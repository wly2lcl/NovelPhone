import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/writing_stats.dart';
import '../../data/data_providers.dart';
import '../../data/db.dart';
import '../../l10n/l10n.dart';

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
    final done = await ref
        .read(settingsRepositoryProvider)
        .incrementPomodoroDone();
    if (!mounted) return;
    setState(() {
      _running = false;
      _remainingSeconds = (_pomodoroMinutes ?? 25) * 60;
      _pomodoroDone = done;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.statsPomodoroFinished)));
  }

  // ---------- 编辑弹窗 ----------

  /// 编辑每日字数目标（沿用项目约定：TextFormField(initialValue:) + 局部变量）。
  Future<void> _editTarget() async {
    var input = '${_target ?? 0}';
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.statsDailyTargetTitle),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.l10n.statsDailyTargetHint,
            suffixText: context.l10n.statsDailyTargetUnit,
          ),
          onChanged: (v) => input = v,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(input.trim()) ?? 0),
            child: Text(context.l10n.commonSave),
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
        title: Text(context.l10n.statsPomodoroDurationTitle),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.l10n.statsPomodoroDurationHint,
            suffixText: context.l10n.statsPomodoroDurationUnit,
          ),
          onChanged: (v) => input = v,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(input.trim()) ?? 25),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(settingsRepositoryProvider).setPomodoroMinutes(result);
    final minutes = await ref
        .read(settingsRepositoryProvider)
        .pomodoroMinutes();
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
      appBar: AppBar(title: Text(context.l10n.statsTitle)),
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
            title: context.l10n.statsStreakTitle,
            value: context.l10n.statsStreakDays(streak),
            subtitle: streak > 0
                ? context.l10n.statsStreakKeepGoing
                : context.l10n.statsStreakStart,
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

  Map<String, int> _wordsByDay(List<DailyWritingStat> list) => <String, int>{
    for (final stat in list) stat.day: stat.words,
  };
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
        color: context.paper.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                context.l10n.statsTodayTitle,
                style: TextStyle(color: context.paper.inkSoft),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEditTarget,
                child: Text(context.l10n.statsSetTarget),
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: context.paper.ink,
                  ),
                ),
                TextSpan(
                  text: hasGoal
                      ? context.l10n.statsWordsOfGoal(goal)
                      : context.l10n.statsWordsOnly(words),
                  style: TextStyle(color: context.paper.inkSoft),
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
                backgroundColor: context.paper.accent.withValues(alpha: 0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress >= 1.0
                  ? context.l10n.statsGoalReached
                  : context.l10n.statsGoalRemaining(goal - words),
              style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
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
            Icon(Icons.timer_outlined, color: context.paper.inkSoft),
            const SizedBox(width: 8),
            Text(
              context.l10n.statsPomodoroTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton(
              onPressed: onEditMinutes,
              child: Text(context.l10n.statsPomodoroMinutes(minutes)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _display,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              color: context.paper.ink,
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
              label: Text(
                running
                    ? context.l10n.statsPomodoroPause
                    : context.l10n.statsPomodoroStart,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonReset),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            context.l10n.statsPomodoroDoneToday(done),
            style: TextStyle(fontSize: 13, color: context.paper.inkSoft),
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
      leading: Icon(icon, color: context.paper.accent),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: context.paper.ink,
        ),
      ),
      onTap: null,
    );
  }
}
