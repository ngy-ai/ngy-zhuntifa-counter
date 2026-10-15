import 'dart:math' as math;

import 'package:pinyin/pinyin.dart';

/// 准提咒原文（用于拼音转换与文档说明）。
const String mantraText =
    '南无飒哆喃。三藐三菩陀。俱胝喃。怛侄他。唵。折戾主戾。准提娑婆诃。';

/// 准提咒的拼音（不带声调），由 [mantraText] 转换而来，并由测试锁定。
///
/// 语音识别经常把咒文识别成音近的别的字（「飒哆喃」→「萨多南」、
/// 「俱胝喃」→「俱知南」），汉字对不上但拼音几乎一致，所以比对拼音。
const String mantraPinyin =
    'namosaduonan' 'sanmiaosanputuo' 'juzhinan' 'dazhita' 'an' 'zhelizhuli' 'zhuntisuopohe';

/// 实际念诵里与文读不同的读音，比对前先归一化回文读，这样各家各派的念法都能计数。
///
/// 汉字拼音给的是文读（怛侄他 dá zhí tā、唵 ān、娑婆诃 suō pó hē），而课诵习惯
/// 多念成「da zha tuo / ōng / suo ha」，语音识别照念出来的音转写，拼音就和文读对不上。
///
/// 键是听成的音，值是 [mantraPinyin] 里的文读音；要加新念法在这里补一行即可。
/// 注意：键之间不能互相包含（否则替换会互相破坏，见 mantra_matcher_test.dart）。
const Map<String, String> mantraPinyinAliases = <String, String>{
  // 怛侄他：文读 dá zhí tā，课诵多念 da zha tuo
  'dazhatuo': 'dazhita',
  'dazhaduo': 'dazhita', // 末字被听成「多」
  'dazhata': 'dazhita', // 末字被听成「他」
  // 唵：文读 ān，课诵多念 ōng
  'weng': 'an', // 嗡 / 翁
  'wang': 'an', // 王 / 汪 这类近音
  'hong': 'an', // 轰
  // 娑婆诃：文读 suō pó hē，课诵多念 suo ha
  'suoha': 'suopohe', // 娑哈 / 梭哈 / 索哈
  'suopoha': 'suopohe', // 娑婆哈
  'suohe': 'suopohe', // 娑嚩诃：「嚩」无拼音会被丢掉
  'suowahe': 'suopohe', // 娑嚩诃（识别器补出了「嚩」的音）
  'sapohe': 'suopohe', // 萨婆诃
};

/// 把语音识别结果按「遍」比对，判断是否圆满了一遍准提咒。
///
/// 判定条件有两条，缺一不可：
/// 1. 整体与咒文拼音的二元组 Dice 相似度足够高（容忍识别错字、漏字）；
/// 2. 结尾「准提娑婆诃」也确实听到——否则念到一半停下也会被误记成一遍。
///
/// 比对前会先把常见念诵读音归一化（见 [mantraPinyinAliases]），因此按
/// 「da zha tuo / ōng / suo ha」这类课诵习惯念，同样能判成圆满一遍。
class MantraMatcher {
  MantraMatcher({
    this.threshold = 0.75,
    this.tailThreshold = 0.7,
    String? targetPinyin,
  }) : target = targetPinyin ?? mantraPinyin {
    _targetBigrams = _bigramCounts(target);
    final tailLength = math.max(3, (target.length * 0.3).round());
    _tail = target.substring(math.max(0, target.length - tailLength));
    _tailBigrams = _bigramCounts(_tail);
  }

  /// 整体相似度阈值。
  final double threshold;

  /// 结尾相似度阈值。
  final double tailThreshold;

  /// 比对的咒文拼音。
  final String target;

  late final Map<String, int> _targetBigrams;
  late final Map<String, int> _tailBigrams;
  late final String _tail;

  /// 上次判定之后累积的拼音，可能包含半遍未念完的内容。
  String _pending = '';

  /// 最近一次识别到的原文。
  String _lastHeard = '';

  String get lastHeard => _lastHeard;

  String get pending => _pending;

  /// 追加一段识别文本，返回这一次新判定出的圆满遍数。
  int accept(String recognizedText) {
    final trimmed = recognizedText.trim();
    if (trimmed.isEmpty) return 0;
    _lastHeard = trimmed;

    final pinyin = toPinyin(trimmed);
    if (pinyin.isEmpty) return 0;

    _pending += normalizePinyin(pinyin);
    final matched = _consume();
    _trim();
    return matched;
  }

  /// 清空累积状态（关闭语音时调用）。
  void reset() {
    _pending = '';
    _lastHeard = '';
  }

  /// 把常见念诵读音归一化回文读拼音（见 [mantraPinyinAliases]）。
  ///
  /// 别名之间互不包含，逐个替换不会互相破坏；没有别名时原样返回。
  static String normalizePinyin(String pinyin) {
    var result = pinyin;
    for (final alias in mantraPinyinAliases.entries) {
      if (result.contains(alias.key)) {
        result = result.replaceAll(alias.key, alias.value);
      }
    }
    return result;
  }

  /// 汉字转不带声调的字母拼音，非汉字一律丢掉。
  static String toPinyin(String text) {
    if (text.isEmpty) return '';
    final raw = PinyinHelper.getPinyinE(
      text,
      separator: '',
      defPinyin: '',
      format: PinyinFormat.WITHOUT_TONE,
    ).toLowerCase();

    final buffer = StringBuffer();
    for (final code in raw.codeUnits) {
      if (code >= 0x61 && code <= 0x7a) buffer.writeCharCode(code);
    }
    return buffer.toString();
  }

  /// 从左往右贪心找完整的咒文，返回找到的遍数；未匹配的部分留待下段拼接。
  int _consume() {
    final minLength = (target.length * 0.55).round();
    final maxLength = (target.length * 1.5).round();

    var consumed = 0;
    var scan = 0;
    var matched = 0;

    while (scan + minLength <= _pending.length) {
      final limit = math.min(scan + maxLength, _pending.length);
      final counts = <String, int>{};
      var common = 0;
      var bestScore = 0.0;
      var bestEnd = -1;

      for (var end = scan + 2; end <= limit; end++) {
        final gram = _pending.substring(end - 2, end);
        final previous = counts[gram] ?? 0;
        counts[gram] = previous + 1;
        // 二元组只按目标串里的出现次数计入，避免重复字拉高相似度
        if (previous < (_targetBigrams[gram] ?? 0)) common++;

        final length = end - scan;
        if (length < minLength) continue;

        final score = 2 * common / (length - 1 + target.length - 1);
        if (score > bestScore) {
          bestScore = score;
          bestEnd = end;
        }
      }

      if (bestScore >= threshold &&
          bestEnd > 0 &&
          _tailMatches(_pending.substring(scan, bestEnd))) {
        matched++;
        consumed = bestEnd;
        scan = bestEnd;
      } else {
        scan++;
      }
    }

    if (consumed > 0) _pending = _pending.substring(consumed);
    return matched;
  }

  /// 结尾是否听到了「准提娑婆诃」。
  bool _tailMatches(String window) {
    final tailLength = math.min(window.length, _tail.length);
    if (tailLength < 3) return false;
    final windowTail = window.substring(window.length - tailLength);
    final counts = _bigramCounts(windowTail);

    var common = 0;
    counts.forEach((gram, count) {
      final targetCount = _tailBigrams[gram];
      if (targetCount != null) common += math.min(count, targetCount);
    });

    final denominator = windowTail.length - 1 + _tail.length - 1;
    if (denominator <= 0) return false;
    return 2 * common / denominator >= tailThreshold;
  }

  /// 累积太多说明一直没匹配上（噪声），只保留尾部，避免无限增长。
  void _trim() {
    final maxKeep = (target.length * 2.2).round();
    if (_pending.length > maxKeep) {
      _pending = _pending.substring(_pending.length - maxKeep);
    }
  }

  static Map<String, int> _bigramCounts(String value) {
    final counts = <String, int>{};
    for (var index = 0; index + 1 < value.length; index++) {
      final gram = value.substring(index, index + 2);
      counts[gram] = (counts[gram] ?? 0) + 1;
    }
    return counts;
  }
}
