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
}
