import 'package:flutter/material.dart';

import '../data/practice_scope.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_skin.dart';

/// 累计持咒进度条：标题栏下方常驻，首页 / 功课 / 明细共用。
///
/// 展示「累计持咒遍数 / 100 万遍」的完成度，每记一遍都会即时刷新。
class TotalCountProgress extends StatelessWidget {
  const TotalCountProgress({super.key});

  /// 累计目标：一百万遍。
  static const int targetCount = 1000000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final totalCount = PracticeScope.of(context).stats().totalCount;
    final ratio = (totalCount / targetCount).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: skin.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: skin.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                l10n.totalCountLabel,
                style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: _thousands(totalCount),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      TextSpan(
                        text:
                            ' / ${_thousands(targetCount)} ${l10n.unitCount}',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(child: _ProgressTrack(ratio: ratio, skin: skin)),
              const SizedBox(width: 10),
              Text(
                '${(totalCount / targetCount * 100).toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: skin.primary,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 千分位，如 1234567 → 1,234,567。
  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}

/// 圆角进度轨道，按品牌渐变填充。
class _ProgressTrack extends StatelessWidget {
  const _ProgressTrack({required this.ratio, required this.skin});

  final double ratio;
  final AppSkin skin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: skin.chartIdle),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: skin.accentGradient),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
