import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/practice_backup.dart';
import '../data/practice_store.dart';
import '../models/practice_settings.dart';
import '../theme/app_skin.dart';

/// 弹出功课设置面板。
Future<void> showPracticeSettings(BuildContext context, PracticeStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SettingsSheet(store: store),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.store});

  final PracticeStore store;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  static const List<int> _goalOptions = <int>[21, 54, 108, 216, 432, 1080];
  static const List<int> _beadOptions = <int>[18, 21, 27, 54, 108];

  late PracticeSettings _draft = widget.store.settings;

  void _apply(PracticeSettings next) {
    setState(() => _draft = next);
    unawaited(widget.store.updateSettings(next));
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空全部记录？'),
        content: const Text('所有持咒记录与统计都会被删除，且无法恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('已清空全部持咒记录')),
    );
  }

  /// 把备份写成 JSON 文件并唤起系统分享面板：可保存到手机，或直接发到微信、邮箱、网盘。
  Future<void> _shareRecords() async {
    final store = widget.store;
    if (store.sessions.isEmpty && store.currentCount == 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('还没有可导出的明细记录')),
      );
      return;
    }

    final text = store.exportBackup();
    final sessionCount = store.sessions.length + (store.currentCount > 0 ? 1 : 0);
    final totalCount =
        store.sessions.fold<int>(0, (sum, session) => sum + session.count) +
        store.currentCount;

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/${_backupFileName(DateTime.now())}');
      await file.writeAsString(text);
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
          subject: '准提法计数器明细备份',
          text: '准提法计数器明细备份 · 共 $sessionCount 条记录 · $totalCount 遍',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('导出文件失败：$error')),
      );
    }
  }

  /// 备份文件名，如「准提法计数器备份-20261014-1530.json」。
  static String _backupFileName(DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '准提法计数器备份-${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.json';
  }

  /// 把备份复制到剪贴板，便于粘贴到备忘录或聊天窗口。
  Future<void> _copyRecords() async {
    final store = widget.store;
    if (store.sessions.isEmpty && store.currentCount == 0) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('还没有可导出的明细记录')),
      );
      return;
    }

    final text = store.exportBackup();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    final sessionCount = store.sessions.length + (store.currentCount > 0 ? 1 : 0);
    final totalCount =
        store.sessions.fold<int>(0, (sum, session) => sum + session.count) +
        store.currentCount;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('已复制导出文本'),
        content: Text(
          '共 $sessionCount 条记录 · $totalCount 遍，备份文本已复制到剪贴板。\n\n'
          '可以粘贴到备忘录、聊天窗口或文件中保存；'
          '恢复时在「导入恢复」里把这段文本粘贴回来即可。',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  Future<void> _importRecords() async {
    final result = await showDialog<BackupImportResult>(
      context: context,
      builder: (_) => _ImportRecordsDialog(store: widget.store),
    );
    if (result == null || !mounted) return;

    final String message;
    if (result.replaced) {
      message = '已用备份恢复 ${result.totalSessions} 条明细记录';
    } else if (result.added == 0) {
      message = '没有新增记录，备份里的 ${result.skipped} 条都已存在';
    } else if (result.skipped == 0) {
      message = '已导入 ${result.added} 条明细记录';
    } else {
      message = '已导入 ${result.added} 条明细记录，跳过 ${result.skipped} 条已存在的';
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '功课设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: '每日目标（遍）'),
            const SizedBox(height: 10),
            _OptionChips(
              options: _goalOptions,
              selected: _draft.dailyGoal,
              onSelected: (value) =>
                  _apply(_draft.copyWith(dailyGoal: value)),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: '每串念珠颗数'),
            const SizedBox(height: 10),
            _OptionChips(
              options: _beadOptions,
              selected: _draft.beadCount,
              onSelected: (value) =>
                  _apply(_draft.copyWith(beadCount: value)),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('震动反馈'),
              subtitle: const Text('每次计数时轻微震动'),
              value: _draft.hapticsEnabled,
              onChanged: (value) =>
                  _apply(_draft.copyWith(hapticsEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('点击提示音'),
              subtitle: const Text('每次计数时播放系统提示音'),
              value: _draft.soundEnabled,
              onChanged: (value) => _apply(_draft.copyWith(soundEnabled: value)),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: '界面皮肤'),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppSkinMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<AppSkinMode>>[
                  for (final mode in AppSkinMode.values)
                    ButtonSegment<AppSkinMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                ],
                selected: <AppSkinMode>{_draft.skinMode},
                onSelectionChanged: (selection) =>
                    _apply(_draft.copyWith(skinMode: selection.first)),
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: '备份与恢复'),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('导出明细记录'),
              subtitle: const Text('导出为文件，可保存到手机或发送到微信、邮箱、网盘'),
              onTap: _shareRecords,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.copy_all_rounded),
              title: const Text('复制备份文本'),
              subtitle: const Text('复制为文本，粘贴到备忘录或聊天窗口保存'),
              onTap: _copyRecords,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.content_paste_rounded),
              title: const Text('导入恢复'),
              subtitle: const Text('粘贴之前导出的文本，恢复或合并明细'),
              onTap: _importRecords,
            ),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text('清空全部记录', style: TextStyle(color: scheme.error)),
              onTap: _confirmClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _OptionChips extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final option in options)
          ChoiceChip(
            label: Text('$option'),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// 导入恢复对话框：粘贴备份文本，选择合并或覆盖。
class _ImportRecordsDialog extends StatefulWidget {
  const _ImportRecordsDialog({required this.store});

  final PracticeStore store;

  @override
  State<_ImportRecordsDialog> createState() => _ImportRecordsDialogState();
}

class _ImportRecordsDialogState extends State<_ImportRecordsDialog> {
  final TextEditingController _controller = TextEditingController();

  PracticeBackup? _backup;
  String? _error;
  bool _replace = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleChanged(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _backup = null;
        _error = null;
      });
      return;
    }
    try {
      final backup = PracticeBackup.parse(trimmed);
      setState(() {
        _backup = backup;
        _error = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _backup = null;
        _error = error.message;
      });
    }
  }

  bool get _canSubmit =>
      !_busy && _backup != null && _backup!.sessionCount > 0;

  Future<void> _submit() async {
    final backup = _backup;
    if (!_canSubmit || backup == null) return;

    if (_replace) {
      final local = widget.store.sessions.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('覆盖现有记录？'),
          content: Text(
            '本地现有的 $local 条明细记录会被删除，'
            '替换为备份里的 ${backup.sessionCount} 条。此操作无法撤销。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text('确认覆盖'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    final result = await widget.store.importBackup(backup, replace: _replace);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('导入恢复'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '把之前导出的备份文本粘贴到下面：',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _handleChanged,
              minLines: 4,
              maxLines: 7,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                hintText: '{"app":"ngy_zhuntifa_counter", ...}',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _buildPreview(),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text('合并'),
                  icon: Icon(Icons.call_merge_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('覆盖'),
                  icon: Icon(Icons.swap_horiz_rounded, size: 18),
                ),
              ],
              selected: <bool>{_replace},
              onSelectionChanged: (selection) =>
                  setState(() => _replace = selection.first),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_busy ? '导入中…' : '导入'),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    if (error != null) {
      return Text(
        error,
        style: TextStyle(fontSize: 12.5, color: scheme.error),
      );
    }

    final backup = _backup;
    if (backup == null) {
      return Text(
        '等待粘贴…',
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      );
    }

    if (backup.sessionCount == 0) {
      return Text(
        '备份里没有可导入的记录',
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '将导入 ${backup.sessionCount} 条记录 · ${backup.totalCount} 遍'
        '${_describeRange(backup)}',
        style: TextStyle(fontSize: 12.5, color: scheme.primary),
      ),
    );
  }

  String _describeRange(PracticeBackup backup) {
    final first = backup.firstDay;
    final last = backup.lastDay;
    if (first == null) return '';
    final from = '${first.year}/${first.month}/${first.day}';
    if (last == null) return '（$from）';
    final to = '${last.year}/${last.month}/${last.day}';
    return from == to ? '（$from）' : '（$from - $to）';
  }
}
