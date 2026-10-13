import 'package:flutter/material.dart';

import '../data/practice_history.dart';
import '../data/practice_scope.dart';
import '../models/practice_session.dart';
import '../theme/app_skin.dart';
import '../utils/date_formats.dart';
import '../widgets/recitation_sheet.dart';

/// 明细页：按天列出每一次功课。
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.onStartPractice});

  /// 没有记录时，引导用户去功课页。
  final VoidCallback onStartPractice;

  @override
  Widget build(BuildContext context) {
    final store = PracticeScope.of(context);
    final now = DateTime.now();
    final history = PracticeHistory.from(
      sessions: store.sessions,
      current: store.current,
      now: now,
    );

    if (history.isEmpty) {
      return _EmptyHistory(onStartPractice: onStartPractice);
    }

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        itemCount: history.groups.length + 1,
        separatorBuilder: (_, index) =>
            SizedBox(height: index == 0 ? 16 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _SummaryCard(history: history, now: now);
          }
          return _DayCard(
            group: history.groups[index - 1],
            now: now,
            currentId: store.current?.id,
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.history, required this.now});

  final PracticeHistory history;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: <Widget>[
            Text(
              '${DateFormats.yearMonth(now)} 功课',
              style: TextStyle(fontSize: 12.5, color: skin.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                _SummaryItem(label: '本月合计', value: '${history.monthCount}', unit: '遍'),
                const _SummaryDivider(),
                _SummaryItem(label: '本月用功', value: '${history.monthDays}', unit: '天'),
                const _SummaryDivider(),
                _SummaryItem(
                  label: '累计功课',
                  value: '${history.totalSessions}',
                  unit: '次',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '累计 ${history.totalCount} 遍 · ${history.activeDays} 天有记录',
              style: TextStyle(fontSize: 12, color: skin.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: skin.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: skin.onSurface,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 11.5, color: skin.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.group,
    required this.now,
    required this.currentId,
  });

  final DayGroup group;
  final DateTime now;

  /// 正在进行中的功课 id，它不在历史记录里，不允许滑动删除。
  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final relative = DateFormats.friendlyDay(group.date, now);
    final isRecent = relative == '今天' || relative == '昨天' || relative == '前天';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Text(
                  '${DateFormats.monthDay(group.date)} 星期${DateFormats.weekday(group.date)}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isRecent) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: skin.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      relative,
                      style: TextStyle(fontSize: 11, color: skin.primary),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  '${group.count} 遍',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: skin.primary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: skin.outlineVariant),
          for (final session in group.sessions)
            _SessionRow(
              session: session,
              isOngoing: session.id == currentId,
              showDivider: session != group.sessions.last,
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isOngoing,
    required this.showDivider,
  });

  final PracticeSession session;
  final bool isOngoing;
  final bool showDivider;

  Future<bool> _confirmDelete(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(
          '${DateFormats.monthDay(session.startAt)} '
          '${DateFormats.timeRange(session.startAt, session.endAt)} '
          '的 ${session.count} 遍将从统计中扣除。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// 打开详情面板；用户在面板里确认删除时，按类型执行删除或放弃。
  Future<void> _openDetail(BuildContext context) async {
    final store = PracticeScope.read(context);
    final removed = await showRecitationSheet(
      context,
      session,
      isOngoing: isOngoing,
    );
    if (removed != true || !context.mounted) return;

    if (isOngoing) {
      store.discardCurrent();
    } else {
      await store.deleteSession(session.id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(isOngoing ? '已放弃本次功课' : '已删除这条记录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final store = PracticeScope.read(context);

    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      DateFormats.timeRange(session.startAt, session.endAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    if (isOngoing) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: skin.jade.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '进行中',
                          style: TextStyle(fontSize: 11, color: skin.jade),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '持续 ${DateFormats.duration(session.duration)}',
                  style: TextStyle(fontSize: 12, color: skin.outline),
                ),
              ],
            ),
          ),
          Text(
            '${session.count} 遍',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: skin.onSurface,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 18, color: skin.outline),
        ],
      ),
    );

    // 点击查看这一次功课里每一遍的具体时间点，也可以在面板里删除。
    final tappable = InkWell(
      onTap: () => _openDetail(context),
      child: row,
    );

    return Column(
      children: <Widget>[
        if (isOngoing)
          tappable
        else
          Dismissible(
            key: ValueKey<String>(session.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: scheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Icon(Icons.delete_outline_rounded, color: scheme.onError),
                  const SizedBox(width: 6),
                  Text(
                    '删除',
                    style: TextStyle(
                      color: scheme.onError,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            confirmDismiss: (_) => _confirmDelete(context),
            onDismissed: (_) => store.deleteSession(session.id),
            child: tappable,
          ),
        if (showDivider) Divider(height: 1, color: skin.outlineVariant),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.onStartPractice});

  final VoidCallback onStartPractice;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: skin.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '还没有功课明细',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: skin.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '每完成一次功课，这里就会留下一条记录',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: skin.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onStartPractice,
                icon: const Icon(Icons.self_improvement_rounded, size: 18),
                label: const Text('去持咒'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
