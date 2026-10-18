// 下载并解包本地语音识别模型到 assets/models/。
//
// 用法：
//   dart run tool/fetch_model.dart            # 缺文件时才下载
//   dart run tool/fetch_model.dart --force    # 强制重新下载
//
// 模型来自 https://github.com/k2-fsa/sherpa-onnx/releases（Apache-2.0）。
// 生成的文件被 .gitignore 忽略：本地构建与 CI 发布前各执行一次。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

/// 模型在 assets 里的目录（与 lib/voice/model_files.dart 保持一致）。
const String modelDir = 'assets/models/zipformer-multi-zh-hans';

const String archiveName =
    'sherpa-onnx-streaming-zipformer-multi-zh-hans-2023-12-12.tar.bz2';

const String downloadUrl =
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$archiveName';

/// 需要落盘的文件：asset 名 → 解压后的文件匹配规则。
///
/// 匹配规则里的关键词全部命中才选中；同一条规则命中多个文件时优先文件名
/// 含 `prefer` 的，仍不唯一就按字典序取第一个并打印警告。
const Map<String, List<String>> _wanted = <String, List<String>>{
  'encoder.int8.onnx': <String>['encoder', '.onnx'],
  'decoder.int8.onnx': <String>['decoder', '.onnx'],
  'joiner.int8.onnx': <String>['joiner', '.onnx'],
  'tokens.txt': <String>['tokens.txt'],
  // 热词要按 BPE 编码，需要它导出词表（见 lib/voice/local_speech_recognizer.dart）
  'bpe.model': <String>['bpe.model'],
};

/// 优先选择 int8 量化版本。
const String _prefer = 'int8';

/// 由 bpe.model 导出的文本词表：识别库读文本，读不了二进制的 bpe.model。
const String _bpeVocabName = 'bpe.vocab';

/// 落盘文件的 sha256：下载后校验，防止镜像污染或解包错位。
const Map<String, String> _expectedSha256 = <String, String>{
  'encoder.int8.onnx':
      '1870fad66d2d7b0d9ea8045859ddd32621d505d363b3242a9de13183809751cb',
  'decoder.int8.onnx':
      '1ec2099d6adfa149c9a2d7ce84bd14d471e277d1a88ef898dc550ff8bec86342',
  'joiner.int8.onnx':
      '7c00afc5450290d0e0df2bda461a20c6891110b9f111291396ed57559db8b4e9',
  'tokens.txt':
      '6722bd1585f46f84456b29c3550a343a3cc375b971645773c02ed8e0b4e2405c',
  'bpe.model':
      '867a7355801cb43939962ad757ba1cb7941b6171b5a6902772483b4e3a623377',
  // 生成物：bpe.model 与导出逻辑不变时，内容就是确定的
  'bpe.vocab':
      '7c59f35ff9712d8c3c6937faf041da61900b70f21ca06a11be0121f049b0f8ea',
};

Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final dir = Directory(modelDir);

  if (!force && await _isReady(dir)) {
    stdout.writeln('模型已就绪：$modelDir（要重新下载加 --force）');
    return;
  }

  final temp = Directory('${Directory.systemTemp.path}/zhunti-model-cache');
  await temp.create(recursive: true);
  final archiveFile = File('${temp.path}/$archiveName');

  if (force || !await archiveFile.exists()) {
    stdout.writeln('下载 $downloadUrl …');
    await _download(archiveFile);
  }
  stdout.writeln('压缩包：${archiveFile.path}（${_mb(await archiveFile.length())}）');

  stdout.writeln('解包（bzip2 + tar，纯 Dart 实现，稍慢）…');
  final bytes = await archiveFile.readAsBytes();
  final tarBytes = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tarBytes);

  await dir.create(recursive: true);
  for (final entry in _wanted.entries) {
    final candidates = archive.files
        .where((file) => file.isFile)
        .where((file) => entry.value.every(file.name.contains))
        .toList();
    if (candidates.isEmpty) {
      stderr.writeln('压缩包里找不到 ${entry.key}（规则：${entry.value}）');
      exitCode = 1;
      return;
    }

    candidates.sort((a, b) {
      final aPreferred = a.name.contains(_prefer) ? 0 : 1;
      final bPreferred = b.name.contains(_prefer) ? 0 : 1;
      if (aPreferred != bPreferred) return aPreferred - bPreferred;
      // 目录层级浅的优先（模型的命名变体可能藏在子目录里）
      final aDepth = a.name.split('/').length;
      final bDepth = b.name.split('/').length;
      if (aDepth != bDepth) return aDepth - bDepth;
      return a.name.compareTo(b.name);
    });

    final picked = candidates.first;
    if (candidates.length > 1) {
      stdout.writeln(
        '提示：${entry.key} 匹配到 ${candidates.length} 个文件，取 ${picked.name}',
      );
    }

    final target = File('${dir.path}/${entry.key}');
    await target.writeAsBytes(picked.content as List<int>, flush: true);
    await _reportSha256(target);
  }

  stdout.writeln('导出 $_bpeVocabName（热词编码用）…');
  final bpeVocab = File('${dir.path}/$_bpeVocabName');
  await _writeBpeVocab(File('${dir.path}/bpe.model'), bpeVocab);
  await _reportSha256(bpeVocab);

  if (_expectedSha256.isEmpty) {
    stdout.writeln('提示：把上面的 sha256 填进 _expectedSha256 后即可校验。');
  }
  stdout.writeln('完成：$modelDir');
}

/// 需要的文件都在且非空时视为就绪（bpe.vocab 是由 bpe.model 生成的）。
Future<bool> _isReady(Directory dir) async {
  for (final name in [..._wanted.keys, _bpeVocabName]) {
    final file = File('${dir.path}/$name');
    if (!await file.exists() || await file.length() == 0) return false;
  }
  return true;
}

/// 校验并打印 [file] 的 sha256；与登记值不一致时置失败码。
Future<void> _reportSha256(File file) async {
  final name = file.uri.pathSegments.last;
  final digest = sha256.convert(await file.readAsBytes()).toString();
  final expected = _expectedSha256[name];
  final mark = expected == null
      ? '（未登记）'
      : (expected == digest ? 'ok' : '与登记值不一致！');
  stdout.writeln('$name\t${_mb(await file.length())}\tsha256=$digest $mark');
  if (expected != null && expected != digest) exitCode = 1;
}

/// 下载到 [file]，跟随 GitHub 的重定向。
Future<void> _download(File file) async {
  final client = HttpClient();
  try {
    var uri = Uri.parse(downloadUrl);
    HttpClientResponse? response;
    for (var hop = 0; hop < 5; hop++) {
      final request = await client.getUrl(uri);
      response = await request.close();
      if (response.isRedirect) {
        uri = uri.resolve(response.headers.value(HttpHeaders.locationHeader)!);
        continue;
      }
      break;
    }
    if (response == null || response.statusCode != 200) {
      throw HttpException('下载失败：HTTP ${response?.statusCode}');
    }

    final sink = file.openWrite();
    var received = 0;
    var lastReport = 0;
    await for (final chunk in response) {
      sink.add(chunk);
      received += chunk.length;
      if (received - lastReport > 8 * 1024 * 1024) {
        lastReport = received;
        stdout.writeln('  已下载 ${_mb(received)}');
      }
    }
    await sink.close();
  } finally {
    client.close(force: true);
  }
}

/// 把 sentencepiece 的二进制 bpe.model 导出成文本词表。
///
/// 每行 `piece<TAB>分数`，顺序即 token id，与 sherpa-onnx 官方脚本
/// scripts/export_bpe_vocab.py 的输出一致。
Future<void> _writeBpeVocab(File source, File target) async {
  final pieces = _parseModelProto(await source.readAsBytes());
  final buffer = StringBuffer();
  for (final piece in pieces) {
    buffer.write('${piece.text}\t${piece.score}\n');
  }
  await target.writeAsString(buffer.toString(), flush: true);
}

/// 词表里的一条 piece 与它的分数。
class _Piece {
  const _Piece(this.text, this.score);

  final String text;
  final double score;
}

const int _wireVarint = 0;
const int _wire64 = 1;
const int _wireBytes = 2;
const int _wire32 = 5;

/// 解析 sentencepiece 的 ModelProto：字段 1 是 repeated SentencePiece，
/// 每条里字段 1 是 piece（string）、字段 2 是 score（float）。
List<_Piece> _parseModelProto(Uint8List data) {
  final pieces = <_Piece>[];
  var i = 0;
  while (i < data.length) {
    final key = _readVarint(data, i);
    i = key.next;
    final field = key.value >> 3;
    switch (key.value & 7) {
      case _wireVarint:
        i = _readVarint(data, i).next;
      case _wire64:
        i += 8;
      case _wireBytes:
        final length = _readVarint(data, i);
        i = length.next;
        if (field == 1) {
          pieces.add(_parseSentencePiece(data, i, i + length.value));
        }
        i += length.value;
      case _wire32:
        i += 4;
      default:
        throw FormatException('bpe.model 里出现不认识的 protobuf 字段');
    }
  }
  return pieces;
}

_Piece _parseSentencePiece(Uint8List data, int start, int end) {
  var text = '';
  var score = 0.0;
  var i = start;
  while (i < end) {
    final key = _readVarint(data, i);
    i = key.next;
    final field = key.value >> 3;
    switch (key.value & 7) {
      case _wireVarint:
        i = _readVarint(data, i).next;
      case _wire64:
        i += 8;
      case _wireBytes:
        final length = _readVarint(data, i);
        i = length.next;
        if (field == 1) {
          text = utf8.decode(data.sublist(i, i + length.value));
        }
        i += length.value;
      case _wire32:
        if (field == 2) {
          score = ByteData.sublistView(data).getFloat32(i, Endian.little);
        }
        i += 4;
      default:
        throw FormatException('bpe.model 里出现不认识的 protobuf 字段');
    }
  }
  return _Piece(text, score);
}

/// 读一个 protobuf 变长整数，返回值和下一个字节的位置。
({int value, int next}) _readVarint(Uint8List data, int offset) {
  var value = 0;
  var shift = 0;
  var i = offset;
  while (true) {
    final byte = data[i++];
    value |= (byte & 0x7f) << shift;
    if (byte & 0x80 == 0) return (value: value, next: i);
    shift += 7;
  }
}

String _mb(int bytes) => '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
