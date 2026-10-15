import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/practice_stats.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_skin.dart';
import '../utils/date_formats.dart';

/// 近七日持咒柱状图。
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({
    super.key,
    required this.days,
    required this.today,
    this.barHeight = 84,
  });

  final List<DailyStat> days;
  final DateTime today;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final maxCount = days.fold<int>(0, (peak, day) => math.max(peak, day.count));
    final scale = math.max(maxCount, 1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final day in days)
          Expanded(
            child: _Bar(
              day: day,
              isToday:
                  day.date.year == today.year &&
                  day.date.month == today.month &&
                  day.date.day == today.day,
              fillRatio: day.count / scale,
              barHeight: barHeight,
              todayGradient: skin.accentGradient,
              idleColor: skin.chartIdle,
              labelColor: skin.onSurfaceVariant,
              todayColor: skin.primary,
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.isToday,
    required this.fillRatio,
    required this.barHeight,
    required this.todayGradient,
    required this.idleColor,
    required this.labelColor,
    required this.todayColor,
  });

  final DailyStat day;
  final bool isToday;
  final double fillRatio;
  final double barHeight;
  final LinearGradient todayGradient;
  final Color idleColor;
  final Color labelColor;
  final Color todayColor;

  @override
  Widget build(BuildContext context) {
    final hasValue = day.count > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              // 必须锁定单行：位数多时在窄列里换行会把柱子挤出卡片。
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Text(
                  hasValue ? '${day.count}' : '',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isToday ? todayColor : labelColor,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 柱子占用标签以外的剩余空间，满格时也不会超出卡片高度。
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final available = constraints.maxHeight;
                    final minimum = math.min(8.0, available);
                    final height = hasValue
                        ? math.max(available * fillRatio, minimum)
                        : math.min(4.0, available);
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: height,
                        width: 16,
                        decoration: BoxDecoration(
                          color: hasValue && !isToday ? idleColor : null,
                          gradient: hasValue && isToday ? todayGradient : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isToday
              ? AppLocalizations.of(context).chartToday
              : DateFormats.weekdayShort(context, day.date),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
            color: isToday ? todayColor : labelColor,
          ),
        ),
      ],
    );
  }
}
