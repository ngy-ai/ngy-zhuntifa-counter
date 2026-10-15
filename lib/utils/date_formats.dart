import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';

/// 日期与时长格式化工具，输出跟随当前界面语言。
///
/// 日期部分走 [DateFormat] 的语言数据（新增语言通常无需改动），
/// 「今天 / 昨天」「1 小时 20 分」这类说法走 [AppLocalizations] 中的文案。
abstract final class DateFormats {
  /// 取当前语言对应的 intl 日期数据名。
  ///
  /// intl 自带的中文日期数据是 `zh`（简体）与 `zh_TW`（繁体），
  /// 繁体中文映射到 `zh_TW`，星期与日期才会写成「週二」这样的繁体形式。
  static String _intlLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
      return 'zh_TW';
    }
    return locale.toLanguageTag().replaceAll('-', '_');
  }

  static AppLocalizations _l10n(BuildContext context) =>
      AppLocalizations.of(context);

  /// 周几简写，如「周二」「Fri」。
  static String weekdayShort(BuildContext context, DateTime date) =>
      DateFormat.E(_intlLocale(context)).format(date);

  /// 完整日期，如「2026年10月13日星期二」「Tuesday, October 13, 2026」。
  static String fullDate(BuildContext context, DateTime date) =>
      DateFormat.yMMMMEEEEd(_intlLocale(context)).format(date);

  /// 月日，如「10月13日」「Oct 13」。
  static String monthDay(BuildContext context, DateTime date) =>
      DateFormat.MMMd(_intlLocale(context)).format(date);

  /// 月日与星期，如「10月13日星期二」「Tuesday, October 13」。
  static String monthDayWeekday(BuildContext context, DateTime date) =>
      DateFormat.MMMMEEEEd(_intlLocale(context)).format(date);

  /// 年月，如「2026年10月」「October 2026」。
  static String yearMonth(BuildContext context, DateTime date) =>
      DateFormat.yMMMM(_intlLocale(context)).format(date);

  /// 时间段，如「09:05 - 09:32」；不满一分钟时只显示开始时间。
  static String timeRange(DateTime start, DateTime end) {
    final from = hourMinute(start);
    if (end.difference(start).inMinutes < 1) return from;
    return '$from - ${hourMinute(end)}';
  }

  /// 时分，如「09:05」。
  static String hourMinute(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';

  /// 时分秒，如「09:05:07」。
  static String hourMinuteSecond(DateTime date) =>
      '${hourMinute(date)}:${date.second.toString().padLeft(2, '0')}';

  /// 简短时长，如「45 秒」「3 分 20 秒」「1 小时 05 分」。
  static String shortSpan(BuildContext context, Duration value) {
    final l10n = _l10n(context);
    if (value.inSeconds < 60) return l10n.spanSeconds(value.inSeconds);
    if (value.inMinutes < 60) {
      final seconds = value.inSeconds % 60;
      return seconds == 0
          ? l10n.spanMinutes(value.inMinutes)
          : l10n.spanMinutesSeconds(value.inMinutes, seconds);
    }
    final minutes = value.inMinutes % 60;
    return minutes == 0
        ? l10n.spanHours(value.inHours)
        : l10n.spanHoursMinutes(value.inHours, minutes);
  }

  /// 「今天 / 昨天 / 前天 / 10月13日」。
  static String friendlyDay(BuildContext context, DateTime date, DateTime now) =>
      switch (_dayDiff(date, now)) {
        0 => _l10n(context).today,
        1 => _l10n(context).yesterday,
        2 => _l10n(context).dayBeforeYesterday,
        _ => monthDay(context, date),
      };

  /// 是否最近三天（今天 / 昨天 / 前天），明细页用它决定是否打标记。
  static bool isRecentDay(DateTime date, DateTime now) =>
      _dayDiff(date, now) <= 2;

  /// 时长，如「1 小时 20 分」「25 分钟」「不足 1 分钟」。
  static String duration(BuildContext context, Duration value) {
    final l10n = _l10n(context);
    if (value.inMinutes < 1) return l10n.durationUnderMinute;
    if (value.inHours < 1) return l10n.durationMinutes(value.inMinutes);
    final minutes = value.inMinutes % 60;
    return minutes == 0
        ? l10n.durationHours(value.inHours)
        : l10n.durationHoursMinutes(value.inHours, minutes);
  }

  /// 「刚刚 / 3 分钟前 / 2 小时前 / 10月13日」。
  static String relative(BuildContext context, DateTime time, DateTime now) {
    final l10n = _l10n(context);
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l10n.relativeJustNow;
    if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24 && diff.inDays <= 0) {
      return l10n.relativeHoursAgo(diff.inHours);
    }
    return friendlyDay(context, time, now);
  }

  /// 与今天相差的天数（今天为 0）。
  static int _dayDiff(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return today.difference(target).inDays;
  }
}
