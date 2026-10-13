import '../models/practice_session.dart';

/// 某一天的功课明细。
class DayGroup {
  const DayGroup({required this.date, required this.sessions});

  /// 当天零点。
  final DateTime date;

  /// 当天各次功课，按开始时间倒序。
  final List<PracticeSession> sessions;

  int get count => sessions.fold(0, (sum, session) => sum + session.count);

  Duration get duration =>
      sessions.fold(Duration.zero, (sum, session) => sum + session.duration);
}

/// 明细页所需的全部数据：按天分组的记录与汇总数字。
class PracticeHistory {
  const PracticeHistory({
    required this.groups,
    required this.totalCount,
    required this.totalSessions,
    required this.activeDays,
    required this.monthCount,
    required this.monthDays,
  });

  factory PracticeHistory.from({
    required List<PracticeSession> sessions,
    required PracticeSession? current,
    required DateTime now,
  }) {
    final effective = <PracticeSession>[
      for (final session in sessions)
        if (session.isEffective) session,
      if (current != null && current.isEffective) current,
    ];

    final byDay = <DateTime, List<PracticeSession>>{};
    for (final session in effective) {
      byDay.putIfAbsent(session.dayKey, () => <PracticeSession>[]).add(session);
    }

    final groups =
        byDay.entries
            .map((entry) {
              entry.value.sort((a, b) => b.startAt.compareTo(a.startAt));
              return DayGroup(date: entry.key, sessions: entry.value);
            })
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final monthGroups = groups.where(
      (group) =>
          group.date.year == now.year && group.date.month == now.month,
    );

    return PracticeHistory(
      groups: groups,
      totalCount: groups.fold(0, (sum, group) => sum + group.count),
      totalSessions: groups.fold(
        0,
        (sum, group) => sum + group.sessions.length,
      ),
      activeDays: groups.length,
      monthCount: monthGroups.fold(0, (sum, group) => sum + group.count),
      monthDays: monthGroups.length,
    );
  }

  /// 按日期倒序的分组。
  final List<DayGroup> groups;

  /// 累计持咒遍数。
  final int totalCount;

  /// 累计功课次数。
  final int totalSessions;

  /// 有记录的天数。
  final int activeDays;

  /// 当月持咒遍数。
  final int monthCount;

  /// 当月有记录的天数。
  final int monthDays;

  bool get isEmpty => groups.isEmpty;
}
