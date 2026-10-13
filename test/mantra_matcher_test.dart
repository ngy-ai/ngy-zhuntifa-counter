import 'package:flutter_test/flutter_test.dart';
import 'package:ngy_zhuntifa_counter/voice/mantra_matcher.dart';

void main() {
  group('toPinyin', () {
    test('汉字转成不带声调的拼音，标点被丢弃', () {
      expect(MantraMatcher.toPinyin('南无飒哆喃。'), 'namosaduonan');
      expect(MantraMatcher.toPinyin('，。！？'), isEmpty);
      expect(MantraMatcher.toPinyin(''), isEmpty);
    });

    test('咒文原文转换出的拼音与锁定的常量一致', () {
      expect(MantraMatcher.toPinyin(mantraText), mantraPinyin);
    });
  });

  group('整遍判定', () {
    test('完整念一遍计数一次', () {
      final matcher = MantraMatcher();

      expect(matcher.accept(mantraText), 1);
      expect(matcher.lastHeard, mantraText);
      expect(matcher.pending, isEmpty);
    });

    test('识别成同音字也能计数', () {
      final matcher = MantraMatcher();

      // 「飒哆喃」被听成「萨多南」、「俱胝喃」被听成「俱知南」，拼音几乎一致
      expect(
        matcher.accept('南无萨多南三藐三菩陀俱知南怛侄他唵折戾主戾准提娑婆诃'),
        1,
      );
    });

    test('个别字听错不影响计数', () {
      final matcher = MantraMatcher();

      // 「三菩陀」被听成「三菩提」
      expect(
        matcher.accept('南无飒哆喃三藐三菩提俱胝喃怛侄他唵折戾主戾准提娑婆诃'),
        1,
      );
    });

    test('一段文本里连念两遍会计数两次', () {
      final matcher = MantraMatcher();

      expect(matcher.accept(mantraText + mantraText), 2);
      expect(matcher.pending, isEmpty);
    });
  });

  group('跨段拼接', () {
    test('分两段听到的咒文拼成一遍', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃'), 0);
      expect(matcher.pending, isNotEmpty);

      expect(matcher.accept('怛侄他唵折戾主戾准提娑婆诃'), 1);
      expect(matcher.pending, isEmpty);
    });

    test('念到一半停下不算一遍，补完才算', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他唵折戾主戾'), 0);
      expect(matcher.pending, isNotEmpty);

      expect(matcher.accept('准提娑婆诃'), 1);
      expect(matcher.pending, isEmpty);
    });

    test('闲聊之后念完整一遍仍能识别', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('今天天气不错'), 0);
      expect(matcher.accept(mantraText), 1);
    });
  });

  group('状态管理', () {
    test('无关内容不会被计入', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('阿弥陀佛'), 0);
      expect(matcher.accept('南无阿弥陀佛'), 0);
      expect(matcher.lastHeard, '南无阿弥陀佛');
    });

    test('长时间只有噪声时累积的拼音会被裁剪', () {
      final matcher = MantraMatcher();

      for (var index = 0; index < 10; index++) {
        expect(matcher.accept('今天天气真好'), 0);
      }

      final maxKeep = (mantraPinyin.length * 2.2).round();
      expect(matcher.pending.length, lessThanOrEqualTo(maxKeep));
    });

    test('reset 会清空累积状态', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他'), 0);
      expect(matcher.pending, isNotEmpty);

      matcher.reset();

      expect(matcher.pending, isEmpty);
      expect(matcher.lastHeard, isEmpty);
      // 残留清空后，单独念后半段不会被误判成一遍
      expect(matcher.accept('唵折戾主戾准提娑婆诃'), 0);
    });

    test('空白输入不改变状态', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('   '), 0);
      expect(matcher.lastHeard, isEmpty);

      expect(matcher.accept('，。！'), 0);
      expect(matcher.pending, isEmpty);
    });
  });
}
