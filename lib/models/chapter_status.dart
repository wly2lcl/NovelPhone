/// 章节状态：草稿 / 修订中 / 定稿（PRD 5.2）。
enum ChapterStatus {
  draft('draft', '草稿'),
  revising('revising', '修订中'),
  finished('final', '定稿');

  const ChapterStatus(this.value, this.label);

  /// 数据库存储值。
  final String value;

  /// 界面展示文案。
  final String label;

  static ChapterStatus fromValue(String value) {
    return ChapterStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ChapterStatus.draft,
    );
  }
}