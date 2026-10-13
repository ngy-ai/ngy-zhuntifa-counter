import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/models/practice_session.dart';

void main() {
  test('偏移量可还原成每一遍的具体时间点', () {
    final start = DateTime(2026, 10, 13, 4, 20, 5);
    final session = PracticeSession(
      id: 'a',
      startAt: start,
      endAt: start.add(const Duration(seconds: 12)),
      count: 3,
      markOffsets: const <int>[0, 5000, 12000],
    );

    expect(session.hasMarks, isTrue);
    expect(session.markTimes, <DateTime>[
      start,
      start.add(const Duration(seconds: 5)),
      start.add(const Duration(seconds: 12)),
    ]);
  });

  test('序列化保留逐次时间点', () {
    final start = DateTime(2026, 10, 13, 4, 20);
    final session = PracticeSession(
      id: 'a',
      startAt: start,
      endAt: start.add(const Duration(milliseconds: 2500)),
      count: 3,
      markOffsets: const <int>[0, 1000, 2500],
    );

    final restored = PracticeSession.fromJson(
      jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>,
    );

    expect(restored.count, 3);
    expect(restored.markOffsets, <int>[0, 1000, 2500]);
    expect(restored.markTimes.length, 3);
  });

  test('只记了总遍数的旧记录能兼容解析', () {
    final legacy = <String, dynamic>{
      'id': 'old',
      'start': DateTime(2026, 10, 1, 8).millisecondsSinceEpoch,
      'end': DateTime(2026, 10, 1, 8, 30).millisecondsSinceEpoch,
      'count': 108,
    };

    final session = PracticeSession.fromJson(legacy);

    expect(session.count, 108);
    expect(session.isEffective, isTrue);
    expect(session.hasMarks, isFalse);
    expect(session.markTimes, isEmpty);
    // 没有逐次时间就不写进存档，避免无谓的体积
    expect(session.toJson().containsKey('marks'), isFalse);
  });

  test('每新建一次功课都会拿到不同的 id', () {
    final now = DateTime(2026, 10, 13, 9);
    final ids = <String>{
      for (var index = 0; index < 50; index++)
        PracticeSession.begin(now).id,
    };

    expect(ids.length, 50);
  });
}
