import 'package:flutter/material.dart';

import '../data/practice_scope.dart';
import '../data/practice_stats.dart';
import '../models/practice_session.dart';
import '../theme/app_skin.dart';
import '../utils/date_formats.dart';
import '../widgets/stat_tile.dart';
import '../widgets/week_bar_chart.dart';

/// 首页：展示持咒统计概览。
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onStartPractice,
    required this.onViewHistory,
  });

  final VoidCallback onStartPractice;

  /// 打开功课明细。
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final store = PracticeScope.of(context);
    final now = DateTime.now();
    final stats = store.stats(now);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: <Widget>[
          _TodayCard(
            stats: stats,
            now: now,
            onStartPractice: onStartPractice,
          ),
          const SizedBox(height: 16),
          _StatsGrid(stats: stats, now: now),
          const SizedBox(height: 16),
          _WeekCard(stats: stats, now: now),
          const SizedBox(height: 16),
          _RecentCard(
            stats: stats,
            now: now,
            onViewHistory: onViewHistory,
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.stats,
    required this.now,
    required this.onStartPractice,
  });

  final PracticeStats stats;
  final DateTime now;
  final VoidCallback onStartPractice;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final goal = stats.dailyGoal;
    final remaining = (goal - stats.todayCount).clamp(0, goal);

    return Container(
      decoration: BoxDecoration(
        gradient: skin.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: skin.heroShadow,
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '今日持咒 · ${DateFormats.fullDate(now)}',
            style: TextStyle(fontSize: 12.5, color: skin.heroMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: skin.heroForeground),
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${stats.todayCount}',
                            style: const TextStyle(
                              fontSize: 46,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                              fontFeatures: <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          TextSpan(
                            text: ' 遍',
                            style: TextStyle(
                              fontSize: 14,
                              color: skin.heroMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stats.goalReached
                          ? '今日目标 $goal 遍已达成，随喜'
                          : '距今日目标还差 $remaining 遍',
                      style: TextStyle(fontSize: 12.5, color: skin.heroMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: CircularProgressIndicator(
                        value: stats.goalProgress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        backgroundColor: skin.heroForeground.withValues(
                          alpha: 0.25,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          skin.heroForeground,
                        ),
                      ),
                    ),
                    Text(
                      '${(stats.goalProgress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: skin.heroForeground,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStartPractice,
              style: FilledButton.styleFrom(
                backgroundColor: skin.heroButtonBackground,
                foregroundColor: skin.heroButtonForeground,
                minimumSize: const Size.fromHeight(46),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.self_improvement_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('开始持咒', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.now});

  final PracticeStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: StatTile(
                  icon: Icons.graphic_eq_rounded,
                  label: '累计持咒',
                  value: '${stats.totalCount}',
                  unit: '遍',
                  caption: '共 ${stats.activeDays} 天有记录',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.local_fire_department_rounded,
                  label: '连续持咒',
                  value: '${stats.streakDays}',
                  unit: '天',
                  accent: skin.saffron,
                  caption: stats.streakDays > 1
                      ? '保持相续，勿令间断'
                      : '今日已开始用功',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: StatTile(
                  icon: Icons.event_available_rounded,
                  label: '累计功课天数',
                  value: '${stats.activeDays}',
                  unit: '天',
                  accent: skin.jade,
                  caption: '近七日 ${stats.weekCount} 遍',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icon: Icons.emoji_events_rounded,
                  label: '单日最高',
                  value: '${stats.bestDayCount}',
                  unit: '遍',
                  accent: skin.primary,
                  caption: stats.bestDay == null
                      ? '还没有记录'
                      : DateFormats.friendlyDay(stats.bestDay!, now),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats, required this.now});

  final PracticeStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '近七日',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '合计 ${stats.weekCount} 遍',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeekBarChart(days: stats.last7Days, today: now),
          ],
        ),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({
    required this.stats,
    required this.now,
    required this.onViewHistory,
  });

  final PracticeStats stats;
  final DateTime now;
  final VoidCallback onViewHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sessions = stats.recentSessions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '最近功课',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '全部明细',
                    style: TextStyle(fontSize: 13, color: scheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: Text(
                    '还没有功课记录，去持咒吧',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final session in sessions) ...<Widget>[
                _RecentTile(session: session, now: now),
                if (session != sessions.last)
                  Divider(height: 1, color: scheme.outlineVariant),
              ],
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.session, required this.now});

  final PracticeSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.spa_rounded,
              size: 19,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${DateFormats.friendlyDay(session.startAt, now)} '
                  '${DateFormats.hourMinute(session.startAt)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '持续 ${DateFormats.duration(session.duration)}',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ),
          Text(
            '${session.count} 遍',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.primary,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
