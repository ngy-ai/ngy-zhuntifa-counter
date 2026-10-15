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

  group('念诵读音归一化', () {
    test('别名表里的文读音都能在咒文拼音里找到', () {
      for (final canonical in mantraPinyinAliases.values) {
        expect(
          mantraPinyin.contains(canonical),
          isTrue,
          reason: '$canonical 不在咒文拼音里',
        );
      }
    });

    test('常见念法会被映射回文读拼音', () {
      expect(
        MantraMatcher.normalizePinyin('dazhatuowengzhelizhulizhuntisuoha'),
        'dazhitaanzhelizhulizhuntisuopohe',
      );
      // 娑嚩诃（「嚩」没有拼音会被丢掉）与萨婆诃
      expect(MantraMatcher.normalizePinyin('suohe'), 'suopohe');
      expect(MantraMatcher.normalizePinyin('suowahe'), 'suopohe');
      expect(MantraMatcher.normalizePinyin('sapohe'), 'suopohe');
      // 文读本身不受影响
      expect(MantraMatcher.normalizePinyin(mantraPinyin), mantraPinyin);
      // 无关内容原样返回
      expect(MantraMatcher.normalizePinyin('amituofo'), 'amituofo');
    });

    test('别名表里每个念法都能单独归一化回文读', () {
      mantraPinyinAliases.forEach((alias, canonical) {
        expect(
          MantraMatcher.normalizePinyin(alias),
          canonical,
          reason: '「$alias」应归一化为「$canonical」',
        );
      });
    });

    test('同一别名重复出现时全部替换', () {
      expect(MantraMatcher.normalizePinyin('suohasuoha'), 'suopohesuopohe');
      expect(
        MantraMatcher.normalizePinyin('dazhaduodazhaduo'),
        'dazhitadazhita',
      );
    });

    test('别名之间互不包含，逐个替换不会互相破坏', () {
      final keys = mantraPinyinAliases.keys.toList();
      for (final outer in keys) {
        for (final inner in keys) {
          if (outer == inner) continue;
          expect(
            outer.contains(inner),
            isFalse,
            reason: '别名 $inner 是 $outer 的一部分，替换顺序会影响结果',
          );
        }
      }
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
      expect(matcher.accept('南无萨多南三藐三菩陀俱知南怛侄他唵折戾主戾准提娑婆诃'), 1);
    });

    test('个别字听错不影响计数', () {
      final matcher = MantraMatcher();

      // 「三菩陀」被听成「三菩提」
      expect(matcher.accept('南无飒哆喃三藐三菩提俱胝喃怛侄他唵折戾主戾准提娑婆诃'), 1);
    });

    test('一段文本里连念两遍会计数两次', () {
      final matcher = MantraMatcher();

      expect(matcher.accept(mantraText + mantraText), 2);
      expect(matcher.pending, isEmpty);
    });

    test('课诵习惯的念法（da zha tuo / ōng / suo ha）也能计数', () {
      final matcher = MantraMatcher();

      // 「怛侄他」念成「大吒陀」、「唵」念成「嗡」、「娑婆诃」念成「娑哈」
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提娑哈'), 1);
    });

    test('别的念诵版本（唵念 ān、娑婆诃、萨婆诃、娑嚩诃）都能计数', () {
      final matcher = MantraMatcher();

      // 文读「唵」+「娑婆诃」
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他唵折戾主戾准提娑婆诃'), 1);
      // 「萨婆诃」
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他唵折戾主戾准提萨婆诃'), 1);
      // 「娑嚩诃」
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他唵折戾主戾准提娑嚩诃'), 1);
      // 课诵念法「大吒陀 / 嗡 / 娑哈」
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提娑哈'), 1);
    });

    test('用课诵念法念到一半停下仍不算一遍', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提'), 0);

      // 补上结尾才算圆满
      expect(matcher.accept('娑哈'), 1);
    });

    test('各家念法的完整变体都能判成一遍', () {
      const variants = <String, String>{
        '大吒多（怛侄他末字听成「多」）': '南无飒哆喃三藐三菩陀俱胝喃大吒多嗡折戾主戾准提娑哈',
        '大吒他（怛侄他末字听成「他」）': '南无飒哆喃三藐三菩陀俱胝喃大吒他嗡折戾主戾准提娑哈',
        '王（唵听成 Wang）': '南无飒哆喃三藐三菩陀俱胝喃大吒陀王折戾主戾准提娑哈',
        '轰（唵听成 Hong）': '南无飒哆喃三藐三菩陀俱胝喃大吒陀轰折戾主戾准提娑哈',
        '娑婆哈（娑婆诃听成 suo po ha）': '南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提娑婆哈',
      };

      variants.forEach((name, text) {
        final matcher = MantraMatcher();
        expect(matcher.accept(text), 1, reason: name);
        expect(matcher.pending, isEmpty, reason: name);
      });
    });

    test('课诵念法连念两遍计数两次', () {
      final matcher = MantraMatcher();
      const chanting = '南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提娑哈';

      expect(matcher.accept(chanting + chanting), 2);
      expect(matcher.pending, isEmpty);
    });

    test('文读与课诵念法混着念都计数', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃怛侄他唵折戾主戾准提娑婆诃'), 1);
      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃大吒陀嗡折戾主戾准提娑哈'), 1);
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

    test('课诵念法分两段听到也能拼成一遍', () {
      final matcher = MantraMatcher();

      expect(matcher.accept('南无飒哆喃三藐三菩陀俱胝喃大吒多嗡'), 0);
      expect(matcher.pending, isNotEmpty);

      expect(matcher.accept('折戾主戾准提娑哈'), 1);
      expect(matcher.pending, isEmpty);
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
