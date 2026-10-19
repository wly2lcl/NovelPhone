import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/insert_separator.dart';

/// ENH-27.1：AI 结果插入光标处时自动补段落分隔。
void main() {
  test('文末插入在结果前补一个空行', () {
    expect(
      composeAiInsertion(document: '他推门进来。', offset: 6, text: '屋里没有点灯。'),
      '\n\n屋里没有点灯。',
    );
  });

  test('文首插入在结果后补空行', () {
    expect(
      composeAiInsertion(document: '他推门进来。', offset: 0, text: '夜里下过雨。'),
      '夜里下过雨。\n\n',
    );
  });

  test('两侧都有正文时前后都补空行', () {
    expect(
      composeAiInsertion(document: '第一段。第二段。', offset: 4, text: '插入段。'),
      '\n\n插入段。\n\n',
    );
  });

  test('已有空行时不重复补', () {
    expect(
      composeAiInsertion(document: '第一段。\n\n', offset: 6, text: '第二段。'),
      '第二段。',
    );
    expect(
      composeAiInsertion(document: '第一段。\n\n第二段。', offset: 6, text: '插入段。'),
      '插入段。\n\n',
    );
  });

  test('已有一个换行时只补一个换行形成空行', () {
    expect(
      composeAiInsertion(document: '第一段。\n', offset: 5, text: '第二段。'),
      '\n第二段。',
    );
  });

  test('空文档与纯空白不补分隔', () {
    expect(composeAiInsertion(document: '', offset: 0, text: '开头。'), '开头。');
    expect(composeAiInsertion(document: '   ', offset: 1, text: '开头。'), '开头。');
  });

  test('越界偏移按文档长度处理', () {
    expect(
      composeAiInsertion(document: '正文。', offset: 99, text: '续写。'),
      '\n\n续写。',
    );
  });
}
