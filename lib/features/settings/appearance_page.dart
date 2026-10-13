import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/reading_appearance.dart';
import '../../app/theme.dart';
import '../../data/data_providers.dart';

/// 写作外观设置（B-04）：夜间纸张、正文字号、行距，改完即时保存。
/// 仅作用于编辑器写作区（对齐 PRD「深夜沉浸：关灯后切换护眼深色模式，全屏专注写作」）。
class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  ReadingAppearance? _appearance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final raw = await repo.getSetting(ReadingAppearance.settingKey);
    if (!mounted) return;
    setState(() => _appearance = ReadingAppearance.decode(raw));
  }

  Future<void> _save(ReadingAppearance next) async {
    setState(() => _appearance = next);
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(ReadingAppearance.settingKey, next.encode());
    // 让已缓存的读取结果失效，编辑器下次构建即为新外观。
    ref.invalidate(readingAppearanceProvider);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _appearance;
    return Scaffold(
      appBar: AppBar(title: const Text('写作外观')),
      body: appearance == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('夜间纸张'),
                  subtitle: const Text('深色护眼背景，适合关灯后写作'),
                  value: appearance.dark,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                  onChanged: (v) => _save(appearance.copyWith(dark: v)),
                ),
                const Divider(height: 24),
                _SliderTile(
                  label: '正文字号',
                  value: appearance.fontSize,
                  min: ReadingAppearance.minFontSize,
                  max: ReadingAppearance.maxFontSize,
                  divisions:
                      (ReadingAppearance.maxFontSize - ReadingAppearance.minFontSize)
                          .round(),
                  display: '${appearance.fontSize.round()}',
                  onChanged: (v) => _save(appearance.copyWith(fontSize: v)),
                ),
                _SliderTile(
                  label: '行距',
                  value: appearance.lineHeight,
                  min: ReadingAppearance.minLineHeight,
                  max: ReadingAppearance.maxLineHeight,
                  divisions:
                      ((ReadingAppearance.maxLineHeight -
                                  ReadingAppearance.minLineHeight) *
                              10)
                          .round(),
                  display: appearance.lineHeight.toStringAsFixed(1),
                  onChanged: (v) => _save(appearance.copyWith(lineHeight: v)),
                ),
                const Divider(height: 24),
                Text(
                  '预览',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _Preview(appearance: appearance),
              ],
            ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(label),
            const Spacer(),
            Text(
              display,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: display,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 预览：按当前外观渲染一段示例正文（写作区所见即所得）。
class _Preview extends StatelessWidget {
  const _Preview({required this.appearance});

  final ReadingAppearance appearance;

  @override
  Widget build(BuildContext context) {
    // 全局深色时预览同步跟随，保证「所见即所得」。
    final globalDark = Theme.of(context).brightness == Brightness.dark;
    final palette = ReadingPalette.of(appearance, globalDark: globalDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '长夜将尽，她推开窗，风雪扑面而来。\n'
        '远处的灯一盏盏熄灭，只有案头那支蜡烛还亮着。',
        style: TextStyle(
          fontFamily: kSerifFontFamily,
          fontFamilyFallback: kSerifFontFallback,
          fontSize: appearance.fontSize,
          height: appearance.lineHeight,
          color: palette.ink,
        ),
      ),
    );
  }
}