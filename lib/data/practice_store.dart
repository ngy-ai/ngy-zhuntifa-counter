import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/practice_session.dart';
import '../models/practice_settings.dart';
import 'key_value_store.dart';
import 'practice_backup.dart';
import 'practice_stats.dart';

/// 持咒数据仓库：负责记录计数、统计与本地持久化。
///
/// 计数会立即在内存中生效并通知界面刷新，落盘则做 600ms 防抖，
/// 避免连续点击时频繁写入；应用切到后台时可通过 [flush] 强制写入。
class PracticeStore extends ChangeNotifier {
  PracticeStore({KeyValueStore? storage})
    : _storage = storage ?? PrefsKeyValueStore();

  static const String _storageKey = 'ngy_zhunti_practice_v1';

  final KeyValueStore _storage;
  final List<PracticeSession> _sessions = <PracticeSession>[];

  PracticeSession? _current;
  PracticeSettings _settings = const PracticeSettings();
  Timer? _saveTimer;
  bool _dirty = false;
  bool _ready = false;

  bool get isReady => _ready;

  /// 历史功课记录（不含进行中的一次）。
  List<PracticeSession> get sessions => List.unmodifiable(_sessions);

  /// 进行中的功课。
  PracticeSession? get current => _current;

  int get currentCount => _current?.count ?? 0;

  PracticeSettings get settings => _settings;

  /// 取某个时刻的统计快照。
  PracticeStats stats([DateTime? now]) => PracticeStats.from(
    sessions: _sessions,
    current: _current,
    settings: _settings,
    now: now ?? DateTime.now(),
  );

  Future<void> load() async {
    try {
      final raw = await _storage.read(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        _restore(jsonDecode(raw));
      }
    } catch (error, stack) {
      debugPrint('持咒数据读取失败: $error');
      debugPrintStack(stackTrace: stack);
    }
    _ready = true;
    notifyListeners();
  }

  /// 记录一次持咒，同时留下这一次的具体时间点。
  void tap({DateTime? at}) {
    final now = at ?? DateTime.now();
    var active = _current;
    if (active == null || _dayKey(active.startAt) != _dayKey(now)) {
      _settleCurrent();
      active = PracticeSession.begin(now);
    }
    _current = active.copyWith(
      endAt: now,
      count: active.count + 1,
      markOffsets: <int>[
        ...active.markOffsets,
        now.difference(active.startAt).inMilliseconds,
      ],
    );
    _markDirty();
    notifyListeners();
  }

  /// 撤销一次（用于误触），连同这一次的时间点一起回退。
  /// 返回是否撤销成功。
  bool undo() {
    final active = _current;
    if (active == null || active.count <= 0) return false;
    _current = active.copyWith(
      endAt: DateTime.now(),
      count: active.count - 1,
      markOffsets: active.markOffsets.isEmpty
          ? const <int>[]
          : active.markOffsets.sublist(0, active.markOffsets.length - 1),
    );
    _markDirty();
    notifyListeners();
    return true;
  }

  /// 结束本次功课并归档。返回被归档的记录。
  PracticeSession? finishCurrent() {
    final active = _current;
    if (active == null) return null;
    final finished = active.copyWith(endAt: DateTime.now());
    if (finished.isEffective) {
      _sessions.add(finished);
    }
    _current = null;
    _markDirty();
    notifyListeners();
    return finished.isEffective ? finished : null;
  }

  /// 丢弃本次功课（不写入历史）。
  void discardCurrent() {
    if (_current == null) return;
    _current = null;
    _markDirty();
    notifyListeners();
  }

  /// 删除一条历史记录（用于修正误记）。返回是否删除成功。
  Future<bool> deleteSession(String id) async {
    final before = _sessions.length;
    _sessions.removeWhere((session) => session.id == id);
    if (_sessions.length == before) return false;
    _markDirty();
    notifyListeners();
    await flush();
    return true;
  }

  Future<void> updateSettings(PracticeSettings value) async {
    _settings = value;
    _markDirty();
    notifyListeners();
    await flush();
  }

  /// 清空全部持咒记录与进行中的功课。
  Future<void> clearAll() async {
    _sessions.clear();
    _current = null;
    _markDirty();
    notifyListeners();
    await flush();
  }

  /// 导出全部明细记录（含进行中的一次）为备份文本（即备份文件的内容）。
  String exportBackup({DateTime? at}) => PracticeBackup.encode(
    sessions: _sessions,
    current: _current,
    exportedAt: at ?? DateTime.now(),
  );

  /// 用备份恢复明细记录。
  ///
  /// [replace] 为 true 时用备份替换全部历史记录；否则把备份里本地没有的
  /// 记录合并进来（按 id 去重，重复的自动跳过）。
  /// 进行中的功课：本地已经有就不被打断，本地没有时才从备份恢复。
  Future<BackupImportResult> importBackup(
    PracticeBackup backup, {
    bool replace = false,
  }) async {
    final seen = replace
        ? <String>{}
        : <String>{for (final session in _sessions) session.id};
    if (replace) _sessions.clear();

    var added = 0;
    var skipped = 0;
    for (final session in backup.sessions) {
      if (session.isEffective && seen.add(session.id)) {
        _sessions.add(session);
        added++;
      } else {
        skipped++;
      }
    }
    _sessions.sort((a, b) => a.startAt.compareTo(b.startAt));

    final restoredCurrent = backup.current;
    if (_current == null &&
        restoredCurrent != null &&
        restoredCurrent.isEffective) {
      _current = restoredCurrent;
    }

    _markDirty();
    notifyListeners();
    await flush();

    return BackupImportResult(
      added: added,
      skipped: skipped,
      replaced: replace,
      totalSessions: _sessions.length,
    );
  }

  /// 立即落盘（应用退到后台时调用）。
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    try {
      await _storage.write(_storageKey, jsonEncode(_toJson()));
    } catch (error) {
      debugPrint('持咒数据写入失败: $error');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _markDirty() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(flush());
    });
  }

  /// 把进行中的功课归档，跨天时自动收尾。
  void _settleCurrent() {
    final active = _current;
    if (active != null && active.isEffective) {
      _sessions.add(active);
    }
    _current = null;
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Map<String, dynamic> _toJson() => <String, dynamic>{
    'version': 1,
    'sessions': _sessions.map((session) => session.toJson()).toList(),
    'current': (_current != null && _current!.isEffective)
        ? _current!.toJson()
        : null,
    'settings': _settings.toJson(),
  };

  void _restore(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return;

    final settings = decoded['settings'];
    if (settings is Map<String, dynamic>) {
      _settings = PracticeSettings.fromJson(settings);
    }

    final sessions = decoded['sessions'];
    if (sessions is List) {
      _sessions
        ..clear()
        ..addAll(
          sessions.whereType<Map<String, dynamic>>().map(
            PracticeSession.fromJson,
          ),
        );
    }

    final current = decoded['current'];
    if (current is Map<String, dynamic>) {
      final restored = PracticeSession.fromJson(current);
      // 跨天后仍然保留进行中的计数，统计时按日期归入对应那一天。
      _current = restored.isEffective ? restored : null;
    }
  }
}
