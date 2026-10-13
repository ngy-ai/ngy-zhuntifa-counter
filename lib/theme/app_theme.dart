import 'package:flutter/material.dart';

import 'app_skin.dart';

/// 由皮肤参数生成 Material 主题。
abstract final class AppTheme {
  static ThemeData light() => _build(AppSkin.light);

  static ThemeData dark() => _build(AppSkin.dark);

  static ThemeData _build(AppSkin skin) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: skin.primary,
          brightness: skin.brightness,
        ).copyWith(
          primary: skin.primary,
          onPrimary: skin.onPrimary,
          secondary: skin.jade,
          surface: skin.surface,
          onSurface: skin.onSurface,
          onSurfaceVariant: skin.onSurfaceVariant,
          outline: skin.outline,
          outlineVariant: skin.outlineVariant,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: skin.scaffoldBackground,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[skin],
      appBarTheme: AppBarThemeData(
        backgroundColor: skin.scaffoldBackground,
        foregroundColor: skin.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: skin.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: skin.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: skin.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: skin.surface,
        indicatorColor: skin.primary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? skin.primary
                : skin.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? skin.primary
                : skin.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: skin.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: skin.primary,
          foregroundColor: skin.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: skin.onSurface,
          side: BorderSide(color: skin.outline.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: skin.surface,
        selectedColor: skin.primary.withValues(alpha: 0.16),
        side: BorderSide(color: skin.outlineVariant),
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: skin.outlineVariant),
        ),
        labelStyle: TextStyle(fontSize: 13, color: skin.onSurface),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: skin.primary,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: skin.surface,
          foregroundColor: skin.onSurfaceVariant,
          selectedBackgroundColor: skin.primary.withValues(alpha: 0.16),
          selectedForegroundColor: skin.primary,
          side: BorderSide(color: skin.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? skin.onPrimary
              : skin.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? skin.primary
              : skin.outlineVariant,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: skin.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: skin.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: skin.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
