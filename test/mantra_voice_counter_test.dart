import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/voice/local_speech_recognizer.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_matcher.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_voice_counter.dart';
import 'package:ngy_zhuntifa_counter/voice/voice_failure.dart';

/// 可脚本化的本地识别器替身：记录调用，由测试手动驱动识别文本。
class FakeRecognizer implements LocalSpeechRecognizer {
  /// 启动时抛出的异常，null 表示正常启动。
  Object? startError;

  /// 模拟加载模型需要的时长，默认立即可用。
  Duration loadDelay = Duration.zero;

  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  bool started = false;

  void Function(String text, bool isFinal)? _onResult;

  @override
  Future<void> start({required void Function(String, bool) onResult}) async {
    startCalls++;
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    final error = startError;
    if (error != null) throw error;
    _onResult = onResult;
    started = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    started = false;
    _onResult = null;
  }

  @override
  void dispose() {
    disposeCalls++;
    started = false;
    _onResult = null;
  }

  /// 模拟一段识别文本，[isFinal] 表示这段念诵结束（端点）。
  void emit(String text, {bool isFinal = false}) =>
      _onResult?.call(text, isFinal);
}

void main() {
  late FakeRecognizer fake;
  late MantraVoiceCounter counter;
  late int recitations;

  setUp(() {
    fake = FakeRecognizer();
    counter = MantraVoiceCounter(recognizer: fake);
    recitations = 0;
    counter.onRecitation = () => recitations++;
  });

  tearDown(() {
    counter.dispose();
  });

  group('启动与停止', () {
    test('启动后进入聆听状态', () async {
      await counter.start();

      expect(counter.isActive, isTrue);
      expect(counter.status, VoiceStatus.listening);
      expect(counter.failure, isNull);
      expect(fake.startCalls, 1);
      expect(fake.started, isTrue);
    });

    test('加载模型期间是 loading 状态，加载完才聆听', () async {
      fake.loadDelay = const Duration(milliseconds: 60);

      final starting = counter.start();
      await Future<void>.delayed(Duration.zero);

      expect(counter.loading, isTrue);
      expect(counter.isActive, isTrue);
      expect(counter.status, VoiceStatus.starting);

      await starting;

      expect(counter.loading, isFalse);
      expect(counter.status, VoiceStatus.listening);
    });

    test('没有麦克风权限时提示权限问题', () async {
      fake.startError = const SpeechRecognizerException(
        'denied',
        permission: true,
      );

      await counter.start();

      expect(counter.isActive, isFalse);
      expect(counter.status, VoiceStatus.failed);
      expect(counter.failure, VoiceFailure.permission);
    });

    test('启动过程抛错也能给出提示', () async {
      fake.startError = StateError('boom');

      await counter.start();

      expect(counter.status, VoiceStatus.failed);
      expect(counter.failure, VoiceFailure.startFailed);
      expect(counter.failureDetail, contains('boom'));
    });

    test('重复 start 不会重复启动', () async {
      await counter.start();
      await counter.start();

      expect(fake.startCalls, 1);
    });

    test('stop 会停止引擎并复位状态', () async {
      await counter.start();

      await counter.stop();

      expect(counter.isActive, isFalse);
      expect(counter.status, VoiceStatus.idle);
      expect(counter.lastHeard, isEmpty);
      expect(counter.failure, isNull);
      expect(fake.stopCalls, 1);
      expect(fake.started, isFalse);
    });

    test('加载期间 stop 不会被拉回聆听状态', () async {
      fake.loadDelay = const Duration(milliseconds: 80);

      final starting = counter.start();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await counter.stop();

      await starting;

      expect(counter.status, VoiceStatus.idle);
      expect(counter.isActive, isFalse);
      expect(counter.loading, isFalse);
    });
  });

  group('识别结果处理', () {
    test('中间结果只回显，段落结束时才计数', () async {
      await counter.start();

      fake.emit('南无飒哆喃三藐三菩陀');
      expect(recitations, 0);
      expect(counter.lastHeard, '南无飒哆喃三藐三菩陀');

      fake.emit(mantraText, isFinal: true);
      expect(recitations, 1);
      expect(counter.lastHeard, mantraText);
    });

    test('中间结果没有变化时不会重复通知', () async {
      await counter.start();

      var notifications = 0;
      counter.addListener(() => notifications++);

      fake.emit('南无飒哆喃');
      expect(notifications, 1);

      fake.emit('南无飒哆喃');
      expect(notifications, 1);
    });

    test('一段里听到两遍会计数两次', () async {
      await counter.start();

      fake.emit(mantraText + mantraText, isFinal: true);

      expect(recitations, 2);
    });

    test('分两段听到的最终结果拼成一遍', () async {
      await counter.start();

      fake.emit('南无飒哆喃三藐三菩陀俱胝喃', isFinal: true);
      expect(recitations, 0);

      fake.emit('大吒陀嗡折戾主戾准提娑哈', isFinal: true);
      expect(recitations, 1);
    });

    test('空白的最终结果被忽略', () async {
      await counter.start();

      fake.emit('   ', isFinal: true);

      expect(recitations, 0);
      expect(counter.lastHeard, isEmpty);
    });

    test('stop 之后不再处理识别结果', () async {
      await counter.start();
      await counter.stop();

      fake.emit(mantraText, isFinal: true);

      expect(recitations, 0);
      expect(counter.lastHeard, isEmpty);
    });
  });
}
