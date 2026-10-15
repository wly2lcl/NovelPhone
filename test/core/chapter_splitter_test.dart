import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/importer/chapter_splitter.dart';

void main() {
  group('splitIntoChapters', () {
    test('识别「第 X 章」中文数字与阿拉伯数字', () {
      const text = '第一章 起始\n正文一\n\n第 2 章 转折\n正文二\n第三回 收束\n正文三';
      final drafts = splitIntoChapters(text);
      expect(drafts.length, 3);
      expect(drafts[0].title, '第一章 起始');
      expect(drafts[0].content, '正文一');
      expect(drafts[1].title, '第 2 章 转折');
      expect(drafts[2].title, '第三回 收束');
    });

    test('识别 markdown 标题（保证导出后再导入结构还原）', () {
      const text = '# 第一章 起始\n正文一\n## 第二章 转折\n正文二';
      final drafts = splitIntoChapters(text);
      expect(drafts.length, 2);
      expect(drafts[0].title, '第一章 起始');
      expect(drafts[1].title, '第二章 转折');
    });

    test('标题前的内容单独成章', () {
      const text = '作者的话\n\n第一章 起始\n正文一';
      final drafts = splitIntoChapters(text);
      expect(drafts.length, 2);
      expect(drafts[0].title, '');
      expect(drafts[0].content, '作者的话');
    });

    test('没有标题行时整篇一章并采用兜底标题', () {
      final drafts = splitIntoChapters('正文一\n正文二', fallbackTitle: '旧稿');
      expect(drafts.length, 1);
      expect(drafts.first.title, '旧稿');
    });

    test('空文本返回空列表', () {
      expect(splitIntoChapters('   \n  '), isEmpty);
    });

    test('超长标题按 50 字截断', () {
      final long = '第${'一' * 60}章 标题';
      final drafts = splitIntoChapters('$long\n正文');
      expect(drafts.first.title.length, lessThanOrEqualTo(50));
    });

    test('超长标题按码点截断，不劈开 emoji（ENH-09）', () {
      // emoji 恰好落在第 50 个位置上：旧实现按 UTF-16 码元 substring(0, 50)
      // 会切出孤立代理项（半个 emoji），按码点截断应保留完整 emoji。
      final long = '# ${'A' * 49}😀尾';
      final drafts = splitIntoChapters('$long\n正文');
      final title = drafts.first.title;
      expect(title.runes.length, 50);
      expect(title.endsWith('😀'), isTrue);
    });
  });

  group('ChapterDraft.wordCount（ENH-11）', () {
    test('同一实例重复读取结果稳定', () {
      final draft = ChapterDraft(title: '第一章', content: '雨下了一整夜。');
      expect(draft.wordCount, 6);
      expect(draft.wordCount, 6);
    });

    test('copyWith 变更正文后重新计算字数', () {
      final draft = ChapterDraft(title: '第一章', content: '正文一');
      expect(draft.wordCount, 3);
      final merged = draft.copyWith(content: '正文一\n\n正文二');
      expect(merged.wordCount, 6);
      // 原实例不受影响（各自缓存）。
      expect(draft.wordCount, 3);
    });
  });

  group('mergeWithPrevious', () {
    test('把指定章并入上一章并删除该章', () {
      final drafts = splitIntoChapters('第一章 A\n正文一\n第二章 B\n正文二');
      final merged = mergeWithPrevious(drafts, 1);
      expect(merged.length, 1);
      expect(merged.first.title, '第一章 A 第二章 B');
      expect(merged.first.content, '正文一\n\n正文二');
    });

    test('首章无法并入', () {
      final drafts = splitIntoChapters('第一章 A\n正文一\n第二章 B\n正文二');
      expect(mergeWithPrevious(drafts, 0), drafts);
    });
  });
}