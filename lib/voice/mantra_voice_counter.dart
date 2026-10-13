import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'mantra_matcher.dart';

/// 语音计数的对外契约，便于测试替换成替身。
abstract class VoiceCounter implements Listenable {
  /// 正在聆听（含正在启动）。
  bool get isActive;

  /// 最近识别到的原文，用于界面回显。
  String get lastHeard;

  /// 出错信息，null 表示一切正常。
  String? get error;

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
/// - 退到后台由界面层负责 [stop]，避免长时间占用麦克风。
class MantraVoiceCounter extends ChangeNotifier implements VoiceCounter {
  MantraVoiceCounter({SpeechToText? speech, MantraMatcher? matcher})
    : _speech = speech,
      _matcher = matcher ?? MantraMatcher();

  final MantraMatcher _matcher;

  SpeechToText? _speech;
  SpeechToText get _engine => _speech ??= SpeechToText();

  Timer? _restartTimer;
  String? _localeId;
  VoiceStatus _status = VoiceStatus.idle;
  String _lastHeard = '';
  String? _error;

  @override
  VoidCallback? onRecitation;

  VoiceStatus get status => _status;

  @override
  bool get isActive =>
      _status == VoiceStatus.listening || _status == VoiceStatus.starting;

  @override
  String get lastHeard => _lastHeard;

  @override
  String? get error => _error;

  @override
  Future<void> start() async {
    if (isActive) return;
    _error = null;
    _lastHeard = '';
    _status = VoiceStatus.starting;
    notifyListeners();

    try {
      final available = await _engine.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!available) {
        _fail('无法使用语音识别，请检查麦克风权限与系统语音服务');
        return;
      }
      _localeId = await _resolveLocaleId();
      _matcher.reset();
      _status = VoiceStatus.listening;
      notifyListeners();
      await _listen();
    } catch (error) {
      _fail('语音识别启动失败：$error');
    }
  }

  @override
  Future<void> stop() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    _status = VoiceStatus.idle;
    _lastHeard = '';
    _error = null;
    _matcher.reset();
    notifyListeners();
    await _stopEngine();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _restartTimer = null;
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
      _fail('语音识别中断：$error');
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
    if (_status != VoiceStatus.listening) return;
    // 静音后识别器会自己结束，这里稍作停顿再续听，实现连续计数
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      if (_status == VoiceStatus.listening) unawaited(_listen());
    });
  }

  void _handleError(SpeechRecognitionError error) {
    // 「没听清」「静音超时」这类是可恢复的，交给自动续听处理即可
    if (!error.permanent) return;
    _fail(
      switch (error.errorMsg) {
        'error_permission' ||
        'error_permission_denied' => '没有麦克风或语音识别权限，请在系统设置里开启后重试',
        'error_busy' => '语音识别被其他应用占用，请稍后重试',
        'error_network' => '语音识别需要网络，请检查网络后重试',
        _ => '语音识别出错（${error.errorMsg}）',
      },
    );
  }

  /// 优先选中文识别；取不到就让系统用默认语言。
  Future<String?> _resolveLocaleId() async {
    try {
      final locales = await _engine.locales();
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

  void _fail(String message) {
    _restartTimer?.cancel();
    _restartTimer = null;
    _error = message;
    _status = VoiceStatus.failed;
    notifyListeners();
    unawaited(_stopEngine());
  }
}
