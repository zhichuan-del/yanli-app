import 'domain.dart';

/// A source record that contributed to an item in the report.
class ReportSource {
  const ReportSource({
    required this.recordId,
    required this.kind,
    required this.date,
    required this.title,
  });

  final String recordId;
  final RecordKind kind;
  final DateTime date;
  final String title;
}

class ReportItem {
  const ReportItem({required this.text, required this.sources});

  final String text;
  final List<ReportSource> sources;
}

class ReportSection {
  const ReportSection({required this.title, required this.items});

  final String title;
  final List<ReportItem> items;
}

/// An immutable report snapshot. Re-generate it after changing a source record.
class RangeReport {
  const RangeReport._({
    required this.start,
    required this.end,
    required this.generatedAt,
    required this.sections,
  });

  final DateTime start;
  final DateTime end;
  final DateTime generatedAt;
  final List<ReportSection> sections;

  static RangeReport generate({
    required Iterable<ResearchRecord> records,
    required DateTime start,
    required DateTime end,
    DateTime? generatedAt,
  }) {
    final first = dayOnly(start);
    final last = dayOnly(end);
    if (last.isBefore(first)) {
      throw ArgumentError('结束日期不能早于开始日期');
    }
    final nextWeekStart = weekStart(last).add(const Duration(days: 7));
    final nextWeekEnd = nextWeekStart.add(const Duration(days: 6));
    final ordered = records.toList()
      ..sort((a, b) {
        final byDate = dayOnly(a.date).compareTo(dayOnly(b.date));
        if (byDate != 0) return byDate;
        if (a.createdAt == null && b.createdAt != null) return -1;
        if (a.createdAt != null && b.createdAt == null) return 1;
        if (a.createdAt != null && b.createdAt != null) {
          final byCreated = a.createdAt!.compareTo(b.createdAt!);
          if (byCreated != 0) return byCreated;
        }
        return a.id.compareTo(b.id);
      });
    final byId = {for (final record in ordered) record.id: record};
    final sections = [
      _SectionBuilder('本期完成的研究工作'),
      _SectionBuilder('本期遇到的问题'),
      _SectionBuilder('导师反馈与交流结论'),
      _SectionBuilder('下一阶段工作计划'),
    ];

    for (final record in ordered) {
      final date = dayOnly(record.date);
      final inRange = !date.isBefore(first) && !date.isAfter(last);
      final beforeEnd = !date.isAfter(last);
      final inNextWeek =
          !date.isBefore(nextWeekStart) && !date.isAfter(nextWeekEnd);
      switch (record.kind) {
        case RecordKind.task:
          if (inRange && record.done && record.title.trim().isNotEmpty) {
            sections[0].add('已完成计划（任务状态）：${record.title.trim()}', record);
          }
          if (beforeEnd && !record.done && record.title.trim().isNotEmpty) {
            sections[3].add('未完成计划：${record.title.trim()}', record);
          }
          if (inNextWeek && record.title.trim().isNotEmpty) {
            sections[3].add(
              '下周计划（${record.done ? '已完成' : '未完成'}）：${record.title.trim()}',
              record,
            );
          }
        case RecordKind.progress:
          if (inRange) {
            sections[0].add(record.detail, record);
            sections[1].add(record.problem, record);
            sections[3].add(record.next, record);
          }
        case RecordKind.mentor:
          if (inRange) {
            if (record.mentorName.trim().isNotEmpty) {
              sections[2].add('导师对象：${record.mentorName.trim()}', record);
            }
            if (record.previousFollowUp.trim().isNotEmpty) {
              final previous = byId[record.previousDiscussionId];
              final text = '上次要求落实情况：${record.previousFollowUp.trim()}';
              sections[2].add(text, record);
              if (previous != null) sections[2].add(text, previous);
            }
            sections[2].add(record.detail, record);
            sections[2].add(record.problem, record);
          }
          if (beforeEnd) {
            for (final action in record.mentorActions) {
              if (!action.done) {
                sections[3].add(
                  action.status == MentorActionStatus.inProgress
                      ? '导师待办（处理中）：${action.text.trim()}'
                      : '导师待办（当前未完成）：${action.text.trim()}',
                  record,
                );
              }
            }
            // A legacy note and an action with identical wording are not
            // necessarily the same event, so retain the unknown-status note.
            final oldNext = record.next.trim();
            if (oldNext.isNotEmpty) {
              sections[3].add('导师后续（状态未记录）：$oldNext', record);
            }
          }
      }
    }
    return RangeReport._(
      start: first,
      end: last,
      generatedAt: generatedAt ?? DateTime.now(),
      sections: List.unmodifiable(sections.map((section) => section.finish())),
    );
  }

  String toMarkdown() {
    final paragraphs = <String>[
      '# 科研汇报',
      '${dateLabel(start)} - ${dateLabel(end)}',
      '生成时间：${generatedAt.toIso8601String()}',
    ];
    for (final section in sections) {
      final content = section.items.isEmpty
          ? '暂无相关记录'
          : section.items
                .map((item) {
                  final dates = item.sources
                      .map(
                        (source) => '${dateLabel(source.date)} ${source.title}',
                      )
                      .toSet()
                      .join('、');
                  return '- ${item.text}（记录日期：$dates）';
                })
                .join('\n');
      paragraphs.add('## ${section.title}\n$content');
    }
    return paragraphs.join('\n\n');
  }
}

class _SectionBuilder {
  _SectionBuilder(this.title);

  final String title;
  final Map<String, List<ReportSource>> _sourcesByText = {};

  void add(String text, ResearchRecord record) {
    final normalized = text.trim();
    if (normalized.isEmpty) return;
    final sources = _sourcesByText.putIfAbsent(normalized, () => []);
    if (!sources.any(
      (source) => source.recordId == record.id && source.kind == record.kind,
    )) {
      sources.add(
        ReportSource(
          recordId: record.id,
          kind: record.kind,
          date: dayOnly(record.date),
          title: record.title,
        ),
      );
    }
  }

  ReportSection finish() => ReportSection(
    title: title,
    items: List.unmodifiable(
      _sourcesByText.entries.map(
        (entry) => ReportItem(
          text: entry.key,
          sources: List.unmodifiable(entry.value),
        ),
      ),
    ),
  );
}
