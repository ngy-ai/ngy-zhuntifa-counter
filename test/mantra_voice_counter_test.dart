import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_matcher.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_voice_counter.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 可脚本化的语音识别替身：记录调用、暴露回调，由测试手动驱动。
class FakeSpeechToText extends SpeechToText {
  FakeSpeechToText() : super.withMethodChannel();

  bool available = true;
  Object? initializeError;
  Object? listenError;
  List<LocaleName> localeList = const [];
  bool listening = false;

  int initializeCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;

  SpeechResultListener? resultListener;
  SpeechListenOptions? lastOptions;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
    if (initializeError != null) throw initializeError!;
    errorListener = onError;
    statusListener = onStatus;
    return available;
  }

  @override
  Future<List<LocaleName>> locales() async => localeList;

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCalls++;
    if (listenError != null) throw listenError!;
    resultListener = onResult;
    lastOptions = listenOptions;
    listening = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    listening = false;
  }

  @override
  bool get isListening => listening;

  void emit(SpeechRecognitionResult result) => resultListener?.call(result);
}

/// 构造一条识别结果，默认是中间结果。
SpeechRecognitionResult recognition(String words, {bool isFinal = false}) {
  final type = isFinal ? ResultType.finalResult : ResultType.partial;
  return SpeechRecognitionResult(
    [SpeechRecognitionWords(words, null, 0.9)],
    type.value,
  );
}

void main() {
  late FakeSpeechToText fake;
  late MantraVoiceCounter counter;
  late int recitations;

  setUp(() {
    fake = FakeSpeechToText();
    counter = MantraVoiceCounter(speech: fake);
    recitations = 0;
    counter.onRecitation = () => recitations++;
  });

  tearDown(() {
    counter.dispose();
  });

  group('启动与停止', () {
    test('启动后优先使用简体中文并开始聆听', () async {
      fake.localeList = [
        LocaleName('en-US', 'English'),
        LocaleName('zh-CN', '中文（中国）'),
      ];

      await counter.start();

      expect(counter.isActive, isTrue);
      expect(counter.status, VoiceStatus.listening);
      expect(counter.error, isNull);
      expect(fake.initializeCalls, 1);
      expect(fake.listenCalls, 1);
      expect(fake.listening, isTrue);
      expect(fake.lastOptions?.localeId, 'zh-CN');
    });

    test('简体中文优先级高于其它中文变体', () async {
      fake.localeList = [
        LocaleName('zh-TW', '中文（台灣）'),
        LocaleName('cmn-Hans-CN', '中文（简体）'),
      ];

      await counter.start();

      expect(fake.lastOptions?.localeId, 'cmn-Hans-CN');
    });

    test('没有中文识别时交给系统默认语言', () async {
      fake.localeList = [LocaleName('en-US', 'English')];

      await counter.start();

      expect(fake.lastOptions?.localeId, isNull);
    });

    test('语音识别不可用时给出提示', () async {
      fake.available = false;

      await counter.start();

      expect(counter.isActive, isFalse);
      expect(counter.status, VoiceStatus.failed);
      expect(counter.error, contains('麦克风'));
      expect(fake.listenCalls, 0);
    });

    test('启动过程抛错也能给出提示', () async {
      fake.initializeError = StateError('boom');

      await counter.start();

      expect(counter.status, VoiceStatus.failed);
      expect(counter.error, contains('语音识别启动失败'));
    });

    test('聆听抛错会给出提示', () async {
      fake.listenError = StateError('boom');

      await counter.start();

      expect(counter.status, VoiceStatus.failed);
      expect(counter.error, contains('语音识别中断'));
    });

    test('重复 start 不会重复初始化', () async {
      await counter.start();
      await counter.start();

      expect(fake.initializeCalls, 1);
      expect(fake.listenCalls, 1);
    });

    test('stop 会停止引擎并复位状态', () async {
      await counter.start();

      await counter.stop();

      expect(counter.isActive, isFalse);
      expect(counter.status, VoiceStatus.idle);
      expect(counter.lastHeard, isEmpty);
      expect(counter.error, isNull);
      expect(fake.stopCalls, 1);
      expect(fake.listening, isFalse);
    });
  });

  group('识别结果处理', () {
    test('中间结果只回显，最终结果才计数', () async {
      await counter.start();

      fake.emit(recognition('南无飒哆喃三藐三菩陀'));
      expect(recitations, 0);
      expect(counter.lastHeard, '南无飒哆喃三藐三菩陀');

      fake.emit(recognition(mantraText, isFinal: true));
      expect(recitations, 1);
      expect(counter.lastHeard, mantraText);
    });

    test('中间结果没有变化时不会重复通知', () async {
      await counter.start();

      var notifications = 0;
      counter.addListener(() => notifications++);

      fake.emit(recognition('南无飒哆喃'));
      expect(notifications, 1);

      fake.emit(recognition('南无飒哆喃'));
      expect(notifications, 1);
    });

    test('一次最终结果听到两遍会计数两次', () async {
      await counter.start();

      fake.emit(recognition(mantraText + mantraText, isFinal: true));

      expect(recitations, 2);
    });

    test('分两次听到的最终结果拼成一遍', () async {
      await counter.start();

      fake.emit(recognition('南无飒哆喃三藐三菩陀俱胝喃', isFinal: true));
      expect(recitations, 0);

      fake.emit(recognition('怛侄他唵折戾主戾准提娑婆诃', isFinal: true));
      expect(recitations, 1);
    });

    test('空白的最终结果被忽略', () async {
      await counter.start();

      fake.emit(recognition('   ', isFinal: true));

      expect(recitations, 0);
      expect(counter.lastHeard, isEmpty);
    });
  });

  group('静音续听与错误处理', () {
    test('识别器静音结束后自动续听', () async {
      await counter.start();
      expect(fake.listenCalls, 1);

      fake.statusListener?.call('done');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(fake.listenCalls, 2);
      expect(counter.isActive, isTrue);
    });

    test('stop 之后不会再自动续听', () async {
      await counter.start();

      fake.statusListener?.call('done');
      await counter.stop();

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(fake.listenCalls, 1);
    });

    test('永久错误会停止聆听并给出提示', () async {
      await counter.start();

      fake.errorListener?.call(SpeechRecognitionError('error_permission', true));

      expect(counter.isActive, isFalse);
      expect(counter.status, VoiceStatus.failed);
      expect(counter.error, contains('权限'));
      expect(fake.stopCalls, 1);
    });

    test('暂时性错误不影响继续聆听', () async {
      await counter.start();

      fake.errorListener?.call(SpeechRecognitionError('error_no_match', false));

      expect(counter.status, VoiceStatus.listening);
      expect(counter.error, isNull);
    });
  });
}
