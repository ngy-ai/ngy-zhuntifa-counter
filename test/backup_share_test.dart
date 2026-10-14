import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/app.dart';
import 'package:ngy_zhuntifa_counter/data/practice_backup.dart';
import 'package:ngy_zhuntifa_counter/data/practice_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus/share_plus.dart' show SharePlus;
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'memory_key_value_store.dart';

/// 把临时目录指到测试自己的目录。
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

/// 记录分享调用，替换系统分享面板。
class _FakeShare extends SharePlatform {
  final List<ShareParams> calls = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  late Directory tempDir;
  late _FakeShare share;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zhunti_share_test');
    share = _FakeShare();
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    } on FileSystemException {
      // Windows 上文件句柄偶尔释放不及时，临时目录留给系统清理即可
    }
  });

  testWidgets('导出明细记录会写出备份文件并唤起分享面板', (WidgetTester tester) async {
    final store = PracticeStore(storage: MemoryKeyValueStore());
    await store.load();
    store.tap(at: DateTime(2026, 10, 1, 9));
    store.tap(at: DateTime(2026, 10, 1, 9, 1));
    store.finishCurrent();

    await tester.pumpWidget(ZhuntiCounterApp(store: store));

    // 插件平台的注册晚于 setUp，这里在触发导出前替换实现
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    SharePlatform.instance = share;
    await SharePlus.instance.share(ShareParams(text: '探针'));
    expect(share.calls, hasLength(1), reason: '分享平台替身未生效');
    share.calls.clear();

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('导出明细记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出明细记录'));
    await tester.pump();

    // 写文件是真实 IO：runAsync 让真实异步完成，pump 推进挂起的微任务
    for (var attempt = 0; attempt < 20 && share.calls.isEmpty; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    if (share.calls.isEmpty) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();
      fail('分享面板未被调用，当前界面文本：$texts');
    }

    final files = share.calls.single.files!;
    expect(files, hasLength(1));
    expect(files.single.mimeType, 'application/json');

    // 备份文件应当落在临时目录里，内容能被导入解析
    final file = File(files.single.path);
    expect(file.existsSync(), isTrue, reason: '备份文件未写出');
    expect(file.path, startsWith(tempDir.path));
    expect(file.path, endsWith('.json'));
    expect(
      PracticeBackup.parse(file.readAsStringSync()).sessions.single.count,
      2,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    store.dispose();
  });
}
