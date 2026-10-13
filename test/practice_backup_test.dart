import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_backup.dart';
import 'package:ngy_zhuntifa_counter/data/practice_store.dart';
import 'package:ngy_zhuntifa_counter/models/practice_session.dart';

import 'memory_key_value_store.dart';

PracticeSession _session({
  required String id,
  required DateTime start,
  required int count,
  Duration duration = const Duration(minutes: 10),
  List<int> marks = const <int>[],
}) => PracticeSession(
  id: id,
  startAt: start,
  endAt: start.add(duration),
  count: count,
  markOffsets: marks,
);

void main() {
  group('PracticeBackup 编解码', () {
    test('导出的文本可以原样解析回来', () {
      final start = DateTime(2026, 9, 20, 7, 30);
      final currentStart = DateTime(2026, 10, 13, 6);
      final text = PracticeBackup.encode(
        sessions: <PracticeSession>[
          _session(id: 'a', start: start, count: 108, marks: <int>[0, 1500]),
        ],
        current: _session(id: 'b', start: currentStart, count: 5, marks: <int>[0]),
        exportedAt: DateTime(2026, 10, 13, 8),
      );

      final parsed = PracticeBackup.parse(text);

      expect(parsed.sessions.single.id, 'a');
      expect(parsed.sessions.single.count, 108);
      expect(parsed.sessions.single.startAt, start);
      expect(parsed.sessions.single.markOffsets, <int>[0, 1500]);
      expect(parsed.current?.id, 'b');
      expect(parsed.current?.count, 5);
      expect(parsed.current?.startAt, currentStart);
      expect(parsed.exportedAt, DateTime(2026, 10, 13, 8));
    });

    test('导出会剔除没有遍数的记录', () {
      final text = PracticeBackup.encode(
        sessions: <PracticeSession>[
          _session(id: 'empty', start: DateTime(2026, 10, 1), count: 0),
          _session(id: 'ok', start: DateTime(2026, 10, 2), count: 3),
        ],
        exportedAt: DateTime(2026, 10, 13),
      );

      expect(PracticeBackup.parse(text).sessions.map((s) => s.id), <String>['ok']);
    });

    test('解析时会跳过没有遍数的条目', () {
      const text =
          '{"app":"ngy_zhuntifa_counter","version":1,"sessions":['
          '{"id":"x","start":1700000000000,"end":1700000600000,"count":0},'
          '{"id":"y","start":1700000000000,"end":1700000600000,"count":9}'
          '],"current":null}';

      final parsed = PracticeBackup.parse(text);

      expect(parsed.sessions.single.id, 'y');
      expect(parsed.sessions.single.count, 9);
    });

    test('预览统计给出条数、遍数与日期范围', () {
      final parsed = PracticeBackup.parse(
        PracticeBackup.encode(
          sessions: <PracticeSession>[
            _session(id: 'a', start: DateTime(2026, 8, 1), count: 10),
            _session(id: 'b', start: DateTime(2026, 10, 12), count: 20),
          ],
          current: _session(id: 'c', start: DateTime(2026, 10, 13), count: 2),
          exportedAt: DateTime(2026, 10, 13),
        ),
      );

      expect(parsed.sessionCount, 3);
      expect(parsed.totalCount, 32);
      expect(parsed.firstDay, DateTime(2026, 8, 1));
      expect(parsed.lastDay, DateTime(2026, 10, 13));
    });

    test('拒绝各种不合法的文本', () {
      // 空文本
      expect(() => PracticeBackup.parse(''), throwsFormatException);
      expect(() => PracticeBackup.parse('   '), throwsFormatException);
      // 不是 JSON
      expect(() => PracticeBackup.parse('你好'), throwsFormatException);
      // 不是对象
      expect(() => PracticeBackup.parse('[1, 2]'), throwsFormatException);
      // 别的应用的备份
      expect(
        () => PracticeBackup.parse('{"app":"other_app","sessions":[]}'),
        throwsFormatException,
      );
      // 版本过新
      expect(
        () => PracticeBackup.parse(
          '{"app":"ngy_zhuntifa_counter","version":99,"sessions":[]}',
        ),
        throwsFormatException,
      );
      // 缺少明细
      expect(
        () => PracticeBackup.parse('{"app":"ngy_zhuntifa_counter","version":1}'),
        throwsFormatException,
      );
      // 明细里缺关键字段
      expect(
        () => PracticeBackup.parse('{"sessions":[{"id":"x","count":3}]}'),
        throwsFormatException,
      );
    });
  });

  group('PracticeStore 导入导出', () {
    test('导出的备份可以完整恢复到另一个仓库', () async {
      final source = PracticeStore(storage: MemoryKeyValueStore());
      await source.load();
      source.tap(at: DateTime(2026, 10, 1, 9));
      source.tap(at: DateTime(2026, 10, 1, 9, 5));
      source.finishCurrent();
      final text = source.exportBackup(at: DateTime(2026, 10, 13));
      source.dispose();

      final target = PracticeStore(storage: MemoryKeyValueStore());
      await target.load();
      final result = await target.importBackup(PracticeBackup.parse(text));

      expect(result.added, 1);
      expect(result.skipped, 0);
      expect(result.replaced, isFalse);
      expect(target.sessions.single.count, 2);
      expect(target.sessions.single.markOffsets, <int>[0, 300000]);
      expect(target.stats(DateTime(2026, 10, 13)).totalCount, 2);
      target.dispose();
    });

    test('合并导入会跳过重复记录', () async {
      final store = PracticeStore(storage: MemoryKeyValueStore());
      await store.load();
      store.tap(at: DateTime(2026, 10, 1, 9));
      store.finishCurrent();
      final text = store.exportBackup(at: DateTime(2026, 10, 13));

      // 本地再补一条独有的记录
      store.tap(at: DateTime(2026, 10, 2, 9));
      store.finishCurrent();
      expect(store.sessions.length, 2);

      final result = await store.importBackup(PracticeBackup.parse(text));

      expect(result.added, 0);
      expect(result.skipped, 1);
      expect(store.sessions.length, 2);
      expect(store.stats(DateTime(2026, 10, 13)).totalCount, 2);
      store.dispose();
    });

    test('合并导入会追加本地没有的记录', () async {
      final store = PracticeStore(storage: MemoryKeyValueStore());
      await store.load();
      store.tap(at: DateTime(2026, 10, 1, 9));
      store.finishCurrent();

      final other = PracticeStore(storage: MemoryKeyValueStore());
      await other.load();
      other.tap(at: DateTime(2026, 10, 5, 9));
      other.finishCurrent();
      final text = other.exportBackup(at: DateTime(2026, 10, 13));
      other.dispose();

      final result = await store.importBackup(PracticeBackup.parse(text));

      expect(result.added, 1);
      expect(store.sessions.length, 2);
      expect(store.stats(DateTime(2026, 10, 13)).totalCount, 2);
      store.dispose();
    });

    test('覆盖导入会替换掉本地记录', () async {
      final store = PracticeStore(storage: MemoryKeyValueStore());
      await store.load();
      store.tap(at: DateTime(2026, 10, 1, 9));
      store.tap(at: DateTime(2026, 10, 1, 9, 1));
      store.finishCurrent();

      final backup = PracticeBackup.parse(
        PracticeBackup.encode(
          sessions: <PracticeSession>[
            _session(id: 'restored', start: DateTime(2026, 9, 1, 6), count: 108),
          ],
          exportedAt: DateTime(2026, 10, 13),
        ),
      );

      final result = await store.importBackup(backup, replace: true);

      expect(result.replaced, isTrue);
      expect(result.added, 1);
      expect(store.sessions.single.id, 'restored');
      expect(store.stats(DateTime(2026, 10, 13)).totalCount, 108);
      store.dispose();
    });

    test('导入后记录会落盘', () async {
      final storage = MemoryKeyValueStore();
      final store = PracticeStore(storage: storage);
      await store.load();

      await store.importBackup(
        PracticeBackup.parse(
          PracticeBackup.encode(
            sessions: <PracticeSession>[
              _session(id: 'saved', start: DateTime(2026, 9, 1, 6), count: 7),
            ],
            exportedAt: DateTime(2026, 10, 13),
          ),
        ),
      );
      store.dispose();

      final reloaded = PracticeStore(storage: storage);
      await reloaded.load();
      expect(reloaded.sessions.single.id, 'saved');
      expect(reloaded.sessions.single.count, 7);
      reloaded.dispose();
    });

    test('备份里的进行中功课会恢复，但不会打断本地正在计数的功课', () async {
      final backupText = PracticeBackup.encode(
        sessions: const <PracticeSession>[],
        current: _session(
          id: 'ongoing',
          start: DateTime(2026, 10, 12, 6),
          count: 12,
          marks: <int>[0],
        ),
        exportedAt: DateTime(2026, 10, 13),
      );

      // 本地没有进行中的功课时，从备份恢复
      final first = PracticeStore(storage: MemoryKeyValueStore());
      await first.load();
      await first.importBackup(PracticeBackup.parse(backupText));
      expect(first.current?.id, 'ongoing');
      expect(first.currentCount, 12);
      first.dispose();

      // 本地已经在计数时，保留本地那一次
      final second = PracticeStore(storage: MemoryKeyValueStore());
      await second.load();
      second.tap(at: DateTime(2026, 10, 13, 8));
      await second.importBackup(PracticeBackup.parse(backupText));
      expect(second.current?.count, 1);
      expect(second.current?.id, isNot('ongoing'));
      second.dispose();
    });
  });
}
