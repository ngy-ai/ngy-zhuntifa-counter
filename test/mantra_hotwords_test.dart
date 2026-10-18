import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_hotwords.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_matcher.dart';

/// 与 lib/voice/model_files.dart 的 [modelAssetDir] 保持一致。
const String _tokensPath = 'assets/models/zipformer-multi-zh-hans/tokens.txt';

/// 读模型词表（每行「token 编号」）；模型未下载时返回 null。
///
/// 模型资产不入库（.gitignore 忽略 /assets/models/），CI 上没有这两个文件，
/// 所以词表相关的断言在缺资产时跳过，只在本地开发机上生效。
Set<String>? _loadVocabulary() {
  final file = File(_tokensPath);
  if (!file.existsSync()) return null;

  final tokens = <String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final space = trimmed.lastIndexOf(' ');
    tokens.add(space < 0 ? trimmed : trimmed.substring(0, space));
  }
  return tokens;
}

void main() {
  final lines = mantraHotwords
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  final vocabulary = _loadVocabulary();

  test('每条热词的拼音（归一化后）都是咒文拼音的片段', () {
    expect(lines, isNotEmpty);

    for (final line in lines) {
      final pinyin = MantraMatcher.normalizePinyin(
        MantraMatcher.toPinyin(line),
      );
      expect(
        pinyin,
        isNotEmpty,
        reason: '「$line」转不出拼音：多半全是拼音库不认识的生僻字',
      );
      expect(
        mantraPinyin.contains(pinyin),
        isTrue,
        reason:
            '「$line」的拼音「$pinyin」不在咒文拼音里：'
            '多半用了读音字母不同的多音字（如「扎」默认读 zā），或写错了音',
      );
    }
  });

  test('热词不重复', () {
    expect(lines.toSet().length, lines.length, reason: '重复条目只是白占热词图');
  });

  // 热词按字查词表编码，缺一个字整条就被丢弃——这条断言防止再把生僻字写回来。
  test(
    '每条热词的每个字都在模型词表里',
    () {
      final missing = <String>{};
      for (final line in lines) {
        for (final char in line.split('')) {
          if (!vocabulary!.contains(char)) missing.add(char);
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            '这些字不在 tokens.txt 里，含它们的整条热词都会被识别器丢掉：'
            '${missing.join('、')}',
      );
    },
    skip: vocabulary == null
        ? '没有模型资产（$_tokensPath），跳过词表断言'
        : false,
  );
}
