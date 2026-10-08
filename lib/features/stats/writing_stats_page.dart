import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/writing_stats.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';

/// 写作统计（B-07）：今日字数与每日目标进度、连续写作天数、番茄钟。
class WritingStatsPage extends ConsumerStatefulWidget {
  const WritingStatsPage({super.key});

  @override
  ConsumerState<WritingStatsPage> createState() => _WritingStatsPageState();
}

class _WritingStatsPageState extends ConsumerState<WritingStatsPage> {
  int? _target;
  int? _pomodoroMinutes;
  int _pomodoroDone = 0;

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final target = await repo.dailyWordTarget();
    final minutes = await repo.pomodoroMinutes();
    final done = await repo.pomodoroDoneToday();
    if (!mounted) return;
    setState(() {
      _target = target;
      _pomodoroMinutes = minutes;
      _remainingSeconds = minutes * 60;
      _pomodoroDone = done;
    });
  }

  // ---------- 番茄钟 ----------

  void _startTimer() {
    final minutes = _pomodoroMinutes ?? 25;
    if (_remainingSeconds <= 0) _remainingSeconds = minutes * 60;
    _timer?.cancel();
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _finishPomodoro();
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _remainingSeconds = (_pomodoroMinutes ?? 25) * 60;
    });
  }

  Future<void> _finishPomodoro() async {
    final done =
        await ref.read(settingsRepositoryProvider).incrementPomodoroDone();
    if (!mounted) return;
    setState(() {
      _running = false;
      _remainingSeconds = (_pomodoroMinutes ?? 25) * 60;
      _pomodoroDone = done;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('番茄钟完成，休息一下吧')));
  }

  // ---------- 编辑弹窗 ----------

  /// 编辑每日字数目标（沿用项目约定：TextFormField(initialValue:) + 局部变量）。
  Future<void> _editTarget() async {
    var input = '${_target ?? 0}';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('每日字数目标'),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '0 表示不设目标',
            suffixText: '字',
          ),
          onChanged: (v) => input = v,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(input.trim()) ?? 0),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(settingsRepositoryProvider).setDailyWordTarget(result);
    if (!mounted) return;
    setState(() => _target = result < 0 ? 0 : result);
  }

  Future<void> _editPomodoroMinutes() async {
    var input = '${_pomodoroMinutes ?? 25}';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('番茄钟时长'),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '1~120',
            suffixText: '分钟',
          ),
          onChanged: (v) => input = v,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(int.tryParse(input.trim()) ?? 25),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(settingsRepositoryProvider).setPomodoroMinutes(result);
    final minutes =
        await ref.read(settingsRepositoryProvider).pomodoroMinutes();
    if (!mounted) return;
    setState(() {
      _pomodoroMinutes = minutes;
      if (!_running) _remainingSeconds = minutes * 60;
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dailyWritingStatsProvider);
    final todayWords = stats.maybeWhen(
      data: (list) => _todayWords(list),
      orElse: () => 0,
    );
    final streak = stats.maybeWhen(
      data: (list) => writingStreak(_wordsByDay(list)),
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('写作统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _TodayCard(
            target: _target,
            words: todayWords,
            onEditTarget: _editTarget,
          ),
          const SizedBox(height: 16),
          _StatTile(
            icon: Icons.local_fire_department_outlined,
            title: '连续写作',
            value: '$streak 天',
            subtitle: streak > 0 ? '保持下去，别断更' : '今天写一点，开启连击',
          ),
          const Divider(height: 24),
          _PomodoroCard(
            running: _running,
            remainingSeconds: _remainingSeconds,
            minutes: _pomodoroMinutes ?? 25,
            done: _pomodoroDone,
            onStart: _startTimer,
            onPause: _pauseTimer,
            onReset: _resetTimer,
            onEditMinutes: _editPomodoroMinutes,
          ),
        ],
      ),
    );
  }

  int _todayWords(List<DailyWritingStat> list) {
    final key = writingDayKey(DateTime.now());
    for (final stat in list) {
      if (stat.day == key) return stat.words;
    }
    return 0;
  }

  Map<String, int> _wordsByDay(List<DailyWritingStat> list) =>
      <String, int>{for (final stat in list) stat.day: stat.words};
}

/// 今日字数与目标进度。
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.target,
    required this.words,
    required this.onEditTarget,
  });

  final int? target;
  final int words;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    final goal = target ?? 0;
    final hasGoal = goal > 0;
    final progress = hasGoal ? (words / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaperColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('今日写作', style: TextStyle(color: PaperColors.inkSoft)),
              const Spacer(),
              TextButton(
                onPressed: onEditTarget,
                child: const Text('设定目标'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: <InlineSpan>[
                TextSpan(
                  text: '$words',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: PaperColors.ink,
                  ),
                ),
                if (hasGoal)
                  TextSpan(
                    text: ' / $goal 字',
                    style: const TextStyle(color: PaperColors.inkSoft),
                  )
                else
                  const TextSpan(
                    text: ' 字',
                    style: TextStyle(color: PaperColors.inkSoft),
                  ),
              ],
            ),
          ),
          if (hasGoal) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: PaperColors.accent.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress >= 1.0 ? '已达成今日目标' : '距离目标还差 ${goal - words} 字',
              style: const TextStyle(fontSize: 12, color: PaperColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }
}

/// 番茄钟：倒计时、开始 / 暂停 / 重置、今日完成数。
class _PomodoroCard extends StatelessWidget {
  const _PomodoroCard({
    required this.running,
    required this.remainingSeconds,
    required this.minutes,
    required this.done,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onEditMinutes,
  });

  final bool running;
  final int remainingSeconds;
  final int minutes;
  final int done;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onEditMinutes;

  String get _display {
    final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.timer_outlined, color: PaperColors.inkSoft),
            const SizedBox(width: 8),
            const Text('番茄钟', style: TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            TextButton(
              onPressed: onEditMinutes,
              child: Text('$minutes 分钟'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _display,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              color: PaperColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FilledButton.icon(
              onPressed: running ? onPause : onStart,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
              label: Text(running ? '暂停' : '开始'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: const Text('重置'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '今日已完成 $done 个番茄钟',
            style: const TextStyle(fontSize: 13, color: PaperColors.inkSoft),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: PaperColors.accent),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: PaperColors.ink,
        ),
      ),
      onTap: null,
    );
  }
}