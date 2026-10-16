import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_error.dart';
import '../data/backup_file.dart';
import '../data/practice_backup.dart';
import '../data/practice_store.dart';
import '../l10n/app_language.dart';
import '../l10n/gen/app_localizations.dart';
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

/// 皮肤模式的展示名称，随语言变化。
String _skinLabel(AppLocalizations l10n, AppSkinMode mode) => switch (mode) {
  AppSkinMode.system => l10n.skinSystem,
  AppSkinMode.light => l10n.skinLight,
  AppSkinMode.dark => l10n.skinDark,
};

/// 语言选项的展示名称。
///
/// 简体中文 / 繁體中文 / English 都写成自己的文字，任何界面语言下都能认出来；
/// 只有「跟随系统」需要翻译。
String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
    switch (language) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.zh => l10n.languageZh,
      AppLanguage.zhHant => l10n.languageZhHant,
      AppLanguage.en => l10n.languageEn,
    };

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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearConfirmTitle),
        content: Text(l10n.clearConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.clearConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(l10n.clearDone)));
  }

  /// 把备份写成 JSON 文件并唤起系统分享面板：可保存到手机，或直接发到微信、邮箱、网盘。
  Future<void> _shareRecords() async {
    final l10n = AppLocalizations.of(context);
    final store = widget.store;
    if (store.sessions.isEmpty && store.currentCount == 0) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.exportEmpty)));
      return;
    }

    final text = store.exportBackup();
    final sessionCount =
        store.sessions.length + (store.currentCount > 0 ? 1 : 0);
    final totalCount =
        store.sessions.fold<int>(0, (sum, session) => sum + session.count) +
        store.currentCount;

    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${_backupFileName(l10n, DateTime.now())}',
      );
      await file.writeAsString(text);
      if (!mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
          subject: l10n.exportShareSubject,
          text: l10n.exportShareText(sessionCount, totalCount),
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$error'))));
    }
  }

  /// 备份文件名，如「准提法计数器备份-20261014-1530.json」。
  static String _backupFileName(AppLocalizations l10n, DateTime now) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}';
    return l10n.exportFileName(stamp);
  }

  /// 选择备份文件并导入：用户取消选择时什么也不做；文件读不了或不是备份时提示原因。
  Future<void> _importRecords() async {
    final l10n = AppLocalizations.of(context);

    final String? text;
    try {
      text = await backupFileReader();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(l10n.importReadFailed('$error'))));
      return;
    }
    if (text == null || !mounted) return;

    final PracticeBackup backup;
    try {
      backup = PracticeBackup.parse(text);
    } on BackupParseException catch (error) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(backupErrorMessage(l10n, error))));
      return;
    }

    final result = await showDialog<BackupImportResult>(
      context: context,
      builder: (_) => _ImportRecordsDialog(store: widget.store, backup: backup),
    );
    if (result == null || !mounted) return;

    final String message;
    if (result.replaced) {
      message = l10n.importRestored(result.totalSessions);
    } else if (result.added == 0) {
      message = l10n.importNothingNew(result.skipped);
    } else if (result.skipped == 0) {
      message = l10n.importAdded(result.added);
    } else {
      message = l10n.importAddedSkipped(result.added, result.skipped);
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.settingsTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: l10n.settingsDailyGoal),
            const SizedBox(height: 10),
            _OptionChips<int>(
              options: _goalOptions,
              selected: _draft.dailyGoal,
              labelOf: (value) => '$value',
              onSelected: (value) => _apply(_draft.copyWith(dailyGoal: value)),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: l10n.settingsBeadCount),
            const SizedBox(height: 10),
            _OptionChips<int>(
              options: _beadOptions,
              selected: _draft.beadCount,
              labelOf: (value) => '$value',
              onSelected: (value) => _apply(_draft.copyWith(beadCount: value)),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsHaptics),
              subtitle: Text(l10n.settingsHapticsHint),
              value: _draft.hapticsEnabled,
              onChanged: (value) =>
                  _apply(_draft.copyWith(hapticsEnabled: value)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.settingsSound),
              subtitle: Text(l10n.settingsSoundHint),
              value: _draft.soundEnabled,
              onChanged: (value) =>
                  _apply(_draft.copyWith(soundEnabled: value)),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: l10n.settingsSkin),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppSkinMode>(
                showSelectedIcon: false,
                segments: <ButtonSegment<AppSkinMode>>[
                  for (final mode in AppSkinMode.values)
                    ButtonSegment<AppSkinMode>(
                      value: mode,
                      label: Text(_skinLabel(l10n, mode)),
                    ),
                ],
                selected: <AppSkinMode>{_draft.skinMode},
                onSelectionChanged: (selection) =>
                    _apply(_draft.copyWith(skinMode: selection.first)),
              ),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: l10n.settingsLanguage),
            const SizedBox(height: 10),
            _OptionChips<AppLanguage>(
              options: AppLanguage.options,
              selected: _draft.language,
              labelOf: (language) => _languageLabel(l10n, language),
              onSelected: (language) =>
                  _apply(_draft.copyWith(language: language)),
            ),
            const SizedBox(height: 22),
            _SectionLabel(text: l10n.settingsBackup),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share_rounded),
              title: Text(l10n.settingsExport),
              subtitle: Text(l10n.settingsExportHint),
              onTap: _shareRecords,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_open_rounded),
              title: Text(l10n.settingsImport),
              subtitle: Text(l10n.settingsImportHint),
              onTap: _importRecords,
            ),
            const SizedBox(height: 8),
            Divider(color: scheme.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline_rounded, color: scheme.error),
              title: Text(
                l10n.settingsClearAll,
                style: TextStyle(color: scheme.error),
              ),
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

class _OptionChips<T> extends StatelessWidget {
  const _OptionChips({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final option in options)
          ChoiceChip(
            label: Text(labelOf(option)),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}

/// 导入确认对话框：展示备份文件的记录摘要，选择合并或覆盖。
class _ImportRecordsDialog extends StatefulWidget {
  const _ImportRecordsDialog({required this.store, required this.backup});

  final PracticeStore store;

  /// 已经解析好的备份内容（文件在打开对话框前就已读取、校验）。
  final PracticeBackup backup;

  @override
  State<_ImportRecordsDialog> createState() => _ImportRecordsDialogState();
}

class _ImportRecordsDialogState extends State<_ImportRecordsDialog> {
  bool _replace = false;
  bool _busy = false;

  bool get _canSubmit => !_busy && widget.backup.sessionCount > 0;

  Future<void> _submit() async {
    final backup = widget.backup;
    if (!_canSubmit) return;

    if (_replace) {
      final l10n = AppLocalizations.of(context);
      final local = widget.store.sessions.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.importReplaceTitle),
          content: Text(l10n.importReplaceBody(local, backup.sessionCount)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.importReplaceConfirm),
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
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      scrollable: true,
      title: Text(l10n.importTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildPreview(),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  label: Text(l10n.importMerge),
                  icon: const Icon(Icons.call_merge_rounded, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text(l10n.importReplace),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_busy ? l10n.importBusy : l10n.importAction),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final backup = widget.backup;

    if (backup.sessionCount == 0) {
      return Text(
        l10n.importPreviewEmpty,
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
        l10n.importPreview(
          backup.sessionCount,
          backup.totalCount,
          _describeRange(l10n, backup),
        ),
        style: TextStyle(fontSize: 12.5, color: scheme.primary),
      ),
    );
  }

  String _describeRange(AppLocalizations l10n, PracticeBackup backup) {
    final first = backup.firstDay;
    final last = backup.lastDay;
    if (first == null) return '';
    final from = _numericDate(first);
    if (last == null) return l10n.importRangeSingle(from);
    final to = _numericDate(last);
    return from == to
        ? l10n.importRangeSingle(from)
        : l10n.importRangeSpan(from, to);
  }

  /// 备份预览里的日期，统一写成 2026/10/13。
  static String _numericDate(DateTime value) =>
      '${value.year}/${value.month}/${value.day}';
}
