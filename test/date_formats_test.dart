import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/l10n/gen/app_localizations.dart';
import 'package:ngy_zhuntifa_counter/utils/date_formats.dart';

/// 在指定语言下取一个组件上下文，用于调用 [DateFormats]。
Future<BuildContext> _contextFor(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  final DateTime date = DateTime(2026, 10, 13, 9, 5);
  final DateTime now = DateTime(2026, 10, 15, 12);

  testWidgets('简体中文的日期格式保持原有写法', (WidgetTester tester) async {
    final context = await _contextFor(tester, const Locale('zh'));

    expect(DateFormats.fullDate(context, date), '2026年10月13日星期二');
    expect(DateFormats.monthDay(context, date), '10月13日');
    expect(DateFormats.yearMonth(context, date), '2026年10月');
    expect(DateFormats.weekdayShort(context, date), '周二');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 15), now), '今天');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 14), now), '昨天');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 13), now), '前天');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 1), now), '10月1日');
  });

  testWidgets('英语使用英语日期与时长文案', (WidgetTester tester) async {
    final context = await _contextFor(tester, const Locale('en'));

    expect(DateFormats.fullDate(context, date), 'Tuesday, October 13, 2026');
    expect(DateFormats.monthDay(context, date), 'Oct 13');
    expect(DateFormats.yearMonth(context, date), 'October 2026');
    expect(DateFormats.weekdayShort(context, date), 'Tue');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 15), now), 'Today');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 14), now), 'Yesterday');
  });

  testWidgets('繁体中文使用繁体日期数据', (WidgetTester tester) async {
    final context = await _contextFor(
      tester,
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    );

    expect(DateFormats.fullDate(context, date), '2026年10月13日 星期二');
    expect(DateFormats.weekdayShort(context, date), '週二');
    expect(DateFormats.friendlyDay(context, DateTime(2026, 10, 15), now), '今天');
  });

  testWidgets('时长文案随语言变化', (WidgetTester tester) async {
    final zh = await _contextFor(tester, const Locale('zh'));
    expect(DateFormats.shortSpan(zh, const Duration(seconds: 45)), '45 秒');
    expect(
      DateFormats.shortSpan(zh, const Duration(minutes: 3, seconds: 20)),
      '3 分 20 秒',
    );
    expect(
      DateFormats.shortSpan(zh, const Duration(hours: 1, minutes: 5)),
      '1 小时 5 分',
    );
    expect(DateFormats.duration(zh, const Duration(seconds: 30)), '不足 1 分钟');
    expect(DateFormats.duration(zh, const Duration(minutes: 25)), '25 分钟');
    expect(
      DateFormats.duration(zh, const Duration(hours: 1, minutes: 20)),
      '1 小时 20 分',
    );

    final en = await _contextFor(tester, const Locale('en'));
    expect(DateFormats.shortSpan(en, const Duration(seconds: 45)), '45 sec');
    expect(DateFormats.shortSpan(en, const Duration(seconds: 1)), '1 sec');
    expect(
      DateFormats.duration(en, const Duration(seconds: 30)),
      'Less than 1 min',
    );
    expect(
      DateFormats.duration(en, const Duration(minutes: 25)),
      '25 min',
    );
  });
}
