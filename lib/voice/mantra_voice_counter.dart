import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_speech_recognizer.dart';
import 'mantra_matcher.dart';
import 'voice_failure.dart';

/// 语音计数的对外契约，便于测试替换成替身。
abstract class VoiceCounter implements Listenable {
  /// 正在聆听（含正在加载模型）。
  bool get isActive;

  /// 正在加载模型，尚未开始聆听。
  bool get loading;

  /// 最近识别到的原文，用于界面回显。
  String get lastHeard;

  /// 失败原因，null 表示一切正常。界面按当前语言翻译后展示。
  VoiceFailure? get failure;

  /// 失败细节：启动失败/中断时是异常信息。
  String? get failureDetail;

  /// 开启一段时间后仍没听到任何内容，多半是麦克风没收到声音。
  bool get heardNothing;

  /// 判定圆满一遍时回调。
  set onRecitation(VoidCallback? callback);

  Future<void> start();

  Future<void> stop();

  void dispose();
}

/// 识别器状态。
enum VoiceStatus { idle, starting, listening, failed }

/// 语音计数控制器：开启后持续聆听，每判定圆满一遍准提咒就回调一次。
///
/// - 识别完全在本机进行（见 docs/adr/0001），不联网、不依赖系统语音服务；
/// - 只对一段念诵结束时的**最终识别文本**做比对，中间结果仅用于回显；
/// - 首次开启会先加载模型（[loading] 为 true），之后复用同一实例；
/// - 退到后台由界面层负责 [stop]，避免长时间占用麦克风。
class MantraVoiceCounter extends ChangeNotifier implements VoiceCounter {
  MantraVoiceCounter({LocalSpeechRecognizer? recognizer, MantraMatcher? matcher})
    : _recognizer = recognizer,
      _matcher = matcher ?? MantraMatcher();

  /// 开启后多久还没听到任何内容，就提示检查麦克风。
  static const Duration _silenceHintDelay = Duration(seconds: 8);

  /// 加载模型前先让出一小段时间，让「正在加载模型」有机会渲染出来。
  static const Duration _loadingFrameDelay = Duration(milliseconds: 20);

  final MantraMatcher _matcher;

  LocalSpeechRecognizer? _recognizer;
  LocalSpeechRecognizer get _engine => _recognizer ??= SherpaSpeechRecognizer();

  Timer? _silenceTimer;
  VoiceStatus _status = VoiceStatus.idle;
  String _lastHeard = '';
  bool _heardNothing = false;
  VoiceFailure? _failure;
  String? _failureDetail;

  @override
  VoidCallback? onRecitation;

  VoiceStatus get status => _status;

  @override
  bool get isActive =>
      _status == VoiceStatus.listening || _status == VoiceStatus.starting;

  @override
  bool get loading => _status == VoiceStatus.starting;

  @override
  String get lastHeard => _lastHeard;

  @override
  VoiceFailure? get failure => _failure;

  @override
  String? get failureDetail => _failureDetail;

  @override
  bool get heardNothing => _heardNothing;

  @override
  Future<void> start() async {
    if (isActive) return;
    _failure = null;
    _failureDetail = null;
    _lastHeard = '';
    _heardNothing = false;
    _status = VoiceStatus.starting;
    notifyListeners();

    await Future<void>.delayed(_loadingFrameDelay);
    if (_status != VoiceStatus.starting) return;

    try {
      _matcher.reset();
      await _engine.start(onResult: _handleResult);
      if (_status != VoiceStatus.starting) {
        // 加载期间被 stop 了：把刚启动的引擎收回去
        await _engine.stop();
        return;
      }
      _status = VoiceStatus.listening;
      notifyListeners();
      _armSilenceHint();
    } on SpeechRecognizerException catch (error) {
      _fail(
        error.permission ? VoiceFailure.permission : VoiceFailure.startFailed,
        error.message,
      );
    } catch (error) {
      _fail(VoiceFailure.startFailed, '$error');
    }
  }

  @override
  Future<void> stop() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _status = VoiceStatus.idle;
    _lastHeard = '';
    _heardNothing = false;
    _failure = null;
    _failureDetail = null;
    _matcher.reset();
    notifyListeners();
    await _engine.stop();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _status = VoiceStatus.idle;
    _recognizer?.dispose();
    _recognizer = null;
    super.dispose();
  }

  /// 识别文本回调：中间结果只回显，段落结束（isFinal）才参与判定。
  void _handleResult(String text, bool isFinal) {
    if (_status != VoiceStatus.listening) return;
    final words = text.trim();

    final changed = words != _lastHeard;
    _lastHeard = words;

    if (words.isNotEmpty) {
      // 又听到内容了：撤下「没听到声音」提示
      _heardNothing = false;
      _silenceTimer?.cancel();
      _silenceTimer = null;
    }

    if (!isFinal) {
      // 中间结果不参与判定，避免同一遍被重复计数
      if (changed) notifyListeners();
      return;
    }

    if (words.isEmpty) return;
    final matched = _matcher.accept(words);
    for (var i = 0; i < matched; i++) {
      onRecitation?.call();
    }
    notifyListeners();
  }

  /// 开启一段时间还没听到任何内容时提示用户（多半是麦克风没收到声音）。
  void _armSilenceHint() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceHintDelay, () {
      if (_status == VoiceStatus.listening && _lastHeard.isEmpty) {
        _heardNothing = true;
        notifyListeners();
      }
    });
  }

  void _fail(VoiceFailure failure, [String? detail]) {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _heardNothing = false;
    _failure = failure;
    _failureDetail = detail;
    _status = VoiceStatus.failed;
    unawaited(_engine.stop());
    notifyListeners();
  }
}
