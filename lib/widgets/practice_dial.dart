import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';
import '../theme/app_skin.dart';

/// 持咒计数表盘：中心是大号计数按钮，外圈是一串念珠，显示本串进度。
class PracticeDial extends StatefulWidget {
  const PracticeDial({
    super.key,
    required this.sessionCount,
    required this.beadCount,
    required this.onTap,
  });

  /// 本次功课已持咒遍数。
  final int sessionCount;

  /// 一串念珠的颗数。
  final int beadCount;

  final VoidCallback onTap;

  @override
  State<PracticeDial> createState() => _PracticeDialState();
}

class _PracticeDialState extends State<PracticeDial> {
  bool _pressed = false;

  int get _beadCount => widget.beadCount > 0 ? widget.beadCount : 108;

  /// 本串已完成的颗数，刚好圆满一串时点亮整圈。
  int get _filledBeads {
    if (widget.sessionCount <= 0) return 0;
    final remainder = widget.sessionCount % _beadCount;
    return remainder == 0 ? _beadCount : remainder;
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.max(
          160.0,
          math.min(constraints.maxWidth, constraints.maxHeight),
        );
        final geometry = _DialGeometry(size: size, beadCount: _beadCount);
        final double innerDiameter = geometry.innerRadius * 2;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: AnimatedScale(
              scale: _pressed ? 0.965 : 1,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _setPressed(true),
                onTapUp: (_) => _setPressed(false),
                onTapCancel: () => _setPressed(false),
                onTap: widget.onTap,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Container(
                      width: innerDiameter,
                      height: innerDiameter,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: skin.accentGradient,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: skin.accentShadow,
                            blurRadius: 28,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _BeadRingPainter(
                            geometry: geometry,
                            filled: _filledBeads,
                            idleColor: skin.beadIdle,
                            doneColor: skin.beadDone,
                            activeColor: skin.beadActive,
                            glowColor: skin.beadGlow,
                          ),
                        ),
                      ),
                    ),
                    _DialLabel(
                      sessionCount: widget.sessionCount,
                      filled: _filledBeads,
                      beadCount: _beadCount,
                      scale: geometry.innerRadius,
                      foreground: skin.onAccent,
                      muted: skin.onAccentMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialLabel extends StatelessWidget {
  const _DialLabel({
    required this.sessionCount,
    required this.filled,
    required this.beadCount,
    required this.scale,
    required this.foreground,
    required this.muted,
  });

  final int sessionCount;
  final int filled;
  final int beadCount;
  final double scale;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.practiceSessionLabel,
          style: TextStyle(fontSize: 13, letterSpacing: 6, color: muted),
        ),
        const SizedBox(height: 2),
        Text(
          '$sessionCount',
          style: TextStyle(
            fontSize: scale * 0.56,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: foreground,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        Text(l10n.unitCount, style: TextStyle(fontSize: 13, color: muted)),
        SizedBox(height: scale * 0.1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: foreground.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$filled / $beadCount',
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// 表盘几何计算：念珠所在半径、珠间距、内圆半径。
class _DialGeometry {
  _DialGeometry({required this.size, required this.beadCount}) {
    ringRadius = size / 2 - 9;
    pitch = 2 * math.pi * ringRadius / beadCount;
    beadRadius = (pitch * 0.30).clamp(1.0, 4.2).toDouble();
    innerRadius = ringRadius - math.max(pitch * 1.35, beadRadius * 3.4);
  }

  final double size;
  final int beadCount;
  late final double ringRadius;
  late final double pitch;
  late final double beadRadius;
  late final double innerRadius;
}

class _BeadRingPainter extends CustomPainter {
  _BeadRingPainter({
    required this.geometry,
    required this.filled,
    required this.idleColor,
    required this.doneColor,
    required this.activeColor,
    required this.glowColor,
  });

  final _DialGeometry geometry;
  final int filled;
  final Color idleColor;
  final Color doneColor;
  final Color activeColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.fill;
    final step = 2 * math.pi / geometry.beadCount;

    for (var index = 0; index < geometry.beadCount; index++) {
      final angle = -math.pi / 2 + index * step;
      final position =
          center +
          Offset(
            math.cos(angle) * geometry.ringRadius,
            math.sin(angle) * geometry.ringRadius,
          );

      if (index < filled) {
        final isCurrent = index == filled - 1;
        if (isCurrent) {
          canvas.drawCircle(
            position,
            geometry.beadRadius * 2.9,
            Paint()..color = glowColor.withValues(alpha: 0.28),
          );
        }
        paint.color = isCurrent ? activeColor : doneColor;
        canvas.drawCircle(
          position,
          isCurrent ? geometry.beadRadius * 1.55 : geometry.beadRadius,
          paint,
        );
      } else {
        paint.color = index == filled
            ? glowColor.withValues(alpha: 0.55)
            : idleColor;
        canvas.drawCircle(position, geometry.beadRadius * 0.72, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BeadRingPainter oldDelegate) =>
      oldDelegate.filled != filled ||
      oldDelegate.geometry.size != geometry.size ||
      oldDelegate.geometry.beadCount != geometry.beadCount ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.doneColor != doneColor ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.glowColor != glowColor;
}
