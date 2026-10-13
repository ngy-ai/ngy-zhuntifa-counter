/// 中文日期与时长格式化工具。
abstract final class DateFormats {
  static const List<String> _weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];

  /// 周几，如「五」。
  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  /// 完整日期，如「2026年10月13日 星期二」。
  static String fullDate(DateTime date) =>
      '${date.year}年${date.month}月${date.day}日 星期${weekday(date)}';

  /// 月日，如「10月13日」。
  static String monthDay(DateTime date) => '${date.month}月${date.day}日';

  /// 年月，如「2026年10月」。
  static String yearMonth(DateTime date) => '${date.year}年${date.month}月';

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
  static String shortSpan(Duration value) {
    if (value.inSeconds < 60) return '${value.inSeconds} 秒';
    if (value.inMinutes < 60) {
      final seconds = value.inSeconds % 60;
      return seconds == 0 ? '${value.inMinutes} 分' : '${value.inMinutes} 分 $seconds 秒';
    }
    final minutes = value.inMinutes % 60;
    return minutes == 0 ? '${value.inHours} 小时' : '${value.inHours} 小时 $minutes 分';
  }

  /// 「今天 / 昨天 / 前天 / 10月13日」。
  static String friendlyDay(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    return switch (diff) {
      0 => '今天',
      1 => '昨天',
      2 => '前天',
      _ => monthDay(date),
    };
  }

  /// 时长，如「1 小时 20 分」「25 分钟」「不足 1 分钟」。
  static String duration(Duration value) {
    if (value.inMinutes < 1) return '不足 1 分钟';
    if (value.inHours < 1) return '${value.inMinutes} 分钟';
    final minutes = value.inMinutes % 60;
    return minutes == 0
        ? '${value.inHours} 小时'
        : '${value.inHours} 小时 $minutes 分';
  }

  /// 「刚刚 / 3 分钟前 / 2 小时前 / 10月13日」。
  static String relative(DateTime time, DateTime now) {
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24 && diff.inDays <= 0) return '${diff.inHours} 小时前';
    return friendlyDay(time, now);
  }
}
