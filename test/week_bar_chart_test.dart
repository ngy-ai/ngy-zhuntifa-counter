import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/data/practice_stats.dart';
import 'package:ngy_zhuntifa_counter/l10n/gen/app_localizations.dart';
import 'package:ngy_zhuntifa_counter/theme/app_theme.dart';
import 'package:ngy_zhuntifa_counter/widgets/week_bar_chart.dart';

/// 柱状图在窄屏、满格等极端情况下都不能溢出（溢出会直接让测试失败）。
Future<void> _pumpChart(
  WidgetTester tester,
  List<int> counts, {
  double width = 320,
  double height = 84,
  Brightness brightness = Brightness.light,
}) async {
  final today = DateTime(2026, 10, 13);
  final days = <DailyStat>[
    for (var index = 0; index < counts.length; index++)
      DailyStat(
        date: DateTime(2026, 10, 13 - (counts.length - 1 - index)),
        count: counts[index],
        sessions: counts[index] > 0 ? 1 : 0,
      ),
  ];

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: WeekBarChart(days: days, today: today, barHeight: height),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('柱子满格时不会溢出', (WidgetTester tester) async {
    await _pumpChart(
      tester,
      <int>[10, 20, 30, 40, 108, 60, 108],
    );

    expect(find.text('108'), findsNWidgets(2));
    expect(find.text('今日'), findsOneWidget);
  });

  testWidgets('没有数据与全部为零时也能正常渲染', (WidgetTester tester) async {
    await _pumpChart(tester, <int>[0, 0, 0, 0, 0, 0, 0]);
    expect(find.text('今日'), findsOneWidget);

    await _pumpChart(tester, <int>[1, 1, 1, 1, 1, 1, 1]);
    expect(find.text('1'), findsNWidgets(7));
  });

  testWidgets('深色皮肤与很小的柱高都不会溢出', (WidgetTester tester) async {
    await _pumpChart(
      tester,
      <int>[108, 1, 108, 1, 108, 1, 108],
      brightness: Brightness.dark,
      height: 24,
      width: 200,
    );

    expect(find.text('今日'), findsOneWidget);
  });
}
