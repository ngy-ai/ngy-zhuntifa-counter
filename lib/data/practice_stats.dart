import '../models/practice_session.dart';
import '../models/practice_settings.dart';

/// 单日汇总。
class DailyStat {
  const DailyStat({
    required this.date,
    required this.count,
    required this.sessions,
  });

  /// 当天零点。
  final DateTime date;
  final int count;
  final int sessions;
}

/// 由持咒记录推导出的统计数据。
class PracticeStats {
  const PracticeStats({
    required this.todayCount,
    required this.totalCount,
    required this.streakDays,
    required this.activeDays,
    required this.bestDayCount,
    required this.bestDay,
    required this.lastPracticeAt,
    required this.last7Days,
    required this.beadCount,
    required this.todayBeads,
    required this.todayRemainder,
    required this.dailyGoal,
    required this.recentSessions,
  });

  factory PracticeStats.from({
    required List<PracticeSession> sessions,
    required PracticeSession? current,
    required PracticeSettings settings,
    required DateTime now,
    int recentLimit = 5,
  }) {
    final effective = <PracticeSession>[
      for (final session in sessions)
        if (session.isEffective) session,
      if (current != null && current.isEffective) current,
    ];

    final byDay = <DateTime, int>{};
    final sessionsByDay = <DateTime, int>{};
    DateTime? lastPracticeAt;
    for (final session in effective) {
      final key = session.dayKey;
      byDay.update(key, (value) => value + session.count, ifAbsent: () => session.count);
      sessionsByDay.update(key, (value) => value + 1, ifAbsent: () => 1);
      if (lastPracticeAt == null || session.endAt.isAfter(lastPracticeAt)) {
        lastPracticeAt = session.endAt;
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    final todayCount = byDay[today] ?? 0;
    final totalCount = byDay.values.fold<int>(0, (sum, value) => sum + value);

    var bestDayCount = 0;
    DateTime? bestDay;
    byDay.forEach((day, count) {
      if (count > bestDayCount) {
        bestDayCount = count;
        bestDay = day;
      }
    });

    final recent = <PracticeSession>[...effective]
      ..sort((a, b) => b.endAt.compareTo(a.endAt));

    final beadCount = settings.beadCount > 0 ? settings.beadCount : 108;

    return PracticeStats(
      todayCount: todayCount,
      totalCount: totalCount,
      streakDays: _streakOf(byDay, today),
      activeDays: byDay.length,
      bestDayCount: bestDayCount,
      bestDay: bestDay,
      lastPracticeAt: lastPracticeAt,
      last7Days: <DailyStat>[
        for (var offset = 6; offset >= 0; offset--)
          _dayStat(byDay, sessionsByDay, today, offset),
      ],
      beadCount: beadCount,
      todayBeads: todayCount ~/ beadCount,
      todayRemainder: todayCount % beadCount,
      dailyGoal: settings.dailyGoal,
      recentSessions: recent.take(recentLimit).toList(growable: false),
    );
  }

  static DailyStat _dayStat(
    Map<DateTime, int> byDay,
    Map<DateTime, int> sessionsByDay,
    DateTime today,
    int offset,
  ) {
    final day = DateTime(today.year, today.month, today.day - offset);
    return DailyStat(
      date: day,
      count: byDay[day] ?? 0,
      sessions: sessionsByDay[day] ?? 0,
    );
  }

  /// 连续持咒天数：从今天（或昨天）往前数连续有记录的天数。
  static int _streakOf(Map<DateTime, int> byDay, DateTime today) {
    var cursor = today;
    if ((byDay[cursor] ?? 0) <= 0) {
      cursor = DateTime(today.year, today.month, today.day - 1);
    }
    var streak = 0;
    while ((byDay[cursor] ?? 0) > 0) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  final int todayCount;
  final int totalCount;

  /// 连续持咒天数。
  final int streakDays;

  /// 有持咒记录的总天数。
  final int activeDays;
  final int bestDayCount;
  final DateTime? bestDay;
  final DateTime? lastPracticeAt;
  final List<DailyStat> last7Days;
  final int beadCount;

  /// 今日已圆满的整串数。
  final int todayBeads;

  /// 今日当前未满一串的遍数。
  final int todayRemainder;
  final int dailyGoal;
  final List<PracticeSession> recentSessions;

  /// 今日目标完成度，范围 0~1。
  double get goalProgress {
    if (dailyGoal <= 0) return 0;
    return (todayCount / dailyGoal).clamp(0.0, 1.0);
  }

  bool get goalReached => dailyGoal > 0 && todayCount >= dailyGoal;

  int get weekCount => last7Days.fold<int>(0, (sum, day) => sum + day.count);
}
