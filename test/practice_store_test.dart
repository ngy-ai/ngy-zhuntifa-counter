import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_store.dart';
import 'package:ngy_zhuntifa_counter/models/practice_settings.dart';
import 'package:ngy_zhuntifa_counter/theme/app_skin.dart';

import 'memory_key_value_store.dart';

void main() {
  test('计数、撤销与结束本次', () async {
    final store = PracticeStore(storage: MemoryKeyValueStore());
    await store.load();

    expect(store.currentCount, 0);

    store.tap();
    store.tap();
    store.tap();
    expect(store.currentCount, 3);

    expect(store.undo(), isTrue);
    expect(store.currentCount, 2);
    expect(store.undo(), isTrue);
    expect(store.undo(), isTrue);
    expect(store.undo(), isFalse);
    expect(store.currentCount, 0);

    store.tap();
    store.tap();
    final finished = store.finishCurrent();
    expect(finished?.count, 2);
    expect(store.currentCount, 0);
    expect(store.sessions.length, 1);
    expect(store.stats(DateTime.now()).totalCount, 2);

    store.dispose();
  });

  test('数据可以重新载入', () async {
    final storage = MemoryKeyValueStore();

    final first = PracticeStore(storage: storage);
    await first.load();
    first.tap();
    first.tap();
    await first.updateSettings(
      const PracticeSettings(
        dailyGoal: 216,
        beadCount: 27,
        soundEnabled: false,
        skinMode: AppSkinMode.dark,
      ),
    );
    first.dispose();

    final second = PracticeStore(storage: storage);
    await second.load();
    expect(second.currentCount, 2);
    expect(second.settings.dailyGoal, 216);
    expect(second.settings.beadCount, 27);
    expect(second.settings.soundEnabled, isFalse);
    expect(second.settings.skinMode, AppSkinMode.dark);
    expect(second.stats(DateTime.now()).todayCount, 2);

    second.dispose();
  });

  test('跨天计数会把上一天的功课归档', () async {
    final store = PracticeStore(storage: MemoryKeyValueStore());
    await store.load();

    store.tap(at: DateTime(2026, 10, 12, 23, 50));
    store.tap(at: DateTime(2026, 10, 12, 23, 51));
    expect(store.currentCount, 2);

    store.tap(at: DateTime(2026, 10, 13, 0, 5));
    expect(store.currentCount, 1);
    expect(store.sessions.single.count, 2);

    final stats = store.stats(DateTime(2026, 10, 13, 8));
    expect(stats.todayCount, 1);
    expect(stats.totalCount, 3);

    store.dispose();
  });

  test('清空记录会删除全部数据', () async {
    final storage = MemoryKeyValueStore();
    final store = PracticeStore(storage: storage);
    await store.load();

    store.tap();
    store.finishCurrent();
    await store.clearAll();

    expect(store.sessions, isEmpty);
    expect(store.currentCount, 0);
    expect(store.stats(DateTime.now()).totalCount, 0);

    final reloaded = PracticeStore(storage: storage);
    await reloaded.load();
    expect(reloaded.stats(DateTime.now()).totalCount, 0);

    store.dispose();
    reloaded.dispose();
  });

  test('可以按 id 删除单条明细，并同步扣除统计', () async {
    final storage = MemoryKeyValueStore();
    final store = PracticeStore(storage: storage);
    await store.load();

    store.tap();
    store.tap();
    final first = store.finishCurrent()!;
    store.tap();
    store.finishCurrent();
    expect(store.sessions.length, 2);
    expect(store.stats(DateTime.now()).totalCount, 3);

    expect(await store.deleteSession(first.id), isTrue);
    expect(store.sessions.length, 1);
    expect(store.stats(DateTime.now()).totalCount, 1);

    // 未知 id 不会误删数据
    expect(await store.deleteSession('not-exist'), isFalse);
    expect(store.sessions.length, 1);

    // 删除结果会落盘
    final reloaded = PracticeStore(storage: storage);
    await reloaded.load();
    expect(reloaded.sessions.length, 1);
    expect(reloaded.stats(DateTime.now()).totalCount, 1);

    store.dispose();
    reloaded.dispose();
  });

  test('每次持咒都会记下具体时间点，撤销会一并回退', () async {
    final store = PracticeStore(storage: MemoryKeyValueStore());
    await store.load();

    final base = DateTime(2026, 10, 13, 9);
    store.tap(at: base);
    store.tap(at: base.add(const Duration(seconds: 5)));
    store.tap(at: base.add(const Duration(seconds: 12)));

    expect(store.current?.count, 3);
    expect(store.current?.markOffsets, <int>[0, 5000, 12000]);
    expect(
      store.current?.markTimes.last,
      base.add(const Duration(seconds: 12)),
    );

    expect(store.undo(), isTrue);
    expect(store.current?.count, 2);
    expect(store.current?.markOffsets, <int>[0, 5000]);

    store.dispose();
  });

  test('逐次时间点随存档保留', () async {
    final storage = MemoryKeyValueStore();
    final base = DateTime(2026, 10, 13, 9);

    final first = PracticeStore(storage: storage);
    await first.load();
    first.tap(at: base);
    first.tap(at: base.add(const Duration(seconds: 7)));
    first.finishCurrent();
    await first.flush();
    first.dispose();

    final second = PracticeStore(storage: storage);
    await second.load();

    expect(second.sessions.single.count, 2);
    expect(second.sessions.single.markOffsets, <int>[0, 7000]);
    expect(second.sessions.single.markTimes, <DateTime>[
      base,
      base.add(const Duration(seconds: 7)),
    ]);

    second.dispose();
  });

  test('丢弃本次不会写入历史', () async {
    final store = PracticeStore(storage: MemoryKeyValueStore());
    await store.load();

    store.tap();
    store.discardCurrent();

    expect(store.currentCount, 0);
    expect(store.sessions, isEmpty);

    store.dispose();
  });
}
