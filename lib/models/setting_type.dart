/// 设定集类型：世界观 / 地点 / 道具（B-09），存储值对应 SETTING_ENTRY.type。
enum SettingType {
  worldview('worldview', '世界观'),
  location('location', '地点'),
  item('item', '道具');

  const SettingType(this.value, this.label);

  /// 数据库存储值。
  final String value;

  /// 界面展示文案。
  final String label;

  static SettingType fromValue(String value) {
    return SettingType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => SettingType.worldview,
    );
  }
}