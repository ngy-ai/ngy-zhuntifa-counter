import 'package:flutter/material.dart';

import 'data/practice_scope.dart';
import 'data/practice_store.dart';
import 'home_shell.dart';
import 'l10n/gen/app_localizations.dart';
import 'theme/app_theme.dart';

class ZhuntiCounterApp extends StatelessWidget {
  const ZhuntiCounterApp({super.key, required this.store});

  final PracticeStore store;

  @override
  Widget build(BuildContext context) {
    return PracticeScope(
      store: store,
      // 监听仓库，皮肤或语言切换后立即重建 MaterialApp。
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: store.settings.skinMode.themeMode,
          // 跟随系统时为 null；系统语言不在支持列表内时回退到简体中文。
          locale: store.settings.language.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
