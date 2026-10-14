import 'dart:async';

import 'package:flutter/material.dart';

import 'data/practice_scope.dart';
import 'pages/history_page.dart';
import 'pages/home_page.dart';
import 'pages/practice_page.dart';
import 'pages/settings_sheet.dart';
import 'widgets/total_count_progress.dart';

/// 应用主框架：底部导航在「首页」与「功课」之间切换。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const List<String> _titles = <String>['准提法计数器', '持咒功课', '功课明细'];

  int _index = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 退到后台时立刻落盘，避免连续计数丢失。
    if (state != AppLifecycleState.resumed) {
      unawaited(PracticeScope.read(context).flush());
    }
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final store = PracticeScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: <Widget>[
          IconButton(
            tooltip: '功课设置',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showPracticeSettings(context, store),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const TotalCountProgress(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: <Widget>[
                HomePage(
                  onStartPractice: () => _goTo(1),
                  onViewHistory: () => _goTo(2),
                ),
                const PracticePage(),
                HistoryPage(onStartPractice: () => _goTo(1)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.self_improvement_outlined),
            selectedIcon: Icon(Icons.self_improvement_rounded),
            label: '功课',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: '明细',
          ),
        ],
      ),
    );
  }
}
