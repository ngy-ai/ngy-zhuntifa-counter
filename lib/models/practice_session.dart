import 'package:flutter/foundation.dart';

/// 一次功课记录：从开始持咒到结束的一段连续过程。
@immutable
class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.count,
    this.markOffsets = const <int>[],
  });

  /// 新建一次空功课。
  factory PracticeSession.begin(DateTime now) => PracticeSession(
    id: '${now.microsecondsSinceEpoch}-${_sequence++}',
    startAt: now,
    endAt: now,
    count: 0,
  );

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    final startMs = (json['start'] as num).toInt();
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final endMs = (json['end'] as num?)?.toInt() ?? startMs;
    final rawMarks = json['marks'];
    return PracticeSession(
      id: json['id'] as String? ?? startMs.toString(),
      startAt: start,
      endAt: DateTime.fromMillisecondsSinceEpoch(endMs),
      count: (json['count'] as num?)?.toInt() ?? 0,
      markOffsets: rawMarks is List
          ? rawMarks
                .whereType<num>()
                .map((value) => value.toInt())
                .toList(growable: false)
          : const <int>[],
    );
  }

  /// 进程内自增序号：系统时钟精度可能不足 1 毫秒，
  /// 仅用时间戳会让「结束本次后立刻再开始」的两次功课重号。
  static int _sequence = 0;

  final String id;
  final DateTime startAt;
  final DateTime endAt;

  /// 本次功课累计持咒遍数。
  final int count;

  /// 每一次持咒相对 [startAt] 的毫秒偏移，用于回看每次持咒的具体时间。
  ///
  /// 只记录偏移而不是绝对时间，可显著压缩存档体积。
  /// 早期版本只记总遍数，这类记录此处为空，界面按「没有逐次时间」处理。
  final List<int> markOffsets;

  bool get isEffective => count > 0;

  /// 是否记录了逐次时间点。
  bool get hasMarks => markOffsets.isNotEmpty;

  /// 每一次持咒的具体时间点。
  List<DateTime> get markTimes => <DateTime>[
    for (final offset in markOffsets)
      startAt.add(Duration(milliseconds: offset)),
  ];

  Duration get duration {
    final value = endAt.difference(startAt);
    return value.isNegative ? Duration.zero : value;
  }

  /// 归属日期（当天零点），用于按日聚合统计。
  DateTime get dayKey => DateTime(startAt.year, startAt.month, startAt.day);

  PracticeSession copyWith({
    DateTime? endAt,
    int? count,
    List<int>? markOffsets,
  }) => PracticeSession(
    id: id,
    startAt: startAt,
    endAt: endAt ?? this.endAt,
    count: count ?? this.count,
    markOffsets: markOffsets ?? this.markOffsets,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'start': startAt.millisecondsSinceEpoch,
    'end': endAt.millisecondsSinceEpoch,
    'count': count,
    if (markOffsets.isNotEmpty) 'marks': markOffsets,
  };
}
