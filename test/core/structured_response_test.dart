import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/structured_response.dart';
import 'package:novelphone/models/setting_type.dart';
import 'package:novelphone/models/work_style_guide.dart';

void main() {
  group('parseStyleGuideResponse', () {
    test('解析中文键名与围栏 JSON', () {
      final guide = parseStyleGuideResponse('''
```json
{
  "叙事人称": "第三人称限知，跟随沈砚",
  "语言风格": "冷峻克制，短句为主",
  "禁忌": ["不用网络流行语", "少用感叹号"],
  "示例段落": "雨落在刀鞘上，他没有回头。"
}
```
''');

      expect(guide, isNotNull);
      expect(guide!.perspective, '第三人称限知，跟随沈砚');
      expect(guide.tone, '冷峻克制，短句为主');
      expect(guide.taboos, contains('不用网络流行语'));
      expect(guide.taboos, contains('；'));
      expect(guide.sample, '雨落在刀鞘上，他没有回头。');
    });

    test('缺字段沿用现有档案', () {
      const fallback = WorkStyleGuide(perspective: '第一人称', sample: '旧示例');
      final guide = parseStyleGuideResponse(
        '{"tone": "轻盈明快"}',
        fallback: fallback,
      );

      expect(guide, isNotNull);
      expect(guide!.perspective, '第一人称');
      expect(guide.tone, '轻盈明快');
      expect(guide.sample, '旧示例');
    });

    test('非 JSON 或空档案返回 null', () {
      expect(parseStyleGuideResponse('抱歉，我无法完成。'), isNull);
      expect(parseStyleGuideResponse('{"perspective": "  "}'), isNull);
    });
  });

  group('parseEntityExtractionResponse', () {
    test('解析角色与设定并去重', () {
      final extraction = parseEntityExtractionResponse('''
[
  {"characters": [
    {"name": "沈砚", "identity": "游侠", "性格": "沉默、克制", "外貌": "左眉有疤"},
    {"name": "沈砚", "identity": "重复项"},
    {"name": "苏晚", "身份": "医女", "关系": "沈砚的旧识"}
  ]},
  {"settings": [
    {"name": "长夜城", "type": "地点", "content": "北境边城，常年落雪"},
    {"name": "青铜灯", "类型": "道具", "描述": "照见亡者记忆"},
    {"name": "长夜城", "type": "地点", "content": "重复项"},
    {"name": "灵潮", "type": "世界观", "content": "每隔十年涨落一次"}
  ]}
]
''');

      expect(extraction.parseFailed, isFalse);
      expect(extraction.characters, hasLength(2));
      expect(extraction.characters.first.name, '沈砚');
      expect(extraction.characters.first.personality, '沉默、克制');
      expect(extraction.characters.first.appearance, '左眉有疤');
      expect(extraction.characters.last.relations, '沈砚的旧识');

      expect(extraction.settings, hasLength(3));
      expect(extraction.settings[0].type, SettingType.location);
      expect(extraction.settings[0].content, '北境边城，常年落雪');
      expect(extraction.settings[1].type, SettingType.item);
      expect(extraction.settings[2].type, SettingType.worldview);
      expect(extraction.total, 5);
    });

    test('数组中的多个对象也能逐项读取', () {
      final extraction = parseEntityExtractionResponse('''
[{"characters": [{"name": "甲"}]}, {"settings": [{"name": "乙", "type": "地点"}]}]
''');
      expect(extraction.characters, hasLength(1));
      expect(extraction.settings, hasLength(1));
    });

    test('非 JSON 标记解析失败', () {
      final extraction = parseEntityExtractionResponse('好的，我已抽取完成。');
      expect(extraction.parseFailed, isTrue);
      expect(extraction.isEmpty, isTrue);
    });
  });

  group('parsePlotPlanResponse', () {
    test('解析走向与分章建议', () {
      final plan = parsePlotPlanResponse('''
```json
{
  "directions": [
    {
      "title": "雪夜决裂",
      "summary": "沈砚发现苏晚隐瞒身份",
      "beats": ["二人对质", "苏晚亮出信物", "沈砚放她离开"],
      "hook": "信物上的纹样与灭门案有关"
    }
  ],
  "chapters": [
    {"title": "第十二章 雪夜", "summary": "对质与决裂"},
    {"title": "第十三章 旧信", "summary": "沈砚追查信物来历"}
  ]
}
```
''');

      expect(plan.parseFailed, isFalse);
      expect(plan.directions, hasLength(1));
      expect(plan.directions.single.title, '雪夜决裂');
      expect(plan.directions.single.beats, contains('苏晚亮出信物'));
      expect(plan.directions.single.hook, contains('灭门案'));
      expect(plan.chapters, hasLength(2));
      expect(plan.chapters.last.title, '第十三章 旧信');
    });

    test('纯文本输出降级为单条走向', () {
      final plan = parsePlotPlanResponse('建议下一章让沈砚主动摊牌，结尾留下追兵逼近的悬念。');
      expect(plan.parseFailed, isTrue);
      expect(plan.directions, hasLength(1));
      expect(plan.directions.single.summary, contains('主动摊牌'));
      expect(plan.chapters, isEmpty);
    });

    test('空输出返回空计划', () {
      final plan = parsePlotPlanResponse('   ');
      expect(plan.isEmpty, isTrue);
      expect(plan.parseFailed, isFalse);
    });
  });
}
