import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/app.dart';
import 'package:ngy_zhuntifa_counter/data/practice_backup.dart';
import 'package:ngy_zhuntifa_counter/data/practice_store.dart';
import 'package:ngy_zhuntifa_counter/l10n/app_language.dart';
import 'package:ngy_zhuntifa_counter/models/practice_settings.dart';
import 'package:ngy_zhuntifa_counter/theme/app_skin.dart';
import 'package:ngy_zhuntifa_counter/widgets/practice_dial.dart';

import 'memory_key_value_store.dart';

/// 语言固定为简体中文：默认是「跟随系统」，而测试环境的系统语言不是中文，
/// 这些用例断言的都是简体中文界面文案。
Future<PracticeStore> _storeWith([PracticeSettings? settings]) async {
  final store = PracticeStore(storage: MemoryKeyValueStore());
  await store.load();
  await store.updateSettings(
    (settings ?? const PracticeSettings()).copyWith(language: AppLanguage.zh),
  );
  return store;
}

/// 收起组件树并让防抖写入的定时器跑完，避免测试残留定时器。
Future<void> _teardown(WidgetTester tester, PracticeStore store) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
  store.dispose();
}

void main() {
  testWidgets('功课页点击计数，首页同步显示统计', (WidgetTester tester) async {
    final store = await _storeWith();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    expect(find.text('准提法计数器'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byType(PracticeDial));
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(store.currentCount, 3);
    expect(find.text('3'), findsWidgets);

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();

    expect(find.text('开始持咒'), findsOneWidget);
    expect(find.textContaining('距今日目标还差 105 遍'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('结束本次会把遍数归档', (WidgetTester tester) async {
    final store = await _storeWith();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PracticeDial));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('结束本次'));
    await tester.pumpAndSettle();

    expect(store.currentCount, 0);
    expect(store.sessions.single.count, 1);

    await _teardown(tester, store);
  });

  testWidgets('皮肤开关立即生效，并写入存档', (WidgetTester tester) async {
    final storage = MemoryKeyValueStore();
    final store = PracticeStore(storage: storage);
    await store.load();
    await store.updateSettings(
      const PracticeSettings(language: AppLanguage.zh),
    );

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.light,
    );

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(store.settings.skinMode, AppSkinMode.dark);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
    expect(
      Theme.of(
        tester.element(find.byType(NavigationBar)),
      ).extension<AppSkin>(),
      AppSkin.dark,
    );

    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(store.settings.skinMode, AppSkinMode.light);
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.light,
    );

    // 关闭面板后重新读档，皮肤选择应当保留。
    await tester.pumpWidget(
      ZhuntiCounterApp(store: PracticeStore(storage: storage)..load()),
    );
    await tester.pumpAndSettle();
    final reloaded = PracticeStore(storage: storage);
    await reloaded.load();
    expect(reloaded.settings.skinMode, AppSkinMode.light);
    reloaded.dispose();

    await _teardown(tester, store);
  });

  testWidgets('默认跟随系统语言，切换语言立即生效并写入存档', (WidgetTester tester) async {
    // 显式把系统语言设成英语，验证「跟随系统」这一默认行为
    tester.platformDispatcher.localesTestValue = const <Locale>[
      Locale('en', 'US'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final storage = MemoryKeyValueStore();
    final store = PracticeStore(storage: storage);
    await store.load();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    expect(store.settings.language, AppLanguage.system);
    expect(find.text('Home'), findsOneWidget);
    expect(find.textContaining('Today ·'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('繁體中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('繁體中文'));
    await tester.pumpAndSettle();

    expect(store.settings.language, AppLanguage.zhHant);
    expect(find.text('首頁'), findsOneWidget);
    expect(find.textContaining('今日持咒 ·'), findsOneWidget);

    await tester.tap(find.text('简体中文'));
    await tester.pumpAndSettle();

    expect(store.settings.language, AppLanguage.zh);
    expect(find.text('首页'), findsOneWidget);
    expect(find.textContaining('今日持咒 ·'), findsOneWidget);

    // 语言选择随功课数据一起持久化
    final reloaded = PracticeStore(storage: storage);
    await reloaded.load();
    expect(reloaded.settings.language, AppLanguage.zh);
    reloaded.dispose();

    await _teardown(tester, store);
  });

  testWidgets('两套皮肤下功课页都能正常计数', (WidgetTester tester) async {
    for (final mode in <AppSkinMode>[AppSkinMode.light, AppSkinMode.dark]) {
      final store = await _storeWith(PracticeSettings(skinMode: mode));

      await tester.pumpWidget(ZhuntiCounterApp(store: store));
      expect(
        Theme.of(tester.element(find.byType(NavigationBar))).brightness,
        mode == AppSkinMode.dark ? Brightness.dark : Brightness.light,
        reason: '皮肤 $mode',
      );

      await tester.tap(find.byIcon(Icons.self_improvement_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PracticeDial));
      await tester.pump(const Duration(milliseconds: 150));

      expect(store.currentCount, 1, reason: '皮肤 $mode');

      await _teardown(tester, store);
    }
  });

  testWidgets('首页「全部明细」可跳转到明细页', (WidgetTester tester) async {
    // 用手机比例的画布，保证首页所有卡片都在视口内被构建出来。
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = await _storeWith();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    expect(find.text('全部明细'), findsOneWidget);

    await tester.tap(find.text('全部明细'));
    await tester.pumpAndSettle();

    expect(find.text('功课明细'), findsOneWidget);
    expect(find.text('还没有功课明细'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('点击明细可查看每一遍的具体时间点', (WidgetTester tester) async {
    final store = await _storeWith();
    await tester.pumpWidget(ZhuntiCounterApp(store: store));

    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byType(PracticeDial));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('结束本次'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey<String>(store.sessions.single.id)));
    await tester.pumpAndSettle();

    expect(find.text('逐次时间'), findsOneWidget);
    expect(find.text('共 3 遍'), findsOneWidget);
    expect(find.text('第 1 遍'), findsOneWidget);
    expect(find.text('第 2 遍'), findsOneWidget);
    expect(find.text('第 3 遍'), findsOneWidget);
    expect(find.text('第 4 遍'), findsNothing);

    // 点空白处关掉面板，避免残留路由影响收尾
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('逐次时间'), findsNothing);

    await _teardown(tester, store);
  });

  testWidgets('明细页按天列出功课，并可删除单条记录', (WidgetTester tester) async {
    final store = await _storeWith();
    await tester.pumpWidget(ZhuntiCounterApp(store: store));

    // 先完成一次 3 遍的功课
    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byType(PracticeDial));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('结束本次'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.text('功课明细'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    // 当天合计与这一条记录各显示一次
    expect(find.text('3 遍'), findsNWidgets(2));

    // 用记录自身的 key 定位，避免误命中 SnackBar 内部的 Dismissible
    await tester.drag(
      find.byKey(ValueKey<String>(store.sessions.single.id)),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除这条记录？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(store.sessions, isEmpty);
    expect(store.stats(DateTime.now()).totalCount, 0);
    expect(find.text('还没有功课明细'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('设置面板可以把备份文本复制到剪贴板', (WidgetTester tester) async {
    final clipboard = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        clipboard.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final store = await _storeWith();
    store.tap(at: DateTime(2026, 10, 1, 9));
    store.tap(at: DateTime(2026, 10, 1, 9, 1));
    store.finishCurrent();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('复制备份文本'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制备份文本'));
    await tester.pumpAndSettle();

    expect(find.text('已复制导出文本'), findsOneWidget);
    expect(find.textContaining('共 1 条记录 · 2 遍'), findsOneWidget);

    final setData = clipboard.lastWhere(
      (MethodCall call) => call.method == 'Clipboard.setData',
    );
    final text =
        (setData.arguments as Map<Object?, Object?>)['text']! as String;
    expect(PracticeBackup.parse(text).sessions.single.count, 2);

    await tester.tap(find.text('好的'));
    await tester.pumpAndSettle();

    await _teardown(tester, store);
  });

  testWidgets('设置面板可以粘贴备份恢复记录', (WidgetTester tester) async {
    // 从另一个仓库导出一份带 2 遍记录的备份
    final source = PracticeStore(storage: MemoryKeyValueStore());
    await source.load();
    source.tap(at: DateTime(2026, 10, 1, 9));
    source.tap(at: DateTime(2026, 10, 1, 9, 1));
    source.finishCurrent();
    final text = source.exportBackup(at: DateTime(2026, 10, 13));
    source.dispose();

    final store = await _storeWith();
    await tester.pumpWidget(ZhuntiCounterApp(store: store));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('导入恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入恢复'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
    expect(find.textContaining('将导入 1 条记录 · 2 遍'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await tester.pumpAndSettle();

    expect(store.sessions.length, 1);
    expect(store.stats(DateTime(2026, 10, 13)).totalCount, 2);
    expect(find.textContaining('已导入 1 条明细记录'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('明细里点开记录可以在详情面板删除', (WidgetTester tester) async {
    final store = await _storeWith();
    await tester.pumpWidget(ZhuntiCounterApp(store: store));

    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();
    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byType(PracticeDial));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('结束本次'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey<String>(store.sessions.single.id)));
    await tester.pumpAndSettle();
    expect(find.text('逐次时间'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '删除这条记录'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条记录？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(store.sessions, isEmpty);
    expect(store.stats(DateTime.now()).totalCount, 0);
    expect(find.text('还没有功课明细'), findsOneWidget);
    expect(find.text('已删除这条记录'), findsOneWidget);

    await _teardown(tester, store);
  });

  testWidgets('进行中的功课可以在明细里放弃', (WidgetTester tester) async {
    final store = await _storeWith();
    await tester.pumpWidget(ZhuntiCounterApp(store: store));

    await tester.tap(find.byIcon(Icons.self_improvement_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PracticeDial));
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.text('进行中'), findsOneWidget);

    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('逐次时间'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '放弃本次功课'));
    await tester.pumpAndSettle();
    expect(find.text('放弃本次功课？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '放弃'));
    await tester.pumpAndSettle();

    expect(store.current, isNull);
    expect(store.currentCount, 0);
    expect(find.text('还没有功课明细'), findsOneWidget);
    expect(find.text('已放弃本次功课'), findsOneWidget);

    await _teardown(tester, store);
  });
}
