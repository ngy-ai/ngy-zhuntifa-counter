import 'package:flutter/widgets.dart';

import 'practice_store.dart';

/// 把 [PracticeStore] 共享给整棵组件树。
class PracticeScope extends InheritedNotifier<PracticeStore> {
  const PracticeScope({super.key, required PracticeStore store, required super.child})
    : super(notifier: store);

  /// 在 build 中读取，仓库变化时会触发重建。
  static PracticeStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PracticeScope>();
    assert(scope != null, '组件树中缺少 PracticeScope');
    return scope!.notifier!;
  }

  /// 在回调中读取，不建立依赖关系。
  static PracticeStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PracticeScope>();
    assert(scope != null, '组件树中缺少 PracticeScope');
    return scope!.notifier!;
  }
}
