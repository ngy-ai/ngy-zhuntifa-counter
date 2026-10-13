import 'dart:convert';

import '../models/practice_session.dart';

/// 明细记录的备份：把全部功课记录编码成一段可粘贴的 JSON 文本。
///
/// 只包含持咒记录（含进行中的一次），不含界面设置，
/// 导入时不会动到当前的偏好设置。
class PracticeBackup {
  const PracticeBackup({required this.sessions, this.current, this.exportedAt});

  /// 备份来源标记，用于识别误粘贴的其它 JSON 文本。
  static const String appTag = 'ngy_zhuntifa_counter';

  /// 当前支持的备份版本。
  static const int version = 1;

  /// 把记录编码成备份文本。
  static String encode({
    required List<PracticeSession> sessions,
    PracticeSession? current,
    required DateTime exportedAt,
  }) {
    final effective = <PracticeSession>[
      for (final session in sessions)
        if (session.isEffective) session,
    ];
    return jsonEncode(<String, dynamic>{
      'app': appTag,
      'version': version,
      'exportedAt': exportedAt.millisecondsSinceEpoch,
      'sessions': effective.map((session) => session.toJson()).toList(),
      'current': (current != null && current.isEffective)
          ? current.toJson()
          : null,
    });
  }

  /// 解析备份文本，格式不对时抛出 [FormatException]（中文说明可直接展示）。
  static PracticeBackup parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('备份内容为空，请先把导出的文本粘贴进来');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      throw const FormatException('不是有效的备份文本（JSON 解析失败）');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('备份格式不对，应为一段备份文本');
    }

    final app = decoded['app'];
    if (app is String && app != appTag) {
      throw const FormatException('这不是准提法计数器的备份');
    }

    final versionValue = decoded['version'];
    if (versionValue is num && versionValue > version) {
      throw FormatException('备份来自更新的版本（v$versionValue），请先升级应用');
    }

    final rawSessions = decoded['sessions'];
    if (rawSessions is! List) {
      throw const FormatException('备份里缺少明细记录');
    }

    final sessions = <PracticeSession>[];
    for (var index = 0; index < rawSessions.length; index++) {
      final item = rawSessions[index];
      if (item is! Map<String, dynamic>) {
        throw FormatException('第 ${index + 1} 条明细记录格式不对');
      }
      final PracticeSession session;
      try {
        session = PracticeSession.fromJson(item);
      } catch (_) {
        throw FormatException('第 ${index + 1} 条明细记录解析失败');
      }
      if (session.isEffective) sessions.add(session);
    }

    PracticeSession? current;
    final rawCurrent = decoded['current'];
    if (rawCurrent is Map<String, dynamic>) {
      try {
        final restored = PracticeSession.fromJson(rawCurrent);
        if (restored.isEffective) current = restored;
      } catch (_) {
        // 进行中的这条坏了不影响其它明细
      }
    }

    final rawExportedAt = decoded['exportedAt'];
    return PracticeBackup(
      sessions: sessions,
      current: current,
      exportedAt: rawExportedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(rawExportedAt.toInt())
          : null,
    );
  }

  /// 备份里的历史记录（不含进行中的一次）。
  final List<PracticeSession> sessions;

  /// 导出时进行中的功课，可能为空。
  final PracticeSession? current;

  /// 导出时刻。
  final DateTime? exportedAt;

  /// 可导入的记录条数（含进行中的一次）。
  int get sessionCount => sessions.length + (current != null ? 1 : 0);

  /// 全部记录的遍数合计。
  int get totalCount =>
      sessions.fold(0, (sum, session) => sum + session.count) +
      (current?.count ?? 0);

  /// 最早一次功课的开始时间。
  DateTime? get firstDay {
    DateTime? result = current?.startAt;
    for (final session in sessions) {
      if (result == null || session.startAt.isBefore(result)) {
        result = session.startAt;
      }
    }
    return result;
  }

  /// 最近一次功课的开始时间。
  DateTime? get lastDay {
    DateTime? result = current?.startAt;
    for (final session in sessions) {
      if (result == null || session.startAt.isAfter(result)) {
        result = session.startAt;
      }
    }
    return result;
  }
}

/// 导入结果，用于提示新增了多少、跳过了多少。
class BackupImportResult {
  const BackupImportResult({
    required this.added,
    required this.skipped,
    required this.replaced,
    required this.totalSessions,
  });

  /// 本次新增的记录条数。
  final int added;

  /// 因重复（或无效）被跳过的条数。
  final int skipped;

  /// 是否采用了覆盖模式。
  final bool replaced;

  /// 导入后本地历史记录的总条数。
  final int totalSessions;
}
