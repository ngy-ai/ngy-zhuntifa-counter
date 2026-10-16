import '../l10n/gen/app_localizations.dart';

/// 备份文件内容解析失败的原因。
enum BackupError {
  /// 文件内容为空。
  empty,

  /// JSON 解析失败。
  invalidJson,

  /// 顶层结构不是一段备份。
  wrongFormat,

  /// 是别的应用的 JSON。
  wrongApp,

  /// 备份来自更新的版本。
  newerVersion,

  /// 缺少明细记录列表。
  missingSessions,

  /// 某条明细记录格式不对。
  sessionFormat,

  /// 某条明细记录解析失败。
  sessionParse,
}

/// 备份文件的内容解析失败。
///
/// 继承 [FormatException]，保持「解析失败即抛 FormatException」的既有约定；
/// [code] 供界面翻译成当前语言的提示，[detail] 是可选细节（版本号或记录序号），
/// 因此这一层不携带任何语言的文案。
class BackupParseException extends FormatException {
  BackupParseException(this.code, {this.detail})
    : super('practice backup parse failed: ${code.name}');

  final BackupError code;

  /// 补充信息：版本过新时是版本号，明细出错时是记录序号（从 1 开始）。
  final Object? detail;
}

/// 把解析失败的原因翻译成当前语言的提示文案。
String backupErrorMessage(
  AppLocalizations l10n,
  BackupParseException error,
) => switch (error.code) {
  BackupError.empty => l10n.backupErrorEmpty,
  BackupError.invalidJson => l10n.backupErrorInvalidJson,
  BackupError.wrongFormat => l10n.backupErrorWrongFormat,
  BackupError.wrongApp => l10n.backupErrorWrongApp,
  BackupError.newerVersion => l10n.backupErrorNewerVersion('${error.detail}'),
  BackupError.missingSessions => l10n.backupErrorMissingSessions,
  BackupError.sessionFormat => l10n.backupErrorSessionFormat(
    _recordIndex(error),
  ),
  BackupError.sessionParse => l10n.backupErrorSessionParse(_recordIndex(error)),
};

int _recordIndex(BackupParseException error) => switch (error.detail) {
  final int value => value,
  _ => 0,
};
