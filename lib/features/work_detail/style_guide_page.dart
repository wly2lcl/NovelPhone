import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../data/data_providers.dart';
import '../../l10n/l10n.dart';
import '../../models/work_style_guide.dart';
import '../ai/ai_providers.dart';
import '../ai/ai_service.dart';

/// 作品文风档案（ENH-23）：手动编辑 + AI 从最近章节提取。
class StyleGuidePage extends ConsumerStatefulWidget {
  const StyleGuidePage({super.key, required this.workId});

  final int workId;

  @override
  ConsumerState<StyleGuidePage> createState() => _StyleGuidePageState();
}

class _StyleGuidePageState extends ConsumerState<StyleGuidePage> {
  final _perspective = TextEditingController();
  final _tone = TextEditingController();
  final _taboos = TextEditingController();
  final _sample = TextEditingController();
  bool _loading = true;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _perspective.dispose();
    _tone.dispose();
    _taboos.dispose();
    _sample.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final work = await ref.read(workRepositoryProvider).getWork(widget.workId);
    if (!mounted) return;
    final guide = WorkStyleGuide.decode(work?.styleGuide ?? '');
    _perspective.text = guide.perspective;
    _tone.text = guide.tone;
    _taboos.text = guide.taboos;
    _sample.text = guide.sample;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    await ref
        .read(workRepositoryProvider)
        .updateStyleGuide(
          widget.workId,
          WorkStyleGuide(
            perspective: _perspective.text.trim(),
            tone: _tone.text.trim(),
            taboos: _taboos.text.trim(),
            sample: _sample.text.trim(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.styleGuideSaved)));
  }

  Future<void> _extract() async {
    final l10n = context.l10n;
    final ready = await ref.read(aiServiceProvider).isReady('style');
    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiPanelNeedsConfig),
          action: SnackBarAction(
            label: l10n.editorGoSettings,
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
      return;
    }
    setState(() => _extracting = true);
    try {
      final result = await ref
          .read(aiServiceProvider)
          .extractStyleGuide(workId: widget.workId);
      if (!mounted) return;
      final apply = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.styleGuideExtractTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(l10n.styleGuideExtractConfirm),
                const SizedBox(height: 12),
                _PreviewRow(
                  label: l10n.styleGuidePerspective,
                  value: result.guide.perspective,
                ),
                _PreviewRow(
                  label: l10n.styleGuideTone,
                  value: result.guide.tone,
                ),
                _PreviewRow(
                  label: l10n.styleGuideTaboos,
                  value: result.guide.taboos,
                ),
                _PreviewRow(
                  label: l10n.styleGuideSample,
                  value: result.guide.sample,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.styleGuideApply),
            ),
          ],
        ),
      );
      if (apply == true && mounted) {
        setState(() {
          if (result.guide.perspective.trim().isNotEmpty) {
            _perspective.text = result.guide.perspective;
          }
          if (result.guide.tone.trim().isNotEmpty) {
            _tone.text = result.guide.tone;
          }
          if (result.guide.taboos.trim().isNotEmpty) {
            _taboos.text = result.guide.taboos;
          }
          if (result.guide.sample.trim().isNotEmpty) {
            _sample.text = result.guide.sample;
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.styleGuideApplied)));
      }
    } on AiServiceNeedsConfig {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.aiPanelNeedsConfig),
          action: SnackBarAction(
            label: l10n.editorGoSettings,
            onPressed: () => context.push('/settings'),
          ),
        ),
      );
    } on AiServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.styleGuideExtractFailed(e.message))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.styleGuideExtractFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.styleGuideTitle),
        actions: <Widget>[
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                Text(
                  l10n.styleGuideIntro,
                  style: TextStyle(color: context.paper.inkSoft, height: 1.5),
                ),
                const SizedBox(height: 16),
                _Field(
                  controller: _perspective,
                  label: l10n.styleGuidePerspective,
                  hint: l10n.styleGuidePerspectiveHint,
                  maxLines: 2,
                ),
                _Field(
                  controller: _tone,
                  label: l10n.styleGuideTone,
                  hint: l10n.styleGuideToneHint,
                  maxLines: 3,
                ),
                _Field(
                  controller: _taboos,
                  label: l10n.styleGuideTaboos,
                  hint: l10n.styleGuideTaboosHint,
                  maxLines: 3,
                ),
                _Field(
                  controller: _sample,
                  label: l10n.styleGuideSample,
                  hint: l10n.styleGuideSampleHint,
                  maxLines: 8,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _extracting ? null : _extract,
                  icon: _extracting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    _extracting
                        ? l10n.styleGuideExtracting
                        : l10n.styleGuideExtract,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        minLines: 1,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.paper.inkSoft),
          ),
          const SizedBox(height: 2),
          Text(value.trim().isEmpty ? '—' : value.trim()),
        ],
      ),
    );
  }
}
