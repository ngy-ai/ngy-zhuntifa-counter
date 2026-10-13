import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/theme/app_skin.dart';
import 'package:ngy_zhuntifa_counter/theme/app_theme.dart';

/// WCAG 对比度：1 表示完全相同，正文建议 ≥ 4.5，大号文字 ≥ 3。
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  test('两套皮肤都注册进了主题', () {
    expect(AppTheme.light().extension<AppSkin>(), AppSkin.light);
    expect(AppTheme.dark().extension<AppSkin>(), AppSkin.dark);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(
      AppTheme.light().scaffoldBackgroundColor,
      AppSkin.light.scaffoldBackground,
    );
    expect(
      AppTheme.dark().scaffoldBackgroundColor,
      AppSkin.dark.scaffoldBackground,
    );
    expect(AppTheme.light().colorScheme.primary, AppSkin.light.primary);
    expect(AppTheme.dark().colorScheme.primary, AppSkin.dark.primary);
  });

  test('两套皮肤都满足可读性对比度', () {
    for (final skin in <AppSkin>[AppSkin.light, AppSkin.dark]) {
      final name = skin.brightness == Brightness.dark ? '深色皮肤' : '浅色皮肤';

      expect(
        _contrast(skin.onSurface, skin.surface),
        greaterThanOrEqualTo(4.5),
        reason: '$name 的正文与卡片底色对比度不足',
      );
      expect(
        _contrast(skin.onSurfaceVariant, skin.surface),
        greaterThanOrEqualTo(4.5),
        reason: '$name 的次要文字对比度不足',
      );
      expect(
        _contrast(skin.primary, skin.surface),
        greaterThanOrEqualTo(3),
        reason: '$name 的主色文字对比度不足',
      );
      expect(
        _contrast(skin.onAccent, skin.accentGradient.colors.last),
        greaterThanOrEqualTo(3),
        reason: '$name 的计数按钮文字在渐变最深处对比度不足',
      );
      expect(
        _contrast(skin.heroForeground, skin.heroGradient.colors.last),
        greaterThanOrEqualTo(4.5),
        reason: '$name 的今日功课卡文字对比度不足',
      );
      expect(
        _contrast(skin.heroButtonForeground, skin.heroButtonBackground),
        greaterThanOrEqualTo(4.5),
        reason: '$name 的今日功课卡按钮对比度不足',
      );
    }
  });

  test('两套皮肤是不同配色，念珠与图表颜色可区分', () {
    expect(AppSkin.light.surface, isNot(AppSkin.dark.surface));
    expect(AppSkin.light.accentGradient, isNot(AppSkin.dark.accentGradient));

    for (final skin in <AppSkin>[AppSkin.light, AppSkin.dark]) {
      final name = skin.brightness.name;
      // 已完成的念珠必须能与未完成的区分开。
      expect(
        _contrast(skin.beadDone, skin.beadIdle),
        greaterThanOrEqualTo(1.6),
        reason: '$name 的念珠已完成/未完成状态不易区分',
      );
      expect(
        _contrast(skin.beadActive, skin.beadIdle),
        greaterThanOrEqualTo(1.8),
        reason: '$name 的当前念珠不够醒目',
      );
      // 念珠画在页面底色上。
      expect(
        _contrast(skin.beadIdle, skin.scaffoldBackground),
        greaterThanOrEqualTo(1.15),
        reason: '$name 的念珠在底色上看不清',
      );
    }
  });

  test('皮肤可以插值，供主题切换动画使用', () {
    final mid = AppSkin.light.lerp(AppSkin.dark, 0.5);

    expect(mid.scaffoldBackground, isNot(AppSkin.light.scaffoldBackground));
    expect(mid.scaffoldBackground, isNot(AppSkin.dark.scaffoldBackground));
    expect(
      mid.accentGradient.colors.first,
      isNot(AppSkin.light.accentGradient.colors.first),
    );

    // 插值到两端时应当完全落在对应皮肤上。
    final end = AppSkin.light.lerp(AppSkin.dark, 1);
    expect(end.scaffoldBackground, AppSkin.dark.scaffoldBackground);
    expect(end.primary, AppSkin.dark.primary);
    expect(end.beadActive, AppSkin.dark.beadActive);
    expect(end.accentGradient.colors, AppSkin.dark.accentGradient.colors);

    final start = AppSkin.light.lerp(AppSkin.dark, 0);
    expect(start.scaffoldBackground, AppSkin.light.scaffoldBackground);
    expect(start.beadActive, AppSkin.light.beadActive);

    expect(AppSkin.light.lerp(null, 1), same(AppSkin.light));
  });

  test('皮肤模式与 ThemeMode 对应，并能从存档还原', () {
    expect(AppSkinMode.system.themeMode, ThemeMode.system);
    expect(AppSkinMode.light.themeMode, ThemeMode.light);
    expect(AppSkinMode.dark.themeMode, ThemeMode.dark);

    expect(AppSkinMode.fromName('dark'), AppSkinMode.dark);
    expect(AppSkinMode.fromName('light'), AppSkinMode.light);
    expect(AppSkinMode.fromName('system'), AppSkinMode.system);
    expect(AppSkinMode.fromName(null), AppSkinMode.system);
    expect(AppSkinMode.fromName('未知皮肤'), AppSkinMode.system);
  });
}
