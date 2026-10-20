import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/chat_citations.dart';

/// ENH-43：作品问答的章节引用标记解析与展示清洗。
void main() {
  test('按出现顺序解析并去重章节 id', () {
    expect(ChatCitations.parse('沈砚离乡 [[ch:12]]，苏晚追问 [[ch: 3]]。'), <int>[12, 3]);
    expect(ChatCitations.parse('[[CH:7]][[ch:7]]'), <int>[7]);
    expect(ChatCitations.parse('[[ch：9]]'), <int>[9]);
  });

  test('忽略非法与重复标记', () {
    expect(ChatCitations.parse(''), isEmpty);
    expect(ChatCitations.parse('[[ch:]] [[ch:0]] [[ch:abc]] [ch:2]'), isEmpty);
  });

  test('去掉标记并清理多余空格与空行', () {
    expect(ChatCitations.strip('沈砚离乡 [[ch:12]]。'), '沈砚离乡。');
    expect(ChatCitations.strip('沈砚 [[ch:12]] 离乡'), '沈砚 离乡');
    expect(ChatCitations.strip('第一段 [[ch:1]]\n\n\n第二段'), '第一段\n\n第二段');
    expect(ChatCitations.strip('  原文  '), '原文');
  });

  test('无标记文本只去除首尾空白，不改动内部排版', () {
    expect(ChatCitations.strip('保留  双空格'), '保留  双空格');
  });

  test('ENH-47：去掉包裹标记的空括号与重复标点', () {
    expect(ChatCitations.strip('苏晚随后追问（[[ch:12]]）。'), '苏晚随后追问。');
    expect(ChatCitations.strip('沈砚离乡[[ch:12]]，[[ch:13]]，苏晚目送。'), '沈砚离乡，苏晚目送。');
    expect(ChatCitations.strip('（[[ch:12]]）'), '');
  });

  test('ENH-47：按标记位置拆分为文本段与引用段', () {
    final segments = ChatCitations.segments('沈砚离乡（[[ch:12]]），苏晚追问 [[ch:13]]。');
    expect(
      segments
          .map(
            (segment) =>
                segment.isCitation ? 'ch:${segment.chapterId}' : segment.text,
          )
          .toList(),
      <String>['沈砚离乡', 'ch:12', '，苏晚追问 ', 'ch:13', '。'],
    );
    expect(ChatCitations.segments('无引用'), hasLength(1));
    expect(ChatCitations.segments(''), isEmpty);
  });

  test('ENH-47：同一章节重复标记只内联一次，非法标记不产生引用段', () {
    final segments = ChatCitations.segments('甲 [[ch:1]] 乙 [[ch:1]] [[ch:0]]');
    expect(segments.where((segment) => segment.isCitation), hasLength(1));
    expect(segments.where((segment) => segment.isCitation).single.chapterId, 1);
  });
}
