import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/range_report.dart';

ResearchRecord record(
  String id,
  RecordKind kind,
  String date,
  String title, {
  String detail = '',
  String problem = '',
  String next = '',
  bool done = false,
}) => ResearchRecord(
  id: id,
  kind: kind,
  date: DateTime.parse(date),
  title: title,
  detail: detail,
  problem: problem,
  next: next,
  done: done,
);

void main() {
  test('范围含首尾日期，跨年并拒绝倒置日期', () {
    final records = [
      record(
        'outside',
        RecordKind.progress,
        '2025-12-30',
        '以前',
        detail: '无关成果',
      ),
      record('first', RecordKind.progress, '2025-12-31', 'A', detail: '第一天'),
      record('last', RecordKind.progress, '2026-01-01', 'B', detail: '最后一天'),
      record('after', RecordKind.progress, '2026-01-02', '以后', detail: '无关成果'),
    ];
    final report = RangeReport.generate(
      records: records,
      start: DateTime(2025, 12, 31),
      end: DateTime(2026, 1, 1),
    );
    expect(
      report.sections[0].items.expand((e) => e.sources).map((s) => s.recordId),
      ['first', 'last'],
    );
    expect(
      () => RangeReport.generate(
        records: [],
        start: DateTime(2026, 1, 2),
        end: DateTime(2026, 1, 1),
      ),
      throwsArgumentError,
    );
    expect(report.toMarkdown(), contains('2025.12.31 - 2026.01.01'));
  });

  test('四章按已有事实输出，不把完成计划当作科研成果', () {
    final records = [
      record('plan', RecordKind.task, '2026-10-28', '阅读文献', done: true),
      record(
        'p',
        RecordKind.progress,
        '2026-10-29',
        '进展',
        detail: '阅读了两篇文献',
        problem: '实验受阻',
        next: '核对方法',
      ),
      record(
        'm',
        RecordKind.mentor,
        '2026-10-29',
        '课题沟通',
        detail: '建议补充对照',
        problem: '下周复核',
        next: '整理资料',
      ),
    ];
    final report = RangeReport.generate(
      records: records,
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    expect(report.sections, hasLength(4));
    expect(
      report.sections[0].items.map((e) => e.text),
      contains('已完成计划（任务状态）：阅读文献'),
    );
    expect(report.sections[0].items.map((e) => e.text), contains('阅读了两篇文献'));
    expect(report.sections[1].items.single.text, '实验受阻');
    expect(
      report.sections[2].items.map((e) => e.text),
      containsAll(['建议补充对照', '下周复核']),
    );
    expect(report.sections[3].items.map((e) => e.text), contains('核对方法'));
    expect(
      report.sections[3].items.map((e) => e.text),
      contains('导师后续（状态未记录）：整理资料'),
    );
  });

  test('同章内容去掉首尾空白后完全去重，保留全部来源，不合并不同内容', () {
    final records = [
      record(
        'b',
        RecordKind.progress,
        '2026-10-29',
        '不同标题1',
        detail: ' 同一成果  ',
      ),
      record('a', RecordKind.progress, '2026-10-28', '不同标题2', detail: '同一成果'),
      record('c', RecordKind.progress, '2026-10-30', '第三项', detail: '同一成果（补充）'),
      record('empty', RecordKind.progress, '2026-10-30', '第四项', detail: '  '),
    ];
    final report = RangeReport.generate(
      records: records,
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    final entries = report.sections[0].items;
    expect(entries, hasLength(2));
    expect(entries.first.text, '同一成果');
    expect(entries.first.sources.map((s) => s.recordId), ['a', 'b']);
    expect(entries.first.sources.map((s) => s.kind), [
      RecordKind.progress,
      RecordKind.progress,
    ]);
    expect(entries.first.sources.map((s) => s.date), [
      DateTime(2026, 10, 28),
      DateTime(2026, 10, 29),
    ]);
  });

  test('下一步含截止日未完成计划及下一自然周已安排计划，忽略过期已完成计划', () {
    final records = [
      record('old', RecordKind.task, '2026-10-01', '历史未完成'),
      record('done', RecordKind.task, '2026-10-01', '历史已完成', done: true),
      record('next', RecordKind.task, '2026-11-02', '下周安排'),
      record('outside', RecordKind.task, '2026-11-09', '两周后'),
      record('mentor', RecordKind.mentor, '2026-10-01', '旧交流', next: '确认方案'),
    ];
    final report = RangeReport.generate(
      records: records,
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    final texts = report.sections[3].items.map((e) => e.text).toList();
    expect(texts, contains('未完成计划：历史未完成'));
    expect(texts, contains('下周计划（未完成）：下周安排'));
    expect(texts, contains('导师后续（状态未记录）：确认方案'));
    expect(texts.join(), isNot(contains('历史已完成')));
    expect(texts.join(), isNot(contains('两周后')));
  });

  test('空章节显示暂无相关记录，Markdown 保留中文换行和范围', () {
    final report = RangeReport.generate(
      records: [],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    expect(report.sections.every((s) => s.items.isEmpty), true);
    expect('暂无相关记录'.allMatches(report.toMarkdown()), hasLength(4));
    expect(report.toMarkdown(), contains('2026.10.26 - 2026.11.01'));
  });
  test('导师对象、上次落实及未完成事项进汇报，已完成事项不出现在下一步', () {
    final mentor = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '课题讨论',
      mentorName: '王老师',
      previousFollowUp: '已补充对照',
      next: '旧跟进',
      mentorActions: [
        MentorAction(id: 'a', text: '补做实验'),
        MentorAction(id: 'b', text: '已整理材料', done: true),
      ],
    );
    final report = RangeReport.generate(
      records: [mentor],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    final discussions = report.sections[2].items;
    final upcoming = report.sections[3].items;
    expect(discussions.map((x) => x.text), contains('导师对象：王老师'));
    expect(discussions.map((x) => x.text), contains('上次要求落实情况：已补充对照'));
    expect(upcoming.map((x) => x.text), contains('导师待办（当前未完成）：补做实验'));
    expect(upcoming.map((x) => x.text), contains('导师后续（状态未记录）：旧跟进'));
    expect(upcoming.map((x) => x.text).join(), isNot(contains('已整理材料')));
    expect(
      upcoming
          .firstWhere((x) => x.text.contains('补做实验'))
          .sources
          .single
          .recordId,
      'm',
    );
  });

  test('相同文字没有关联依据，旧状态未知事项和明确待办均保留', () {
    final mentor = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '交流',
      next: ' 补实验 ',
      mentorActions: [MentorAction(id: 'todo', text: '补实验')],
    );
    final report = RangeReport.generate(
      records: [mentor],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    final items = report.sections[3].items.map((x) => x.text).toList();
    expect(items, containsAll(['导师待办（当前未完成）：补实验', '导师后续（状态未记录）：补实验']));
  });
  test('同文字待办已完成时，旧状态未知备注仍保留', () {
    final mentor = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '交流',
      next: '补实验',
      mentorActions: [MentorAction(id: 'todo', text: '补实验', done: true)],
    );
    final report = RangeReport.generate(
      records: [mentor],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    expect(report.sections[3].items.map((item) => item.text), [
      '导师后续（状态未记录）：补实验',
    ]);
  });
}
