import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_history.dart';
import 'package:ngy_zhuntifa_counter/models/practice_session.dart';

PracticeSession _session(
  DateTime start,
  int count, {
  String? id,
  Duration length = const Duration(minutes: 12),
}) => PracticeSession(
  id: id ?? '${start.microsecondsSinceEpoch}',
  startAt: start,
  endAt: start.add(length),
  count: count,
);

void main() {
  test('按日期倒序分组，并汇总当天遍数与时长', () {
    final history = PracticeHistory.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 11, 7), 21),
        _session(DateTime(2026, 10, 13, 8), 108),
        _session(
          DateTime(2026, 10, 13, 15),
          42,
          length: const Duration(minutes: 18),
        ),
      ],
      current: null,
      now: DateTime(2026, 10, 13, 20),
    );

    expect(history.groups.length, 2);
    expect(history.groups.first.date, DateTime(2026, 10, 13));
    expect(history.groups.last.date, DateTime(2026, 10, 11));

    final today = history.groups.first;
    expect(today.count, 150);
    expect(today.sessions.length, 2);
    expect(today.duration, const Duration(minutes: 30));
    // 同一天内按开始时间倒序
    expect(today.sessions.first.startAt, DateTime(2026, 10, 13, 15));
  });

  test('合计口径覆盖全部记录', () {
    final history = PracticeHistory.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 9, 30, 7), 100),
        _session(DateTime(2026, 10, 13, 8), 108),
        _session(DateTime(2026, 10, 12, 8), 42),
      ],
      current: null,
      now: DateTime(2026, 10, 13, 20),
    );

    expect(history.totalCount, 250);
    expect(history.totalSessions, 3);
    expect(history.activeDays, 3);
    // 当月只统计 10 月
    expect(history.monthCount, 150);
    expect(history.monthDays, 2);
  });

  test('进行中的功课也计入明细', () {
    final current = _session(
      DateTime(2026, 10, 13, 21),
      7,
      id: 'ongoing',
      length: Duration.zero,
    );
    final history = PracticeHistory.from(
      sessions: <PracticeSession>[_session(DateTime(2026, 10, 13, 8), 108)],
      current: current,
      now: DateTime(2026, 10, 13, 21, 5),
    );

    expect(history.groups.single.sessions.length, 2);
    expect(history.groups.single.sessions.first.id, 'ongoing');
    expect(history.groups.single.count, 115);
    expect(history.totalCount, 115);
  });

  test('空记录与零遍数的记录都不出现在明细里', () {
    final history = PracticeHistory.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 13, 8), 0),
      ],
      current: _session(DateTime(2026, 10, 13, 9), 0, id: 'ongoing'),
      now: DateTime(2026, 10, 13, 20),
    );

    expect(history.isEmpty, isTrue);
    expect(history.groups, isEmpty);
    expect(history.totalCount, 0);
    expect(history.monthDays, 0);
  });
}
