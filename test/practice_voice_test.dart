import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_scope.dart';
import 'package:ngy_zhuntifa_counter/data/practice_store.dart';
import 'package:ngy_zhuntifa_counter/l10n/app_language.dart';
import 'package:ngy_zhuntifa_counter/l10n/gen/app_localizations.dart';
import 'package:ngy_zhuntifa_counter/models/practice_settings.dart';
import 'package:ngy_zhuntifa_counter/pages/practice_page.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_voice_counter.dart';
import 'package:ngy_zhuntifa_counter/voice/voice_failure.dart';

import 'memory_key_value_store.dart';

/// 语音计数器替身：由用例决定开启成功还是失败，并手动触发「圆满一遍」。
class _FakeVoiceCounter extends ChangeNotifier implements VoiceCounter {
  _FakeVoiceCounter({this.startFailure});

  /// 开启时上报的失败原因，null 表示开启成功。
  final VoiceFailure? startFailure;

  bool _active = false;
  String _lastHeard = '';
  bool _heardNothing = false;
  VoiceFailure? _reported;
  String? _retryErrorCode;

  @override
  VoidCallback? onRecitation;

  @override
  bool get isActive => _active;

  @override
  String get lastHeard => _lastHeard;

  @override
  bool get heardNothing => _heardNothing;

  @override
  VoiceFailure? get failure => _reported;

  @override
  String? get failureDetail => _reported == null ? null : '测试细节';

  @override
  String? get retryErrorCode => _retryErrorCode;

  @override
  Future<void> start() async {
    _reported = startFailure;
    _active = startFailure == null;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _reported = null;
    _active = false;
    notifyListeners();
  }

  /// 模拟识别到一遍圆满的准提咒。
  void emitRecitation() => onRecitation?.call();

  /// 模拟界面回显的识别原文。
  void heard(String text) {
    _lastHeard = text;
    _retryErrorCode = null;
    _heardNothing = false;
    notifyListeners();
  }

  /// 模拟一次可恢复的识别问题（如网络不通），此时仍在聆听。
  void retrying(String code) {
    _retryErrorCode = code;
    notifyListeners();
  }

  /// 模拟开启后一直没听到声音。
  void silent() {
    _heardNothing = true;
    notifyListeners();
  }
}

Future<void> _pumpPractice(
  WidgetTester tester,
  PracticeStore store,
  VoiceCounter voice,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: PracticeScope(
        store: store,
        child: Scaffold(body: PracticePage(voiceCounter: voice)),
      ),
    ),
  );
}

Future<PracticeStore> _store() async {
  final store = PracticeStore(storage: MemoryKeyValueStore());
  await store.load();
  await store.updateSettings(
    const PracticeSettings(language: AppLanguage.zh),
  );
  return store;
}

void main() {
  testWidgets('打开语音计数后，识别到圆满一遍会计数', (WidgetTester tester) async {
    final store = await _store();
    final voice = _FakeVoiceCounter();

    await _pumpPractice(tester, store, voice);
    expect(find.text('语音计数'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(voice.isActive, isTrue);
    expect(find.text('正在聆听'), findsOneWidget);
    expect(find.text('语音计数已开启，念完一遍会自动记数'), findsOneWidget);

    voice.emitRecitation();
    await tester.pump();
    expect(store.currentCount, 1);

    voice.heard('南无飒哆喃 三藐三菩陀');
    await tester.pump();
    expect(find.text('听到：南无飒哆喃 三藐三菩陀'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('关闭语音计数后不再监听', (WidgetTester tester) async {
    final store = await _store();
    final voice = _FakeVoiceCounter();

    await _pumpPractice(tester, store, voice);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(voice.isActive, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(voice.isActive, isFalse);
    expect(find.text('语音计数'), findsOneWidget);
    expect(store.currentCount, 0);

    await _teardown(tester, store);
  });

  testWidgets('识别出错时界面提示正在重试，开关保持开启', (WidgetTester tester) async {
    final store = await _store();
    final voice = _FakeVoiceCounter();

    await _pumpPractice(tester, store, voice);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    voice.retrying('error_network');
    await tester.pump();

    expect(voice.isActive, isTrue);
    expect(find.text('语音识别出错（error_network），正在重试'), findsOneWidget);

    voice.heard('南无飒哆喃');
    await tester.pump();

    expect(find.text('听到：南无飒哆喃'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('一直没听到声音时提示检查麦克风', (WidgetTester tester) async {
    final store = await _store();
    final voice = _FakeVoiceCounter();

    await _pumpPractice(tester, store, voice);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    voice.silent();
    await tester.pump();

    expect(
      find.text('已经开启，但一直没听到声音：请把手机拿近一些，或在安静处念诵'),
      findsOneWidget,
    );

    voice.heard('南无飒哆喃');
    await tester.pump();

    expect(
      find.text('已经开启，但一直没听到声音：请把手机拿近一些，或在安静处念诵'),
      findsNothing,
    );

    await _teardown(tester, store);
  });

  testWidgets('语音不可用时给出提示，并回到未开启状态', (WidgetTester tester) async {
    final store = await _store();
    final voice = _FakeVoiceCounter(startFailure: VoiceFailure.unavailable);

    await _pumpPractice(tester, store, voice);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(voice.isActive, isFalse);
    expect(find.text('语音计数不可用'), findsOneWidget);
    expect(find.text('无法使用语音识别，请检查麦克风权限与系统语音服务'), findsWidgets);

    await _teardown(tester, store);
  });
}

Future<void> _teardown(WidgetTester tester, PracticeStore store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
  store.dispose();
}
