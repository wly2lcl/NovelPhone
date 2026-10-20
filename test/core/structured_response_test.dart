import 'package:flutter_test/flutter_test.dart';
import 'package:novelphone/core/ai/structured_response.dart';
import 'package:novelphone/models/setting_type.dart';
import 'package:novelphone/models/story_state_kind.dart';
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
  ]},
  {"relations": [
    {"from": "沈砚", "to": "苏晚", "label": "旧识，互不信任"},
    {"from": "沈砚", "to": "苏晚", "label": "旧识，互不信任"},
    {"from": "苏晚", "to": "苏晚", "label": "自指应丢弃"},
    {"from": "沈砚", "to": "长夜城", "relation": "驻留"}
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

      expect(extraction.relations, hasLength(2));
      expect(extraction.relations.first.from, '沈砚');
      expect(extraction.relations.first.to, '苏晚');
      expect(extraction.relations.first.summary, '沈砚 → 苏晚 · 旧识，互不信任');
      expect(extraction.relations.last.label, '驻留');
      expect(extraction.total, 7);
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

  group('parseStoryStateExtractionResponse', () {
    test('解析 states 数组并归一化类型与回收状态（ENH-35）', () {
      final extraction = parseStoryStateExtractionResponse('''
```json
{
  "states": [
    {"类型": "角色", "名称": "沈砚", "描述": "左臂中箭，暂不能提刀"},
    {"kind": "foreshadow", "title": "铜印来历", "status": "已回收"},
    {"kind": "timeline", "title": "雨夜入城", "detail": "子时从西门进城"}
  ]
}
```
''');

      expect(extraction.parseFailed, isFalse);
      expect(extraction.suggestions, hasLength(3));
      expect(extraction.suggestions[0].kind, StoryStateKind.character);
      expect(extraction.suggestions[0].detail, '左臂中箭，暂不能提刀');
      expect(extraction.suggestions[0].closes, isFalse);
      expect(extraction.suggestions[1].kind, StoryStateKind.foreshadow);
      expect(extraction.suggestions[1].closes, isTrue);
      expect(extraction.suggestions[2].kind, StoryStateKind.timeline);
      expect(extraction.suggestions[2].detail, '子时从西门进城');
    });

    test('支持按类型分组与直接数组，同类同名以最后一条为准', () {
      final grouped = parseStoryStateExtractionResponse(
        '{"characters":[{"name":"沈砚","detail":"旧伤未愈"}],'
        '"foreshadows":[{"title":"铜印来历"}],'
        '"timeline":[{"title":"雨夜入城"}]}',
      );
      expect(grouped.suggestions, hasLength(3));
      expect(grouped.suggestions[0].kind, StoryStateKind.character);
      expect(grouped.suggestions[1].kind, StoryStateKind.foreshadow);
      expect(grouped.suggestions[2].kind, StoryStateKind.timeline);

      final merged = parseStoryStateExtractionResponse(
        '[{"kind":"character","title":"沈砚","detail":"旧伤未愈"},'
        '{"kind":"character","title":"沈砚","detail":"左臂中箭"}]',
      );
      expect(merged.suggestions, hasLength(1));
      expect(merged.suggestions.single.detail, '左臂中箭');
    });

    test('非 JSON 标记解析失败，空变化不算失败', () {
      expect(parseStoryStateExtractionResponse('本章没有变化').parseFailed, isTrue);
      final empty = parseStoryStateExtractionResponse('{"states":[]}');
      expect(empty.parseFailed, isFalse);
      expect(empty.isEmpty, isTrue);
      expect(parseStoryStateExtractionResponse('[]').parseFailed, isFalse);
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

    test('合法 JSON 但字段名不匹配时标记解析失败', () {
      final plan = parsePlotPlanResponse('{"results": [{"name": "雪夜决裂"}]}');
      expect(plan.parseFailed, isTrue);
      expect(plan.directions, isEmpty);
      expect(plan.chapters, isEmpty);
      expect(plan.rawText, contains('雪夜决裂'));
    });

    test('空输出返回空计划', () {
      final plan = parsePlotPlanResponse('   ');
      expect(plan.isEmpty, isTrue);
      expect(plan.parseFailed, isFalse);
    });
  });

  group('parseContinuityResponse', () {
    test('解析结构化冲突并按原文与来源去重', () {
      final check = parseContinuityResponse('''
```json
{
  "summary": "发现 2 处冲突",
  "issues": [
    {
      "quote": "苏晚今年十六岁",
      "detail": "角色卡中苏晚二十四岁",
      "source": "角色卡·苏晚",
      "suggestion": "改为二十四岁",
      "severity": "严重"
    },
    {
      "quote": "苏晚今年十六岁",
      "detail": "重复条目",
      "source": "角色卡·苏晚"
    },
    {
      "quote": "铜印不见了",
      "detail": "状态卡记录铜印在怀中",
      "source": "故事状态·沈砚",
      "suggestion": "补写丢失经过",
      "severity": "low"
    }
  ]
}
```
''');

      expect(check.parseFailed, isFalse);
      expect(check.clean, isFalse);
      expect(check.summary, '发现 2 处冲突');
      expect(check.issues, hasLength(2));
      expect(check.issues.first.severity, 'high');
      expect(check.issues.first.source, '角色卡·苏晚');
      expect(check.issues.last.severity, 'low');
    });

    test('模型输出裸数组与中文键名也能解析', () {
      final check = parseContinuityResponse(
        '[{"原文":"她把伞收起来","说明":"设定集记录当夜无雨",'
        '"来源":"设定集·天气","建议":"删去雨伞","严重程度":"中等"}]',
      );

      expect(check.parseFailed, isFalse);
      expect(check.issues.single.quote, '她把伞收起来');
      expect(check.issues.single.detail, contains('无雨'));
      expect(check.issues.single.severity, 'medium');
    });

    test('没有冲突时结构化为 clean', () {
      final check = parseContinuityResponse(
        '{"summary":"未发现设定冲突","issues":[]}',
      );

      expect(check.parseFailed, isFalse);
      expect(check.clean, isTrue);
      expect(check.issues, isEmpty);
    });

    test('非 JSON 或无法识别字段时回退原文', () {
      final plain = parseContinuityResponse('未发现设定冲突');
      expect(plain.parseFailed, isTrue);
      expect(plain.rawText, '未发现设定冲突');

      final unknown = parseContinuityResponse('{"foo":"bar"}');
      expect(unknown.parseFailed, isTrue);
      expect(unknown.rawText, contains('foo'));
    });
  });

  group('findContinuityQuote', () {
    test('精确定位冲突原文', () {
      const content = '雪夜里，沈砚推门而入。\n他把铜印揣进怀里。';
      final range = findContinuityQuote(content, '他把铜印揣进怀里');

      expect(range, isNotNull);
      expect(content.substring(range!.start, range.end), '他把铜印揣进怀里');
    });

    test('忽略空白差异与多余引号', () {
      const content = '苏晚今年\n二十四岁，仍住在城南。';
      final range = findContinuityQuote(content, '「苏晚今年二十四岁」');

      expect(range, isNotNull);
      expect(content.substring(range!.start, range.end), '苏晚今年\n二十四岁');
    });

    test('找不到时返回 null', () {
      expect(findContinuityQuote('沈砚推门而入。', '苏晚笑了'), isNull);
      expect(findContinuityQuote('沈砚推门而入。', '   '), isNull);
    });
  });
}
