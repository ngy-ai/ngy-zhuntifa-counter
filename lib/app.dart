import 'package:flutter/material.dart';

import 'data/practice_scope.dart';
import 'data/practice_store.dart';
import 'home_shell.dart';
import 'theme/app_theme.dart';

class ZhuntiCounterApp extends StatelessWidget {
  const ZhuntiCounterApp({super.key, required this.store});

  final PracticeStore store;

  @override
  Widget build(BuildContext context) {
    return PracticeScope(
      store: store,
      // 监听仓库，皮肤切换后立即重建 MaterialApp。
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: '准提法计数器',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: store.settings.skinMode.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
