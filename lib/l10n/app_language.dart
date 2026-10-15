import 'package:flutter/widgets.dart';

/// 界面语言选项。
///
/// 新增一种语言：在 `lib/l10n/` 下添加 `app_<locale>.arb`（可复制 `app_en.arb`
/// 逐条翻译），然后在 [AppLanguage] 里登记一个枚举值并在设置面板的语言选项
/// （[options]）里加入即可，无需改动其它界面代码。
enum AppLanguage {
  /// 跟随系统语言。
  system,

  /// 简体中文。
  zh,

  /// 繁体中文。
  zhHant,

  /// 英语。
  en;

  /// 设置面板里的展示顺序：跟随系统排在最前。
  static const List<AppLanguage> options = <AppLanguage>[
    AppLanguage.system,
    AppLanguage.zh,
    AppLanguage.zhHant,
    AppLanguage.en,
  ];

  /// 该语言对应的 [Locale]；[AppLanguage.system] 返回 null，交给系统决定。
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.zhHant => const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    ),
    AppLanguage.en => const Locale('en'),
  };

  /// 从存档里的名字还原；未知取值回退到跟随系统。
  static AppLanguage fromName(String? name) => values.firstWhere(
    (language) => language.name == name,
    orElse: () => AppLanguage.system,
  );
}
