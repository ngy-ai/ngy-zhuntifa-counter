// 实验脚本：复跑热词配置与判遍，用设备上的念诵录音拿数据。
//
// 用法：把录音放进 assets/rec/ 并临时加进 pubspec 的 assets，然后
//   flutter test integration_test/chant_probe_test.dart -d <设备>
// 跑完把 assets/rec 和 pubspec 那一行删掉——录音不进仓库。
//
// 2026-10 结果（4 段快念录音，每段 5–8 秒念完一遍）：
//   分数    rec1 sim   rec2 sim   rec3 sim   rec4 sim   判遍
//   关热词  0.610      0.538      0.529      0.727      4/4
//   2.0     0.624      0.592      0.529      0.775      4/4
//   5.0     0.624      0.657      0.496      0.743      3/4
//   8.0     0.621      0.662      0.512      0.739      3/4
//   12.0    0.647      0.638      0.482      0.739      3/4
//
// 判定改成「整段 0.5 + 结尾听到准提且后面还有音」后，2.0 分四段全过；
// 5.0 以上 rec3 反而掉到 0.5 以下，所以维持 2.0。tail 列是旧的字符级
// 尾部相似度，只留作对照——它区分不开「念到一半」（0.37 左右），已经不用了。
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_hotwords.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_matcher.dart';
import 'package:ngy_zhuntifa_counter/voice/model_files.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 与生产一致的分块：0.1 秒。
const int _chunkSamples = 1600;

class _Case {
  const _Case(this.label, this.modelingUnit, this.score, this.hotwords);

  final String label;
  final String modelingUnit;
  final double score;
  final String hotwords;
}

final List<_Case> _cases = <_Case>[
  const _Case('关热词', 'cjkchar', 2.0, ''),
  const _Case('cjkchar 2.0', 'cjkchar', 2.0, mantraHotwords),
  const _Case('cjkchar 5.0', 'cjkchar', 5.0, mantraHotwords),
  const _Case('cjkchar 8.0', 'cjkchar', 8.0, mantraHotwords),
  const _Case('cjkchar 12.0', 'cjkchar', 12.0, mantraHotwords),
];

sherpa.OnlineRecognizerConfig _configFor(
  ModelFiles files,
  String modelingUnit,
  double score,
) => sherpa.OnlineRecognizerConfig(
  feat: const sherpa.FeatureConfig(sampleRate: 16000),
  model: sherpa.OnlineModelConfig(
    transducer: sherpa.OnlineTransducerModelConfig(
      encoder: files.encoder,
      decoder: files.decoder,
      joiner: files.joiner,
    ),
    tokens: files.tokens,
    numThreads: 2,
    debug: false,
    modelingUnit: modelingUnit,
    // cjkchar 不需要 BPE 词表；给了也无妨，这里只按模式区分
    bpeVocab: modelingUnit == 'bpe' ? files.bpeVocab : '',
  ),
  decodingMethod: 'modified_beam_search',
  hotwordsScore: score,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('念诵录音：热词分数对比', (tester) async {
    // 录音来源有两个：
    // 1. assets/rec/ 里打包进来的 wav（临时加进 pubspec 的 assets，跑完删掉）；
    // 2. 应用私有目录 / 外部私有目录里现成的录音。
    // 注意 flutter test 跑完会卸载应用，应用目录里的录音会被清空。
    final bundleDir = Directory(
      '${(await getTemporaryDirectory()).path}/chant_probe',
    );
    bundleDir.createSync(recursive: true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    for (final key in manifest.listAssets()) {
      if (!key.startsWith('assets/rec/') || !key.endsWith('.wav')) continue;
      final data = await rootBundle.load(key);
      File('${bundleDir.path}/${key.split('/').last}').writeAsBytesSync(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    final candidates = <Directory>[
      bundleDir,
      Directory('${Directory.systemTemp.parent.path}/files'),
      ?await getExternalStorageDirectory(),
    ];

    final wavs = <File>[];
    for (final dir in candidates) {
      try {
        if (!dir.existsSync()) continue;
        wavs.addAll(
          dir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.wav')),
        );
      } on FileSystemException catch (error) {
        debugPrint('跳过 ${dir.path}：${error.message}');
      }
    }
    wavs.sort((a, b) => a.path.compareTo(b.path));

    if (wavs.isEmpty) {
      markTestSkipped('设备上没有念诵录音，跳过');
      return;
    }

    final files = await ModelStore().ensure();
    sherpa.initBindings();

    for (final wav in wavs) {
      final wave = sherpa.readWave(wav.path);
      final name = wav.uri.pathSegments.last;
      debugPrint('===== $name =====');

      for (final testCase in _cases) {
        final recognizer = sherpa.OnlineRecognizer(
          _configFor(files, testCase.modelingUnit, testCase.score),
        );
        final text = _decode(recognizer, wave, testCase.hotwords);
        recognizer.free();

        final pinyin = MantraMatcher.normalizePinyin(
          MantraMatcher.toPinyin(text),
        );
        final similarity = _dice(pinyin, mantraPinyin);
        final rounds = MantraMatcher().accept(text);
        debugPrint(
          'RESULT\t$name\t${testCase.label}\t'
          'sim=${similarity.toStringAsFixed(3)}\t'
          'tail=${_tailDice(pinyin).toStringAsFixed(2)}\t'
          '遍数=$rounds\t$text',
        );
      }
    }
  });
}

String _decode(
  sherpa.OnlineRecognizer recognizer,
  sherpa.WaveData wave,
  String hotwords,
) {
  final stream = recognizer.createStream(hotwords: hotwords);
  final pieces = <String>[];

  for (var offset = 0; offset < wave.samples.length; offset += _chunkSamples) {
    final end = (offset + _chunkSamples).clamp(0, wave.samples.length);
    stream.acceptWaveform(
      samples: wave.samples.sublist(offset, end),
      sampleRate: wave.sampleRate,
    );
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    if (recognizer.isEndpoint(stream)) {
      final text = recognizer.getResult(stream).text.trim();
      if (text.isNotEmpty) pieces.add(text);
      recognizer.reset(stream);
    }
  }

  stream.inputFinished();
  while (recognizer.isReady(stream)) {
    recognizer.decode(stream);
  }
  final tail = recognizer.getResult(stream).text.trim();
  if (tail.isNotEmpty) pieces.add(tail);

  stream.free();
  return pieces.join();
}

/// 末尾一段的相似度：长度与 MantraMatcher 的尾部窗口一致。
double _tailDice(String pinyin) {
  final length = math.max(3, (mantraPinyin.length * 0.3).round());
  final tail = mantraPinyin.substring(mantraPinyin.length - length);
  if (pinyin.isEmpty) return 0;
  final window = pinyin.length <= length
      ? pinyin
      : pinyin.substring(pinyin.length - length);
  return _dice(window, tail);
}

double _dice(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final target = <String, int>{};
  for (var i = 0; i + 1 < b.length; i++) {
    final gram = b.substring(i, i + 2);
    target[gram] = (target[gram] ?? 0) + 1;
  }
  final used = <String, int>{};
  var common = 0;
  for (var i = 0; i + 1 < a.length; i++) {
    final gram = a.substring(i, i + 2);
    final available = (target[gram] ?? 0) - (used[gram] ?? 0);
    if (available > 0) {
      used[gram] = (used[gram] ?? 0) + 1;
      common++;
    }
  }
  return 2 * common / ((a.length - 1) + (b.length - 1));
}
