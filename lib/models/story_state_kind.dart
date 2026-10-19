/// 故事状态卡类型（ENH-31），存储值对应 STORY_STATE.kind。
enum StoryStateKind {
  character('character', '角色状态'),
  foreshadow('foreshadow', '伏笔'),
  timeline('timeline', '时间线');

  const StoryStateKind(this.value, this.label);

  /// 数据库存储值。
  final String value;

  /// 默认展示文案（页面按 locale 覆盖）。
  final String label;

  static StoryStateKind fromValue(String value) {
    return StoryStateKind.values.firstWhere(
      (k) => k.value == value,
      orElse: () => StoryStateKind.character,
    );
  }
}
