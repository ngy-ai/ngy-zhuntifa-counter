import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// 模型四件套在 assets 里的目录，与 tool/fetch_model.dart 保持一致。
const String modelAssetDir = 'assets/models/zipformer-multi-zh-hans';

/// 模型版本标记：换模型时改这里，设备上旧的沙盒副本会被重新复制。
const String modelRevision = 'zipformer-multi-zh-hans-2023-12-12-int8';

/// 识别器需要的模型文件在某台设备上的绝对路径。
///
/// 原生库只认文件路径，而 Android 的 assets 打在 APK 里不是文件，
/// 所以由 [ModelStore] 先把模型复制到应用支持目录，再提供路径。
class ModelFiles {
  const ModelFiles({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
    required this.bpeVocab,
  });

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  /// BPE 词表（文本格式，由 bpe.model 导出）。
  ///
  /// 热词改成按字查 tokens.txt（`cjkchar`）后已经不用它了，留着是为了
  /// 换模型时能直接切回 `bpe` 继续对比（见 local_speech_recognizer.dart）。
  final String bpeVocab;
}

/// 把模型从 assets 复制到应用支持目录，并返回可交给原生库的路径。
class ModelStore {
  ModelStore({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// 需要复制的文件（顺序即复制顺序）。
  static const List<String> fileNames = <String>[
    'encoder.int8.onnx',
    'decoder.int8.onnx',
    'joiner.int8.onnx',
    'tokens.txt',
    // 热词按字查 tokens.txt，不再需要它；仍随包分发，换模型对比 bpe 时可用
    'bpe.vocab',
  ];

  /// 复制完成标记：内容是 [modelRevision]。
  static const String readyFileName = '.ready';

  final Future<Directory> Function() _supportDirectory;
  Future<ModelFiles>? _pending;

  /// 幂等：并发调用共用同一次复制；失败后允许再次尝试。
  Future<ModelFiles> ensure() => _pending ??= _ensure();

  Future<ModelFiles> _ensure() async {
    try {
      final root = await _supportDirectory();
      final dir = Directory('${root.path}/models/zipformer-multi-zh-hans');
      if (!await _isUpToDate(dir)) {
        await _copyAssets(dir);
      }
      return ModelFiles(
        encoder: '${dir.path}/encoder.int8.onnx',
        decoder: '${dir.path}/decoder.int8.onnx',
        joiner: '${dir.path}/joiner.int8.onnx',
        tokens: '${dir.path}/tokens.txt',
        bpeVocab: '${dir.path}/bpe.vocab',
      );
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  /// 标记与四个文件都在时视为已就绪。
  Future<bool> _isUpToDate(Directory dir) async {
    final ready = File('${dir.path}/$readyFileName');
    if (!await ready.exists()) return false;
    if ((await ready.readAsString()).trim() != modelRevision) return false;
    for (final name in fileNames) {
      final file = File('${dir.path}/$name');
      if (!await file.exists() || await file.length() == 0) return false;
    }
    return true;
  }

  /// 逐个复制 assets 文件；中途失败时标记不存在，下次会重来。
  Future<void> _copyAssets(Directory dir) async {
    await dir.create(recursive: true);
    final ready = File('${dir.path}/$readyFileName');
    if (await ready.exists()) await ready.delete();

    for (final name in fileNames) {
      final data = await rootBundle.load('$modelAssetDir/$name');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final target = File('${dir.path}/$name');
      await target.writeAsBytes(bytes, flush: true);
    }
    await ready.writeAsString(modelRevision, flush: true);
  }
}
