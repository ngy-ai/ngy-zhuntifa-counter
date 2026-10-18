// 端到端自检：在真实设备上用生产参数加载模型并识别一段音频。
//
// 样本放在应用的内部目录（经 /data/local/tmp 中转，不占 APK 体积；
// Android 11 起应用访问外部存储的 /sdcard/Android/data/<包名> 会被拒绝，
// 所以不要放那里）：
//   adb push <某个 16kHz 单声道 wav> /data/local/tmp/asr-smoke.wav
//   adb shell run-as com.ngy.ngy_zhuntifa_counter mkdir -p files
//   adb shell run-as com.ngy.ngy_zhuntifa_counter \
//     cp /data/local/tmp/asr-smoke.wav files/asr-smoke.wav
//   flutter test integration_test/local_recognition_test.dart -d <设备>
//
// 模型包的 test_wavs 里就有现成的中文样本，解包命令见 tool/fetch_model.dart。
// 文件不存在时会跳过；这是开发者本地的自检，不进 CI。

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ngy_zhuntifa_counter/voice/local_speech_recognizer.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_hotwords.dart';
import 'package:ngy_zhuntifa_counter/voice/model_files.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 与 lib/voice/local_speech_recognizer.dart 一致的分块：0.1 秒。
const int _chunkSamples = 1600;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 与上面 run-as 复制的位置一致：systemTemp 形如 /data/user/0/<包名>/cache
  final smokePath =
      '${Directory.systemTemp.parent.path}/files/asr-smoke.wav';

  testWidgets('模型能复制到沙盒、加载并识别出文本', (WidgetTester tester) async {
    if (!File(smokePath).existsSync()) {
      markTestSkipped('设备上没有 $smokePath，跳过（见文件头的 adb push 说明）');
      return;
    }

    // 1) 模型从 assets 落到应用支持目录
    final files = await ModelStore().ensure();
    expect(File(files.encoder).existsSync(), isTrue, reason: 'encoder 应已复制');
    expect(File(files.decoder).existsSync(), isTrue);
    expect(File(files.joiner).existsSync(), isTrue);
    expect(File(files.tokens).existsSync(), isTrue);

    // 2) 用与生产完全相同的配置加载识别器
    sherpa.initBindings();
    final recognizer = sherpa.OnlineRecognizer(buildRecognizerConfig(files));
    final stream = recognizer.createStream(hotwords: mantraHotwords);

    // 3) 读音频并按 100ms 分块喂入，模拟实时聆听
    final wave = sherpa.readWave(smokePath);
    expect(wave.samples, isNotEmpty, reason: '应能读出音频样本');

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
    recognizer.free();

    final transcript = pieces.join();
    debugPrint('识别结果：$transcript');

    // 样本内容不做硬性断言：这段用例保证「模型可用、链路通畅」，
    // 识别质量由真机念诵验收。
    expect(transcript, isNotEmpty, reason: '应至少识别出一些文字');
  });
}
