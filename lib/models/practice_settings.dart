import 'package:flutter/foundation.dart';

import '../theme/app_skin.dart';

/// 功课与界面设置。
@immutable
class PracticeSettings {
  const PracticeSettings({
    this.dailyGoal = 108,
    this.beadCount = 108,
    this.hapticsEnabled = true,
    this.soundEnabled = true,
    this.skinMode = AppSkinMode.system,
  });

  factory PracticeSettings.fromJson(Map<String, dynamic> json) =>
      PracticeSettings(
        dailyGoal: (json['dailyGoal'] as num?)?.toInt() ?? 108,
        beadCount: (json['beadCount'] as num?)?.toInt() ?? 108,
        hapticsEnabled: json['haptics'] as bool? ?? true,
        soundEnabled: json['sound'] as bool? ?? true,
        skinMode: AppSkinMode.fromName(json['skin'] as String?),
      );

  /// 每日目标遍数。
  final int dailyGoal;

  /// 一串念珠的颗数，用于切分念珠进度。
  final int beadCount;

  /// 每次计数是否震动反馈。
  final bool hapticsEnabled;

  /// 每次计数是否播放提示音。
  final bool soundEnabled;

  /// 界面皮肤：跟随系统 / 浅色 / 深色。
  final AppSkinMode skinMode;

  PracticeSettings copyWith({
    int? dailyGoal,
    int? beadCount,
    bool? hapticsEnabled,
    bool? soundEnabled,
    AppSkinMode? skinMode,
  }) => PracticeSettings(
    dailyGoal: dailyGoal ?? this.dailyGoal,
    beadCount: beadCount ?? this.beadCount,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    skinMode: skinMode ?? this.skinMode,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dailyGoal': dailyGoal,
    'beadCount': beadCount,
    'haptics': hapticsEnabled,
    'sound': soundEnabled,
    'skin': skinMode.name,
  };
}
