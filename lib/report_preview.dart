import 'package:flutter/material.dart';

import 'domain.dart' show RecordKind, dateLabel;
import 'range_report.dart';

const _ink = Color(0xff1c1c1e);
const _calendarRed = Color(0xffd93025);
const _muted = Color(0xff6c6c70);
const _noticeBackground = Color(0xfff2f2f7);

/// Displays a generated report without changing its Markdown representation.
///
/// Place this widget in a scrollable parent when its contents may exceed the
/// available height. The surrounding container supplies its own background and
/// padding.
class ReportPreview extends StatelessWidget {
  const ReportPreview({
    super.key,
    required this.report,
    required this.recordCount,
    this.onOpenSource,
  }) : assert(recordCount >= 0);

  final RangeReport report;

  /// Number of records dated within [report]'s inclusive range, including
  /// records that did not contribute an item. Items can also come from dates
  /// outside that range, so this count must not be inferred from report items.
  /// The empty state appears only when this is zero and all sections are empty.
  final int recordCount;
  final ValueChanged<ReportSource>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final hasItems = report.sections.any((section) => section.items.isNotEmpty);

    return SelectionArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text(
              '科研汇报',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${dateLabel(report.start)}  —  ${dateLabel(report.end)}',
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (recordCount == 0 && !hasItems) ...[
            const _EmptyState(),
            if (report.sections.isNotEmpty) const SizedBox(height: 22),
          ],
          for (var index = 0; index < report.sections.length; index++) ...[
            if (index > 0) const SizedBox(height: 22),
            _SectionView(
              section: report.sections[index],
              onOpenSource: onOpenSource,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _noticeBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.event_note_outlined, color: _calendarRed, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '所选日期内暂无记录',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '记录科研进展、计划或交流后，可在这里查看汇报。',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section, this.onOpenSource});

  final ReportSection section;
  final ValueChanged<ReportSource>? onOpenSource;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: _calendarRed, width: 3)),
          ),
          child: Text(
            section.title,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (section.items.isEmpty)
        const Padding(
          padding: EdgeInsets.only(left: 13),
          child: Text(
            '暂无相关记录',
            style: TextStyle(color: _muted, fontSize: 13, height: 1.6),
          ),
        )
      else
        for (var index = 0; index < section.items.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _ItemView(item: section.items[index], onOpenSource: onOpenSource),
        ],
    ],
  );
}

class _ItemView extends StatelessWidget {
  const _ItemView({required this.item, this.onOpenSource});

  final ReportItem item;
  final ValueChanged<ReportSource>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final sourceLabels = item.sources
        .map((source) => '${dateLabel(source.date)} ${source.title}')
        .toSet()
        .join('、');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 3),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _calendarRed,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.text,
                style: const TextStyle(color: _ink, fontSize: 14, height: 1.65),
              ),
              if (item.sources.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '记录日期：$sourceLabels',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (onOpenSource != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final source in item.sources)
                        TextButton(
                          onPressed: () => onOpenSource!(source),
                          child: Text(
                            '查看${switch (source.kind) {
                              RecordKind.task => '计划',
                              RecordKind.progress => '进展',
                              RecordKind.mentor => '交流',
                            }}：${source.title}',
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
