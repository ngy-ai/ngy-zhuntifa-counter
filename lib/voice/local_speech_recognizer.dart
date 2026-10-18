import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'mantra_hotwords.dart';
import 'model_files.dart';

/// 本地流式识别：麦克风 → 识别器 → 识别文本。
///
/// 与具体识别引擎解耦，测试可以注入替身。[start] 的 `onResult` 回调里，
/// `isFinal` 为 true 表示一段念诵结束（端点），中间结果只用于界面回显。
abstract class LocalSpeechRecognizer {
  /// 开始聆听。重复调用（未 [stop] 时）应直接忽略。
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
  });

  /// 停止聆听并释放本轮占用；实例仍可再次 [start]。
  Future<void> stop();

  /// 彻底释放（识别器与录音器）。之后再 [start] 会重新加载。
  void dispose();
}

/// 构造识别器配置。
///
/// 抽成独立的函数是为了让集成测试（integration_test/）用与生产完全相同的
/// 参数做端到端验证，而不是在测试里另抄一份。
sherpa.OnlineRecognizerConfig buildRecognizerConfig(ModelFiles files) =>
    sherpa.OnlineRecognizerConfig(
      feat: const sherpa.FeatureConfig(
        sampleRate: SherpaSpeechRecognizer.sampleRate,
      ),
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: files.encoder,
          decoder: files.decoder,
          joiner: files.joiner,
        ),
        tokens: files.tokens,
        numThreads: SherpaSpeechRecognizer.numThreads,
        debug: false,
        // 热词按字查 tokens.txt 编码，用不到 bpe.vocab（见 modelingUnit 的注释）
        modelingUnit: SherpaSpeechRecognizer.modelingUnit,
      ),
      // 热词（上下文偏置）只在 modified_beam_search 下参与解码，
      // greedy_search 会静默忽略 createStream 传入的热词
      decodingMethod: SherpaSpeechRecognizer.decodingMethod,
      hotwordsScore: SherpaSpeechRecognizer.hotwordsScore,
    );

/// 识别器启动失败。[permission] 为 true 表示缺少麦克风权限。
class SpeechRecognizerException implements Exception {
  const SpeechRecognizerException(this.message, {this.permission = false});

  final String message;
  final bool permission;

  @override
  String toString() => message;
}

/// 用 sherpa-onnx（本机识别）与 record（麦克风采集）实现的识别器。
///
/// - 模型随应用分发，首次使用时复制到应用支持目录（见 [ModelStore]）；
/// - 识别器实例在多次开启之间复用，第二次开启不再重新加载模型；
/// - 音频只喂给本机识别器，不写盘、不上传。
class SherpaSpeechRecognizer implements LocalSpeechRecognizer {
  SherpaSpeechRecognizer({
    AudioRecorder? recorder,
    ModelStore? modelStore,
    String hotwords = defaultHotwords,
  }) : _recorder = recorder ?? AudioRecorder(),
       _modelStore = modelStore ?? ModelStore(),
       _hotwords = hotwords;

  /// 咒文与常见念法组成的热词（见 [mantraHotwords]）。
  static const String defaultHotwords = mantraHotwords;

  /// 识别采样率，与模型训练一致。
  static const int sampleRate = 16000;

  /// 推理线程数：够用又不至于和界面抢 CPU。
  static const int numThreads = 2;

  /// 解码方法：热词只在 modified_beam_search 下生效（默认是 greedy_search）。
  static const String decodingMethod = 'modified_beam_search';

  /// 热词的建模单元：按字查 tokens.txt（cjkchar）。
  ///
  /// 不能用 `bpe`：实测同一份热词在 `bpe` 下，四段录音的识别结果与
  /// 「关掉热词」逐字相同——这份 bpe.vocab 就是与 tokens.txt 同一批两千个字，
  /// 编码不出可用 token，热词等于没开。换成 `cjkchar` 后热词立即生效。
  ///
  /// 代价是热词里只要有一个字不在词表，整条就被丢掉（没有字节级回退），
  /// 所以热词只能用词表内的同音写法，见 mantra_hotwords.dart。
  static const String modelingUnit = 'cjkchar';

  /// 热词加分。测过 1.0 / 2.0 / 3.0 / 5.0：2.0 四段录音全部不倒退，
  /// 3.0 以上在识别最差的一段反而掉分，所以维持 2.0。
  static const double hotwordsScore = 2.0;

  final AudioRecorder _recorder;
  final ModelStore _modelStore;
  final String _hotwords;

  sherpa.OnlineRecognizer? _recognizer;
  sherpa.OnlineStream? _stream;
  StreamSubscription<Uint8List>? _audio;
  bool _starting = false;
  bool _disposed = false;

  @override
  Future<void> start({required void Function(String, bool) onResult}) async {
    if (_starting || _disposed) return;
    _starting = true;
    try {
      if (!await _recorder.hasPermission()) {
        throw const SpeechRecognizerException('没有麦克风权限', permission: true);
      }

      final recognizer = await _ensureRecognizer();
      if (_disposed) return;

      _stream?.free();
      _stream = recognizer.createStream(hotwords: _hotwords);

      final audio = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );
      _audio = audio.listen((bytes) => _accept(bytes, onResult));
    } catch (error) {
      await stop();
      if (error is SpeechRecognizerException) rethrow;
      throw SpeechRecognizerException('$error');
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> stop() async {
    final subscription = _audio;
    _audio = null;
    await subscription?.cancel();

    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {
      // 停止失败无所谓，下次开启会重新建流
    }

    _stream?.free();
    _stream = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    _recognizer?.free();
    _recognizer = null;
    unawaited(_recorder.dispose());
  }

  /// 首次调用加载模型（约 1–3 秒），之后复用同一实例。
  Future<sherpa.OnlineRecognizer> _ensureRecognizer() async {
    final cached = _recognizer;
    if (cached != null) return cached;

    sherpa.initBindings();
    final files = await _modelStore.ensure();
    final recognizer = sherpa.OnlineRecognizer(buildRecognizerConfig(files));
    _recognizer = recognizer;
    return recognizer;
  }

  /// 把一块音频喂给识别器，解码后回报文本与端点。
  void _accept(Uint8List bytes, void Function(String, bool) onResult) {
    final recognizer = _recognizer;
    final stream = _stream;
    if (recognizer == null || stream == null || bytes.isEmpty) return;

    stream.acceptWaveform(samples: _toFloat32(bytes), sampleRate: sampleRate);
    while (recognizer.isReady(stream)) {
      recognizer.decode(stream);
    }

    final text = recognizer.getResult(stream).text;
    final finished = recognizer.isEndpoint(stream);
    if (text.isNotEmpty || finished) {
      onResult(text, finished);
    }
    if (finished) {
      // 一段结束：回到干净状态，下一段从头累积
      recognizer.reset(stream);
    }
  }

  /// PCM16 小端字节转 [-1, 1] 的浮点样本。
  static Float32List _toFloat32(Uint8List bytes) {
    final count = bytes.length ~/ 2;
    final samples = Float32List(count);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < count; i++) {
      samples[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return samples;
  }
}
