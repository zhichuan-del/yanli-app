import 'package:flutter/material.dart';
import 'domain.dart';

class RecordDetails extends StatelessWidget {
  const RecordDetails({super.key, required this.recordId, required this.lookup,
    required this.revision, required this.onEdit, required this.onOpenSource});
  final String recordId;
  final ResearchRecord? Function(String) lookup;
  final Listenable revision;
  final Future<void> Function(ResearchRecord) onEdit;
  final Future<void> Function(ResearchRecord) onOpenSource;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: revision,
    builder: (context, _) {
      final r = lookup(recordId);
      Widget field(String label, String value) => value.isEmpty
          ? const SizedBox.shrink()
          : Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6), SelectableText(value),
              ]));
      Widget source(String label, String? id) {
        final linked = id == null ? null : lookup(id);
        return id == null ? const SizedBox.shrink() : ListTile(
          contentPadding: EdgeInsets.zero, title: Text(label),
          subtitle: Text(linked?.title ?? '来源记录已删除'),
          trailing: linked == null ? null : const Icon(Icons.chevron_right),
          onTap: linked == null ? null : () => onOpenSource(linked),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('记录详情'), actions: [
          if (r != null) TextButton(onPressed: () => onEdit(r), child: const Text('编辑')),
        ]),
        body: r == null ? const Center(child: Text('记录已删除，可返回列表或到回收站恢复'))
          : ListView(key: PageStorageKey('details-$recordId'), padding: const EdgeInsets.all(22), children: [
            SelectableText(r.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            field('日期', dateLabel(r.date)),
            field('记录类型', switch(r.kind) {RecordKind.task => '计划', RecordKind.progress => '科研进展', RecordKind.mentor => '导师交流'}),
            if (r.kind == RecordKind.task) ...[
              field('状态', r.done ? '已完成' : '未完成'), field('优先级', r.priority),
              field('计划时间', r.plannedTime ?? ''),
            ],
            if (r.kind == RecordKind.progress) ...[
              field('科研类型', r.progressType), field('投入时间', r.durationMinutes == null ? '' : '${r.durationMinutes} 分钟'),
            ],
            field(r.kind == RecordKind.mentor ? '导师反馈 / 交流内容' : '内容', r.detail),
            field(r.kind == RecordKind.mentor ? '交流结论' : '遇到的问题', r.problem),
            field('下一步', r.next), field('交流对象', r.mentorName),
            field('上次要求落实情况', r.previousFollowUp),
            field('下次交流日期', r.nextMeetingDate == null ? '' : dateLabel(r.nextMeetingDate!)),
            for (final a in r.mentorActions) field('跟进事项 · ${a.status.label}', a.text),
            source('上次交流', r.previousDiscussionId), source('原交流', r.sourceDiscussionId),
            if (r.sourceMentorActionId != null) field('来源事项', lookup(r.sourceDiscussionId!)?.mentorActions.where((a) => a.id == r.sourceMentorActionId).firstOrNull?.text ?? '来源事项已移除'),
            field('创建时间', r.createdAt?.toLocal().toString() ?? '未记录'),
            field('更新时间', r.updatedAt?.toLocal().toString() ?? '未记录'),
            field('完成时间', r.completedAt?.toLocal().toString() ?? ''),
          ]),
      );
    },
  );
}