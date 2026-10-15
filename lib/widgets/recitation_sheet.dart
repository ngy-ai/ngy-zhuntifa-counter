import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/practice_session.dart';
import '../theme/app_skin.dart';
import '../utils/date_formats.dart';

/// 打开某次功课的「逐次持咒时间」面板。
///
/// 面板里可以删除这条记录；用户确认删除时返回 true，由调用方执行删除。
/// [isOngoing] 表示这是进行中的一次功课（还没写入历史）。
Future<bool?> showRecitationSheet(
  BuildContext context,
  PracticeSession session, {
  bool isOngoing = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RecitationSheet(session: session, isOngoing: isOngoing),
  );
}

class _RecitationSheet extends StatelessWidget {
  const _RecitationSheet({required this.session, required this.isOngoing});

  final PracticeSession session;

  /// 进行中的功课：删除意味着放弃本次计数。
  final bool isOngoing;

  Future<void> _requestDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isOngoing ? l10n.sessionDiscardTitle : l10n.recordDeleteTitle,
        ),
        content: Text(
          isOngoing
              ? l10n.sessionDiscardBody(session.count)
              : l10n.recordDeleteBody(
                  DateFormats.monthDay(context, session.startAt),
                  DateFormats.timeRange(session.startAt, session.endAt),
                  session.count,
                ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            child: Text(isOngoing ? l10n.discard : l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final times = session.markTimes;
    final averageGap = times.length > 1
        ? Duration(
            milliseconds:
                (times.last.difference(times.first).inMilliseconds /
                        (times.length - 1))
                    .round(),
          )
        : null;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DateFormats.monthDayWeekday(context, session.startAt),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.sessionSubtitle(
                    DateFormats.timeRange(session.startAt, session.endAt),
                    DateFormats.duration(context, session.duration),
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: skin.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    _Metric(
                      label: l10n.metricTotal,
                      value: l10n.countTimes(session.count),
                    ),
                    _Metric(
                      label: l10n.metricDuration,
                      value: DateFormats.shortSpan(context, session.duration),
                    ),
                    _Metric(
                      label: l10n.metricAverageGap,
                      value: averageGap == null
                          ? '—'
                          : DateFormats.shortSpan(context, averageGap),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: skin.outlineVariant),
          if (times.isEmpty)
            const Expanded(child: _NoMarksNotice())
          else ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        l10n.sheetMarkTimes,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: skin.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        l10n.sheetMarkCount(times.length),
                        style: TextStyle(fontSize: 12, color: skin.outline),
                      ),
                    ],
                  ),
                  // 升级前记下的遍数没有时间点，这里说明差异，避免看起来像丢数据
                  if (times.length != session.count) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      l10n.sheetLegacyMarks(session.count, times.length),
                      style: TextStyle(fontSize: 11.5, color: skin.outline),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: times.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: skin.outlineVariant),
                itemBuilder: (context, index) => _MarkRow(
                  index: index,
                  time: times[index],
                  gap: index == 0
                      ? null
                      : times[index].difference(times[index - 1]),
                ),
              ),
            ),
          ],
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _requestDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    isOngoing ? l10n.sessionDiscard : l10n.recordDelete,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: skin.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: skin.onSurface,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({required this.index, required this.time, required this.gap});

  /// 从 0 开始的序号。
  final int index;
  final DateTime time;

  /// 与上一次持咒的间隔，第一次为 null。
  final Duration? gap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 68,
            child: Text(
              l10n.sheetMarkIndex(index + 1),
              style: TextStyle(fontSize: 12.5, color: skin.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              DateFormats.hourMinuteSecond(time),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: skin.onSurface,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (gap != null)
            Text(
              '+${DateFormats.shortSpan(context, gap!)}',
              style: TextStyle(
                fontSize: 12,
                color: skin.outline,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoMarksNotice extends StatelessWidget {
  const _NoMarksNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.schedule_outlined, size: 40, color: skin.outlineVariant),
            const SizedBox(height: 14),
            Text(
              l10n.sheetOnlyTotalTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: skin.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.sheetOnlyTotalHint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: skin.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
