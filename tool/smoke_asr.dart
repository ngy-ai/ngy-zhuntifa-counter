// 冒烟验证：用 assets 里的模型识别一个 wav 文件，确认模型与解码配置可用。
//
// 用法：
//   dart run tool/smoke_asr.dart build/DEV_T0000000000.wav
//
// 模型包里的 test_wavs 就是为此准备的：
//   tar -xjf <sherpa-onnx-...-multi-zh-hans-...>.tar.bz2 -C build --strip-components=2 \
//     sherpa-onnx-streaming-zipformer-multi-zh-hans-2023-12-12/test_wavs
//
// 这是开发时的自检工具，不进 CI。

import 'dart:io';

import 'package:ngy_zhuntifa_counter/voice/mantra_hotwords.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 与 lib/voice/model_files.dart、lib/voice/local_speech_recognizer.dart 保持一致。
const String defaultModelDir = 'assets/models/zipformer-multi-zh-hans';
const int sampleRate = 16000;

/// 每次喂 0.1 秒，与实时聆听的分块一致。
const int chunkSamples = 1600;

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('用法：dart run tool/smoke_asr.dart <wav 文件> [模型目录]');
    exitCode = 1;
    return;
  }

  sherpa.initBindings();

  final path = args.first;
  final wave = sherpa.readWave(path);
  if (wave.samples.isEmpty) {
    stderr.writeln('读不出音频：$path');
    exitCode = 1;
    return;
  }
  final seconds = (wave.samples.length / wave.sampleRate).toStringAsFixed(1);
  stdout.writeln('音频：$path（$seconds 秒，${wave.sampleRate}Hz）');

  final dir = args.length > 1 ? args[1] : defaultModelDir;
  final recognizer = sherpa.OnlineRecognizer(
    sherpa.OnlineRecognizerConfig(
      feat: const sherpa.FeatureConfig(sampleRate: sampleRate),
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: '$dir/encoder.int8.onnx',
          decoder: '$dir/decoder.int8.onnx',
          joiner: '$dir/joiner.int8.onnx',
        ),
        tokens: '$dir/tokens.txt',
        numThreads: 2,
        debug: false,
        // 与 lib/voice/local_speech_recognizer.dart 的配置保持一致
        modelingUnit: 'cjkchar',
      ),
      // 热词只在 modified_beam_search 下生效
      decodingMethod: 'modified_beam_search',
      hotwordsScore: 2.0,
    ),
  );

  final stream = recognizer.createStream(hotwords: mantraHotwords);
  final stopwatch = Stopwatch()..start();

  for (var offset = 0; offset < wave.samples.length; offset += chunkSamples) {
    final end = (offset + chunkSamples).clamp(0, wave.samples.length);
    stream.acceptWaveform(
      samples: wave.samples.sublist(offset, end),
      sampleRate: wave.sampleRate,
    );
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }
    if (recognizer.isEndpoint(stream)) {
      final text = recognizer.getResult(stream).text.trim();
      if (text.isNotEmpty) stdout.writeln('段落：$text');
      recognizer.reset(stream);
    }
  }

  stream.inputFinished();
  while (recognizer.isReady(stream)) {
    recognizer.decode(stream);
  }
  final tail = recognizer.getResult(stream).text.trim();
  if (tail.isNotEmpty) stdout.writeln('段落：$tail');

  stopwatch.stop();
  final realtime = stopwatch.elapsedMilliseconds / 1000;
  stdout.writeln('识别完成，用时 ${realtime.toStringAsFixed(1)} 秒'
      '（RTF ${(realtime / (wave.samples.length / wave.sampleRate)).toStringAsFixed(3)}）');

  stream.free();
  recognizer.free();
}
