import 'package:flutter/material.dart';

import 'domain.dart';
import 'frosted_dropdown.dart';

/// Intersects keyword, inclusive calendar dates and category without modifying
/// the source records or their order. Empty filters match all records.
List<ResearchRecord> filterProgressRecords(
  List<ResearchRecord> records, {
  String keyword = '',
  DateTime? start,
  DateTime? end,
  String? type,
}) {
  final query = keyword.trim().toLowerCase();
  final from = start == null ? null : dayOnly(start);
  final to = end == null ? null : dayOnly(end);
  return records.where((r) {
    final date = dayOnly(r.date);
    if (from != null && date.isBefore(from)) return false;
    if (to != null && date.isAfter(to)) return false;
    if (type != null && r.progressType != type) return false;
    return query.isEmpty ||
        [
          r.title,
          r.detail,
          r.problem,
          r.next,
          r.mentorName,
          r.previousFollowUp,
          ...r.mentorActions.map((a) => a.text),
        ].any((value) => value.toLowerCase().contains(query));
  }).toList();
}

class ProgressSearch extends StatefulWidget {
  const ProgressSearch({
    super.key,
    required this.records,
    required this.recordBuilder,
    this.onCreate,
    this.mentor = false,
  });

  final List<ResearchRecord> records;
  final Widget Function(ResearchRecord) recordBuilder;

  /// Creates a first record; the empty-state button is disabled when absent.
  final VoidCallback? onCreate;
  final bool mentor;

  @override
  State<ProgressSearch> createState() => _ProgressSearchState();
}

class _ProgressSearchState extends State<ProgressSearch> {
  final search = TextEditingController();
  String? type;
  DateTime? from;
  DateTime? to;
  bool filtersOpen = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void clearFilters() {
    setState(() {
      search.clear();
      type = null;
      from = null;
      to = null;
    });
  }

  Widget emptyState({
    required IconData icon,
    required String title,
    required String description,
    required Widget action,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 31, color: colors.primary),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              action,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> chooseDate({required bool isStart}) async {
    final first = isStart ? DateTime(1900) : (from ?? DateTime(1900));
    final last = isStart
        ? (to ?? DateTime(2100, 12, 31))
        : DateTime(2100, 12, 31);
    var initial = (isStart ? from : to) ?? dayOnly(DateTime.now());
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: isStart ? '选择开始日期' : '选择结束日期',
    );
    if (selected != null && mounted) {
      setState(() {
        if (isStart) {
          from = dayOnly(selected);
        } else {
          to = dayOnly(selected);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = filterProgressRecords(
      widget.records,
      keyword: search.text,
      type: type,
      start: from,
      end: to,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      labelText: widget.mentor ? '搜索导师交流' : '搜索科研进展',
                      hintText: widget.mentor ? '主题、交流对象或跟进事项' : '标题、成果、问题或下一步',
                    ),
                  ),
                  Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TextButton.icon(
                      key: const ValueKey('search-filter-toggle'),
                      onPressed: () => setState(() => filtersOpen = !filtersOpen),
                      icon: const Icon(Icons.tune), label: const Text('筛选'),
                    ),
                    if (search.text.isNotEmpty || type != null || from != null || to != null)
                      TextButton(onPressed: clearFilters, child: const Text('清除筛选')),
                  ]),
                  if (type != null || from != null || to != null) Wrap(spacing: 6, runSpacing: 4, children: [
                    if (type != null) InputChip(label: Text('类型：$type'), onDeleted: () => setState(() => type = null)),
                    if (from != null) InputChip(label: Text('从 ${dateLabel(from!)}'), onDeleted: () => setState(() => from = null)),
                    if (to != null) InputChip(label: Text('至 ${dateLabel(to!)}'), onDeleted: () => setState(() => to = null)),
                  ]),
                  if (filtersOpen) FrostedMenuSurface(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (!widget.mentor)
                  FrostedDropdown<String>(
                    key: ValueKey(type),
                    initialValue: type ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '科研类型'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('全部类型')),
                      ...researchTypes.map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => type = value == '' ? null : value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => chooseDate(isStart: true),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(from == null ? '开始日期' : dateLabel(from!)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => chooseDate(isStart: false),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(to == null ? '结束日期' : dateLabel(to!)),
                      ),
                    ],
                  ),
                  ],))),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Text(
            '筛选结果 · ${results.length} 条',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (widget.records.isEmpty)
          emptyState(
            icon: Icons.menu_book_outlined,
            title: widget.mentor ? '还没有交流记录' : '还没有科研进展',
            description: '点击新建开始记录',
            action: FilledButton.icon(
              onPressed: widget.onCreate == null
                  ? null
                  : () {
                      clearFilters();
                      widget.onCreate!();
                    },
              icon: const Icon(Icons.add, size: 18),
              label: Text(widget.mentor ? '记录第一条交流' : '记录第一条进展'),
            ),
          )
        else if (results.isEmpty)
          emptyState(
            icon: Icons.search_off,
            title: widget.mentor ? '没有符合条件的导师交流' : '没有符合条件的科研进展',
            description: '试试调整筛选条件，或清除筛选查看全部进展',
            action: OutlinedButton.icon(
              onPressed: clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('清除筛选条件'),
            ),
          )
        else
          ...results.map(widget.recordBuilder),
      ],
    );
  }
}
