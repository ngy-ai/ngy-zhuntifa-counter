import 'package:flutter/material.dart';

/// 界面皮肤模式：跟随系统 / 浅色 / 深色。
enum AppSkinMode {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

  const AppSkinMode(this.label);

  final String label;

  ThemeMode get themeMode => switch (this) {
    AppSkinMode.system => ThemeMode.system,
    AppSkinMode.light => ThemeMode.light,
    AppSkinMode.dark => ThemeMode.dark,
  };

  static AppSkinMode fromName(String? name) => values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => AppSkinMode.system,
  );
}

/// 一套皮肤包含的全部视觉参数。
///
/// 浅色「宣纸 · 檀金」与深色「墨夜 · 鎏金」是两套独立设计，而不是把同一套
/// 配色简单反转：渐变、念珠、投影都按各自的底色重新定过，因此分别声明。
@immutable
class AppSkin extends ThemeExtension<AppSkin> {
  const AppSkin({
    required this.brightness,
    required this.scaffoldBackground,
    required this.surface,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.jade,
    required this.saffron,
    required this.heroGradient,
    required this.heroForeground,
    required this.heroMuted,
    required this.heroShadow,
    required this.heroButtonBackground,
    required this.heroButtonForeground,
    required this.accentGradient,
    required this.onAccent,
    required this.onAccentMuted,
    required this.accentShadow,
    required this.beadIdle,
    required this.beadDone,
    required this.beadActive,
    required this.beadGlow,
    required this.chartIdle,
  });

  /// 宣纸 · 檀金（浅色皮肤）：暖白纸底，檀褐主色，实心藏红按钮配白字。
  static const AppSkin light = AppSkin(
    brightness: Brightness.light,
    scaffoldBackground: Color(0xFFFBF7F0),
    surface: Color(0xFFFFFFFF),
    outline: Color(0xFF8C8175),
    outlineVariant: Color(0xFFEAE0CE),
    primary: Color(0xFF9C5520),
    onPrimary: Color(0xFFFFFFFF),
    onSurface: Color(0xFF2B2620),
    onSurfaceVariant: Color(0xFF6E655B),
    jade: Color(0xFF4F7D62),
    saffron: Color(0xFFB4642A),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFC98A3C), Color(0xFFA9531F)],
    ),
    heroForeground: Color(0xFFFFFFFF),
    heroMuted: Color(0xD9FFFFFF),
    heroShadow: Color(0x47A8501C),
    heroButtonBackground: Color(0xFFFFFFFF),
    heroButtonForeground: Color(0xFF9C5520),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFD89A4A), Color(0xFFA8501C)],
    ),
    onAccent: Color(0xFFFFFFFF),
    onAccentMuted: Color(0xC7FFFFFF),
    accentShadow: Color(0x59A8501C),
    beadIdle: Color(0xFFDFD2BA),
    beadDone: Color(0xFFC1902F),
    beadActive: Color(0xFFA8501C),
    beadGlow: Color(0xFFD2A24C),
    chartIdle: Color(0xFFEFE4D3),
  );

  /// 墨夜 · 鎏金（深色皮肤）：墨底暖光，鎏金主色，明亮黄铜按钮配深字。
  static const AppSkin dark = AppSkin(
    brightness: Brightness.dark,
    scaffoldBackground: Color(0xFF141210),
    surface: Color(0xFF1E1A15),
    outline: Color(0xFF8B7F6D),
    outlineVariant: Color(0xFF352D24),
    primary: Color(0xFFDDB264),
    onPrimary: Color(0xFF2A1D0B),
    onSurface: Color(0xFFF0E8DC),
    onSurfaceVariant: Color(0xFFB3A794),
    jade: Color(0xFF6FA98A),
    saffron: Color(0xFFD98E4E),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF4A361C), Color(0xFF241B10)],
    ),
    heroForeground: Color(0xFFF5E9D4),
    heroMuted: Color(0xB8F5E9D4),
    heroShadow: Color(0x73000000),
    heroButtonBackground: Color(0xFFF0E0C2),
    heroButtonForeground: Color(0xFF3A2710),
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFE0B868), Color(0xFFA76D26)],
    ),
    onAccent: Color(0xFF2A1D0B),
    onAccentMuted: Color(0xA62A1D0B),
    accentShadow: Color(0x80000000),
    beadIdle: Color(0xFF352C22),
    beadDone: Color(0xFFB98F45),
    beadActive: Color(0xFFEBC77E),
    beadGlow: Color(0xFFD2A24C),
    chartIdle: Color(0xFF2B241C),
  );

  /// 读取当前皮肤，未注册时按主题明暗回退。
  static AppSkin of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppSkin>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  final Brightness brightness;

  /// 页面底色。
  final Color scaffoldBackground;

  /// 卡片、导航栏等前景容器色。
  final Color surface;
  final Color outline;
  final Color outlineVariant;
  final Color primary;
  final Color onPrimary;
  final Color onSurface;
  final Color onSurfaceVariant;

  /// 竹青点缀色。
  final Color jade;

  /// 藏红点缀色。
  final Color saffron;

  /// 首页今日功课卡的背景渐变。
  final LinearGradient heroGradient;
  final Color heroForeground;
  final Color heroMuted;
  final Color heroShadow;
  final Color heroButtonBackground;
  final Color heroButtonForeground;

  /// 计数表盘与图表高亮所用的品牌渐变。
  final LinearGradient accentGradient;
  final Color onAccent;
  final Color onAccentMuted;
  final Color accentShadow;

  /// 念珠三态与光晕。
  final Color beadIdle;
  final Color beadDone;
  final Color beadActive;
  final Color beadGlow;

  /// 柱状图无数据时的底色。
  final Color chartIdle;

  /// 皮肤为固定预设，不支持局部覆盖。
  @override
  AppSkin copyWith() => this;

  @override
  AppSkin lerp(covariant AppSkin? other, double t) {
    if (other == null) return this;
    return AppSkin(
      brightness: t < 0.5 ? brightness : other.brightness,
      scaffoldBackground: Color.lerp(
        scaffoldBackground,
        other.scaffoldBackground,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant: Color.lerp(
        onSurfaceVariant,
        other.onSurfaceVariant,
        t,
      )!,
      jade: Color.lerp(jade, other.jade, t)!,
      saffron: Color.lerp(saffron, other.saffron, t)!,
      heroGradient:
          Gradient.lerp(heroGradient, other.heroGradient, t)! as LinearGradient,
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      heroShadow: Color.lerp(heroShadow, other.heroShadow, t)!,
      heroButtonBackground: Color.lerp(
        heroButtonBackground,
        other.heroButtonBackground,
        t,
      )!,
      heroButtonForeground: Color.lerp(
        heroButtonForeground,
        other.heroButtonForeground,
        t,
      )!,
      accentGradient:
          Gradient.lerp(accentGradient, other.accentGradient, t)!
              as LinearGradient,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      onAccentMuted: Color.lerp(onAccentMuted, other.onAccentMuted, t)!,
      accentShadow: Color.lerp(accentShadow, other.accentShadow, t)!,
      beadIdle: Color.lerp(beadIdle, other.beadIdle, t)!,
      beadDone: Color.lerp(beadDone, other.beadDone, t)!,
      beadActive: Color.lerp(beadActive, other.beadActive, t)!,
      beadGlow: Color.lerp(beadGlow, other.beadGlow, t)!,
      chartIdle: Color.lerp(chartIdle, other.chartIdle, t)!,
    );
  }
}
