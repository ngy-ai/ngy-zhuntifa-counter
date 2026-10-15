import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'mantra_matcher.dart';
import 'voice_failure.dart';

/// 语音计数的对外契约，便于测试替换成替身。
abstract class VoiceCounter implements Listenable {
  /// 正在聆听（含正在启动）。
  bool get isActive;

  /// 最近识别到的原文，用于界面回显。
  String get lastHeard;

  /// 失败原因，null 表示一切正常。界面按当前语言翻译后展示。
  VoiceFailure? get failure;

  /// 失败细节：启动失败/中断时是异常信息，其它错误时是系统错误码。
  String? get failureDetail;

  /// 最近一次「可恢复」的系统错误码（如 error_network）。
  ///
  /// 这类问题不会中断聆听，控制器会自动续听，界面用它提示「正在重试」，
  /// 免得用户看到开关亮着却没有任何反应。识别到内容后自动清空。
  String? get retryErrorCode;

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
/// - 只在**最终识别结果**上做比对，避免中间结果被重复计入；
/// - Android 的识别器静音后会自行结束，这里在状态回调里自动续听；
/// - 「没听清」「静音超时」这类错误不会中断聆听，只有权限、占用等
///   无法自行恢复的错误才会停下并提示；
/// - 退到后台由界面层负责 [stop]，避免长时间占用麦克风。
class MantraVoiceCounter extends ChangeNotifier implements VoiceCounter {
  MantraVoiceCounter({SpeechToText? speech, MantraMatcher? matcher})
    : _speech = speech,
      _matcher = matcher ?? MantraMatcher();

  /// 与「听清了没有」无关的错误：继续聆听就行，不必打扰用户。
  static const Set<String> _quietErrorCodes = <String>{
    'error_no_match',
    'error_speech_timeout',
  };

  /// 环境类错误：还能继续尝试，但要在界面上说明原因。
  static const Set<String> _retryableErrorCodes = <String>{
    'error_network',
    'error_network_timeout',
    'error_server',
    'error_server_disconnected',
    'error_too_many_requests',
    'error_audio_error',
    'error_client',
  };

  /// 开启后多久还没听到任何内容，就提示检查麦克风。
  static const Duration _silenceHintDelay = Duration(seconds: 8);

  final MantraMatcher _matcher;

  SpeechToText? _speech;
  SpeechToText get _engine => _speech ??= SpeechToText();

  Timer? _restartTimer;
  Timer? _silenceTimer;
  String? _localeId;
  VoiceStatus _status = VoiceStatus.idle;
  String _lastHeard = '';
  bool _heardNothing = false;
  VoiceFailure? _failure;
  String? _failureDetail;
  String? _retryErrorCode;

  @override
  VoidCallback? onRecitation;

  VoiceStatus get status => _status;

  @override
  bool get isActive =>
      _status == VoiceStatus.listening || _status == VoiceStatus.starting;

  @override
  String get lastHeard => _lastHeard;

  @override
  VoiceFailure? get failure => _failure;

  @override
  String? get failureDetail => _failureDetail;

  @override
  String? get retryErrorCode => _retryErrorCode;

  @override
  bool get heardNothing => _heardNothing;

  @override
  Future<void> start() async {
    if (isActive) return;
    _failure = null;
    _failureDetail = null;
    _retryErrorCode = null;
    _lastHeard = '';
    _heardNothing = false;
    _status = VoiceStatus.starting;
    notifyListeners();

    try {
      final available = await _engine.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!available) {
        _fail(VoiceFailure.unavailable);
        return;
      }
      _localeId = await _resolveLocaleId();
      _matcher.reset();
      _status = VoiceStatus.listening;
      notifyListeners();
      _armSilenceHint();
      await _listen();
    } catch (error) {
      _fail(VoiceFailure.startFailed, '$error');
    }
  }

  @override
  Future<void> stop() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _status = VoiceStatus.idle;
    _lastHeard = '';
    _heardNothing = false;
    _failure = null;
    _failureDetail = null;
    _retryErrorCode = null;
    _matcher.reset();
    notifyListeners();
    await _stopEngine();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _restartTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _status = VoiceStatus.idle;
    unawaited(_stopEngine());
    super.dispose();
  }

  Future<void> _listen() async {
    if (_status != VoiceStatus.listening) return;
    try {
      await _engine.listen(
        onResult: _handleResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          localeId: _localeId,
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      _fail(VoiceFailure.interrupted, '$error');
    }
  }

  Future<void> _stopEngine() async {
    try {
      if (_speech?.isListening ?? false) {
        await _speech!.stop();
      }
    } catch (_) {
      // 停止失败无所谓，下次开启会重新初始化
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    if (words.isEmpty) return;

    final changed = words != _lastHeard;
    _lastHeard = words;
    // 又听到内容了：撤下「正在重试」与「没听到声音」的提示
    _retryErrorCode = null;
    _heardNothing = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (kDebugMode) {
      debugPrint('语音识别${result.finalResult ? '（最终）' : '（中间）'}：$words');
    }

    if (!result.finalResult) {
      // 中间结果只用来回显，不参与判定，避免同一遍被重复计数
      if (changed) notifyListeners();
      return;
    }

    final matched = _matcher.accept(words);
    for (var index = 0; index < matched; index++) {
      onRecitation?.call();
    }
    notifyListeners();
  }

  void _handleStatus(String status) {
    if (status != 'done' && status != 'notListening') return;
    // 静音后识别器会自己结束，这里稍作停顿再续听，实现连续计数
    _scheduleRestart();
  }

  void _handleError(SpeechRecognitionError error) {
    final code = error.errorMsg;

    // 识别器偶尔「没听清」，接着听就行，不用打断用户
    if (_quietErrorCodes.contains(code)) {
      _scheduleRestart();
      return;
    }

    // 网络、服务端、音频等环境问题：继续尝试，同时在界面上说明原因，
    // 否则用户只会看到开关亮着却一直不计数
    if (_retryableErrorCodes.contains(code)) {
      debugPrint('语音识别暂时不可用：$code，稍后自动重试');
      if (_retryErrorCode != code) {
        _retryErrorCode = code;
        notifyListeners();
      }
      _scheduleRestart();
      return;
    }

    // Android 端插件把所有错误都标成 permanent，所以这里只对确实无关
    // 紧要的错误网开一面，其余（权限、被占用、语言不可用等）按致命处理。
    if (!error.permanent) return;
    debugPrint('语音识别已停止：$code');
    _fail(
      switch (code) {
        'error_permission' ||
        'error_permission_denied' => VoiceFailure.permission,
        'error_busy' => VoiceFailure.busy,
        _ => VoiceFailure.unknown,
      },
      code,
    );
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

  /// 识别器结束或报错后稍作停顿再续听，实现连续计数。
  void _scheduleRestart() {
    if (_status != VoiceStatus.listening) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_status == VoiceStatus.listening) unawaited(_listen());
    });
  }

  /// 优先选中文识别；取不到就让系统用默认语言。
  ///
  /// 取语言列表要等服务返回，个别设备可能很久不响应，超时就用系统默认，
  /// 免得卡在「正在启动」而没有任何反应。
  Future<String?> _resolveLocaleId() async {
    try {
      final locales = await _engine.locales().timeout(
        const Duration(seconds: 3),
      );
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('_', '-');
        if (id == 'zh-cn' || id.startsWith('zh-hans') || id == 'cmn-hans-cn') {
          return locale.localeId;
        }
      }
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase();
        if (id.startsWith('zh') || id.startsWith('cmn')) {
          return locale.localeId;
        }
      }
    } catch (_) {
      // 拿不到语言列表就用系统默认
    }
    return null;
  }

  void _fail(VoiceFailure failure, [String? detail]) {
    _restartTimer?.cancel();
    _restartTimer = null;
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _heardNothing = false;
    _failure = failure;
    _failureDetail = detail;
    _status = VoiceStatus.failed;
    notifyListeners();
    unawaited(_stopEngine());
  }
}
