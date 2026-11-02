import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'range_report.dart';

class ReportSummary extends StatefulWidget {
  const ReportSummary({
    super.key,
    required this.report,
    required this.prefs,
    required this.onOpenSource,
  });
  final RangeReport report;
  final SharedPreferences prefs;
  final ValueChanged<ReportSource> onOpenSource;

  @override
  State<ReportSummary> createState() => _ReportSummaryState();
}

class _ReportSummaryState extends State<ReportSummary> {
  static const titles = ['本期完成', '导师反馈与结论', '问题与待支持事项', '下一步计划'];
  static const indexes = [0, 2, 1, 3];
  final controllers = List.generate(4, (_) => TextEditingController());
  String? error;
  bool generated = false;
  bool saving = false;
  String get draftKey =>
      'report-summary-v1:${dateLabel(widget.report.start)}:${dateLabel(widget.report.end)}';

  @override
  void initState() {
    super.initState();
    final saved = widget.prefs.getStringList(draftKey);
    if (saved != null && saved.length == 4) {
      generated = true;
      for (var i = 0; i < 4; i++) {
        controllers[i].text = saved[i];
      }
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (!await widget.prefs.setStringList(
        draftKey,
        controllers.map((c) => c.text).toList(),
      )) {
        throw StateError('save failed');
      }
      if (mounted) setState(() => error = null);
    } catch (_) {
      if (mounted) setState(() => error = '总结草稿保存失败，当前文字仍保留，请重试或复制');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> generate() async {
    if (generated) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('重新生成总结？'),
          content: const Text('将用当前记录重新生成，覆盖此日期范围内已修改的总结草稿。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('重新生成'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    for (var i = 0; i < 4; i++) {
      final items = widget.report.sections[indexes[i]].items;
      controllers[i].text = items.isEmpty
          ? '暂无相关记录，建议补充。'
          : items.map((item) => '• ${item.text}').join('\n');
    }
    setState(() => generated = true);
    await save();
  }

  String get text => [
    '# 科研总结',
    '${dateLabel(widget.report.start)} — ${dateLabel(widget.report.end)}',
    for (var i = 0; i < 4; i++) '## ${titles[i]}\n${controllers[i].text}',
  ].join('\n\n');

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: saving ? null : generate,
            icon: const Icon(Icons.summarize_outlined),
            label: Text(generated ? '重新生成总结' : '生成总结'),
          ),
          if (generated)
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('总结已复制')));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('复制总结'),
            ),
          if (generated)
            TextButton(
              onPressed: saving ? null : save,
              child: Text(saving ? '正在保存…' : '保存总结草稿'),
            ),
        ],
      ),
      const Text(
        '根据已有记录整理初稿，可修改后发送；未完成事项保留原状态。',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
      if (generated) ...[
        const Text(
          '草稿按日期范围保留；修改后请保存。来源对应生成依据，手动修改内容需自行核对。',
          style: TextStyle(fontSize: 12),
        ),
        for (var i = 0; i < 4; i++) ...[
          const SizedBox(height: 14),
          TextField(
            controller: controllers[i],
            minLines: 2,
            maxLines: 8,
            decoration: InputDecoration(labelText: titles[i]),
          ),
          ExpansionTile(
            title: Text('查看${titles[i]}来源'),
            children: [
              for (final item in widget.report.sections[indexes[i]].items)
                for (final source in item.sources)
                  ListTile(
                    title: Text(source.title),
                    subtitle: Text(dateLabel(source.date)),
                    onTap: () => widget.onOpenSource(source),
                  ),
            ],
          ),
        ],
      ],
    ],
  );
}
