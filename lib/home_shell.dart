import 'dart:async';

import 'package:flutter/material.dart';

import 'data/practice_scope.dart';
import 'l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final titles = <String>[
      l10n.appTitle,
      l10n.practiceTitle,
      l10n.historyTitle,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.openSettings,
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
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.self_improvement_outlined),
            selectedIcon: const Icon(Icons.self_improvement_rounded),
            label: l10n.navPractice,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: l10n.navHistory,
          ),
        ],
      ),
    );
  }
}
