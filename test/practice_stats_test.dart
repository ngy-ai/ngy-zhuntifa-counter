import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_stats.dart';
import 'package:ngy_zhuntifa_counter/models/practice_session.dart';
import 'package:ngy_zhuntifa_counter/models/practice_settings.dart';

PracticeSession _session(DateTime start, int count) => PracticeSession(
  id: start.microsecondsSinceEpoch.toString(),
  startAt: start,
  endAt: start.add(const Duration(minutes: 12)),
  count: count,
);

void main() {
  const settings = PracticeSettings();

  test('今日与累计遍数按日期聚合', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 13, 8), 108),
        _session(DateTime(2026, 10, 13, 15), 42),
        _session(DateTime(2026, 10, 12, 9), 216),
      ],
      current: _session(DateTime(2026, 10, 13, 19), 21),
      settings: settings,
      now: DateTime(2026, 10, 13, 20),
    );

    expect(stats.todayCount, 171);
    expect(stats.totalCount, 387);
    expect(stats.activeDays, 2);
    expect(stats.todayBeads, 1);
    expect(stats.todayRemainder, 63);
    expect(stats.goalReached, isTrue);
    expect(stats.goalProgress, 1);
  });

  test('连续持咒天数从今天往前累计', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 13, 8), 21),
        _session(DateTime(2026, 10, 12, 8), 21),
        _session(DateTime(2026, 10, 11, 8), 21),
        _session(DateTime(2026, 10, 9, 8), 21),
      ],
      current: null,
      settings: settings,
      now: DateTime(2026, 10, 13, 20),
    );

    expect(stats.streakDays, 3);
    expect(stats.activeDays, 4);
  });

  test('今天尚未持咒时连续天数从昨天起算', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 12, 8), 21),
        _session(DateTime(2026, 10, 11, 8), 21),
      ],
      current: null,
      settings: settings,
      now: DateTime(2026, 10, 13, 6),
    );

    expect(stats.todayCount, 0);
    expect(stats.streakDays, 2);
  });

  test('中间断档时连续天数归零', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 10, 8), 21),
      ],
      current: null,
      settings: settings,
      now: DateTime(2026, 10, 13, 6),
    );

    expect(stats.streakDays, 0);
  });

  test('近七日包含七天且最后一天为今天', () {
    final now = DateTime(2026, 10, 13, 20);
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 13, 8), 30),
        _session(DateTime(2026, 10, 7, 8), 50),
      ],
      current: null,
      settings: settings,
      now: now,
    );

    expect(stats.last7Days.length, 7);
    expect(stats.last7Days.last.date, DateTime(2026, 10, 13));
    expect(stats.last7Days.first.date, DateTime(2026, 10, 7));
    expect(stats.last7Days.first.count, 50);
    expect(stats.last7Days.last.count, 30);
    expect(stats.weekCount, 80);
  });

  test('单日最高取有记录日期的最大值', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[
        _session(DateTime(2026, 10, 13, 8), 30),
        _session(DateTime(2026, 10, 12, 8), 500),
      ],
      current: null,
      settings: settings,
      now: DateTime(2026, 10, 13, 20),
    );

    expect(stats.bestDayCount, 500);
    expect(stats.bestDay, DateTime(2026, 10, 12));
  });

  test('每串颗数可由设置调整', () {
    final stats = PracticeStats.from(
      sessions: <PracticeSession>[_session(DateTime(2026, 10, 13, 8), 60)],
      current: null,
      settings: settings.copyWith(beadCount: 27),
      now: DateTime(2026, 10, 13, 20),
    );

    expect(stats.todayBeads, 2);
    expect(stats.todayRemainder, 6);
  });
}
