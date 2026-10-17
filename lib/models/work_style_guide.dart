import 'dart:convert';

/// 作品级文风档案（ENH-23）：注入续写、改写、灵感等创作型任务。
class WorkStyleGuide {
  const WorkStyleGuide({
    this.perspective = '',
    this.tone = '',
    this.taboos = '',
    this.sample = '',
  });

  /// 叙事人称与视角，如「第三人称限知，跟随女主」。
  final String perspective;

  /// 语言风格与基调，如「冷峻克制，短句为主」。
  final String tone;

  /// 禁忌与偏好，如「不用网络流行语，少用感叹号」。
  final String taboos;

  /// 示例段落：只模仿语感，不照抄内容。
  final String sample;

  bool get isEmpty =>
      perspective.trim().isEmpty &&
      tone.trim().isEmpty &&
      taboos.trim().isEmpty &&
      sample.trim().isEmpty;

  static const WorkStyleGuide empty = WorkStyleGuide();

  WorkStyleGuide copyWith({
    String? perspective,
    String? tone,
    String? taboos,
    String? sample,
  }) {
    return WorkStyleGuide(
      perspective: perspective ?? this.perspective,
      tone: tone ?? this.tone,
      taboos: taboos ?? this.taboos,
      sample: sample ?? this.sample,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'perspective': perspective,
    'tone': tone,
    'taboos': taboos,
    'sample': sample,
  };

  factory WorkStyleGuide.fromJson(Map<String, dynamic> json) {
    String read(String key) {
      final value = json[key];
      return value is String ? value : '';
    }

    return WorkStyleGuide(
      perspective: read('perspective'),
      tone: read('tone'),
      taboos: read('taboos'),
      sample: read('sample'),
    );
  }

  /// 解析库中的 JSON 文本；脏数据按空档案处理。
  factory WorkStyleGuide.decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return empty;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return empty;
      return WorkStyleGuide.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return empty;
    }
  }

  String encode() => jsonEncode(toJson());

  /// 注入 system 的文本；空档案返回空串。
  String toPromptText() {
    if (isEmpty) return '';
    final buffer = StringBuffer('【作品文风档案】');
    if (perspective.trim().isNotEmpty) {
      buffer.writeln('\n叙事人称与视角：${perspective.trim()}');
    }
    if (tone.trim().isNotEmpty) {
      buffer.writeln('语言风格与基调：${tone.trim()}');
    }
    if (taboos.trim().isNotEmpty) {
      buffer.writeln('禁忌与偏好：${taboos.trim()}');
    }
    if (sample.trim().isNotEmpty) {
      final trimmed = sample.trim();
      buffer.writeln(
        '示例段落（只模仿语感与节奏，不要照抄内容）：\n'
        '${trimmed.length > 1200 ? '${trimmed.substring(0, 1200)}…' : trimmed}',
      );
    }
    buffer.writeln('以上文风要求优先于默认写作要求，但不得改变既有事实与情节。');
    return buffer.toString().trim();
  }

  @override
  bool operator ==(Object other) {
    return other is WorkStyleGuide &&
        other.perspective == perspective &&
        other.tone == tone &&
        other.taboos == taboos &&
        other.sample == sample;
  }

  @override
  int get hashCode => Object.hash(perspective, tone, taboos, sample);
}
