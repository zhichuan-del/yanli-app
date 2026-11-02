import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/range_report.dart';
import 'package:yanli_app/report_preview.dart';

final _start = DateTime(2026, 10, 26);
final _end = DateTime(2026, 11, 1);

RangeReport _report(List<ResearchRecord> records) =>
    RangeReport.generate(records: records, start: _start, end: _end);

Future<void> _pumpPreview(
  WidgetTester tester,
  RangeReport report, {
  required int recordCount,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ReportPreview(report: report, recordCount: recordCount),
          ),
        ),
      ),
    ),
  );
}

List<String> _previewTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(ReportPreview),
        matching: find.byType(Text),
      ),
    )
    .map((widget) => widget.data!)
    .toList();

void _expectInOrder(List<String> actual, Iterable<String> expected) {
  var start = 0;
  for (final text in expected) {
    final index = actual.indexOf(text, start);
    expect(index, isNot(-1), reason: 'Missing or out-of-order text: $text');
    start = index + 1;
  }
}

void main() {
  testWidgets('混合汇报按章节和事项原顺序展示内容及来源，不显示 Markdown 标记', (tester) async {
    final report = _report([
      ResearchRecord(
        id: 'done',
        kind: RecordKind.task,
        date: DateTime(2026, 10, 26),
        title: '阅读论文',
        done: true,
      ),
      ResearchRecord(
        id: 'progress-a',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 28),
        title: '进展甲',
        detail: '已完成对照实验',
        problem: '信号不稳定',
        next: '重新校准仪器',
      ),
      ResearchRecord(
        id: 'progress-b',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 29),
        title: '进展乙',
        detail: '已完成对照实验',
      ),
      ResearchRecord(
        id: 'mentor',
        kind: RecordKind.mentor,
        date: DateTime(2026, 10, 30),
        title: '组会讨论',
        mentorName: '王老师',
        previousFollowUp: '已补充材料',
        detail: '建议增加对照',
        problem: '样本不足',
        next: '核查结果',
        mentorActions: [
          MentorAction(id: 'open', text: '补充实验'),
          MentorAction(id: 'done', text: '不应出现的已完成待办', done: true),
        ],
      ),
      ResearchRecord(
        id: 'old-task',
        kind: RecordKind.task,
        date: DateTime(2026, 10, 25),
        title: '历史计划',
      ),
      ResearchRecord(
        id: 'next-task',
        kind: RecordKind.task,
        date: DateTime(2026, 11, 2),
        title: '下周复核',
      ),
    ]);
    final markdown = report.toMarkdown();

    await _pumpPreview(tester, report, recordCount: 4);

    final texts = _previewTexts(tester);
    _expectInOrder(texts, [
      '科研汇报',
      '2026.10.26  —  2026.11.01',
      '本期完成的研究工作',
      '已完成计划（任务状态）：阅读论文',
      '记录日期：2026.10.26 阅读论文',
      '已完成对照实验',
      '记录日期：2026.10.28 进展甲、2026.10.29 进展乙',
      '本期遇到的问题',
      '信号不稳定',
      '导师反馈与交流结论',
      '导师对象：王老师',
      '上次要求落实情况：已补充材料',
      '建议增加对照',
      '样本不足',
      '下一阶段工作计划',
      '未完成计划：历史计划',
      '重新校准仪器',
      '导师待办（当前未完成）：补充实验',
      '导师后续（状态未记录）：核查结果',
      '下周计划（未完成）：下周复核',
    ]);
    for (final section in report.sections) {
      expect(find.text(section.title), findsOneWidget);
      for (final item in section.items) {
        expect(find.text(item.text), findsOneWidget);
      }
    }
    expect(find.text('记录日期：2026.10.28 进展甲、2026.10.29 进展乙'), findsOneWidget);
    expect(find.text('所选日期内暂无记录'), findsNothing);
    expect(texts.join('\n'), isNot(contains('不应出现的已完成待办')));
    final markdownMarker = RegExp(r'^\s*(?:#{1,6}\s|[-*+]\s)');
    expect(texts.where(markdownMarker.hasMatch), isEmpty);
    expect(markdown, contains('## 本期完成的研究工作'));
    expect(markdown, contains('- 已完成对照实验'));
    expect(report.toMarkdown(), markdown);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同一天同名来源在预览中与 Markdown 一致地去重', (tester) async {
    final report = _report([
      ResearchRecord(
        id: 'one',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 28),
        title: '相同来源',
        detail: '相同成果',
      ),
      ResearchRecord(
        id: 'two',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 28),
        title: '相同来源',
        detail: '相同成果',
      ),
    ]);
    await _pumpPreview(tester, report, recordCount: 2);
    expect(find.text('记录日期：2026.10.28 相同来源'), findsOneWidget);
    expect(report.toMarkdown(), contains('相同成果（记录日期：2026.10.28 相同来源）'));
  });

  testWidgets('没有记录也没有事项时显示友好提示并保留空章节', (tester) async {
    final report = _report([]);
    await _pumpPreview(tester, report, recordCount: 0);

    expect(find.text('所选日期内暂无记录'), findsOneWidget);
    expect(find.text('记录科研进展、计划或交流后，可在这里查看汇报。'), findsOneWidget);
    expect(find.text('暂无相关记录'), findsNWidgets(report.sections.length));
    _expectInOrder(_previewTexts(tester), [
      for (final section in report.sections) ...[section.title, '暂无相关记录'],
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期范围内无记录时仍展示跨期的历史及下周事项', (tester) async {
    final report = _report([
      ResearchRecord(
        id: 'old-mentor',
        kind: RecordKind.mentor,
        date: DateTime(2026, 10, 24),
        title: '旧交流',
        next: '复核方案',
      ),
      ResearchRecord(
        id: 'old-task',
        kind: RecordKind.task,
        date: DateTime(2026, 10, 25),
        title: '历史任务',
      ),
      ResearchRecord(
        id: 'next-task',
        kind: RecordKind.task,
        date: DateTime(2026, 11, 2),
        title: '下周任务',
        done: true,
      ),
      ResearchRecord(
        id: 'mentor-action',
        kind: RecordKind.mentor,
        date: DateTime(2026, 10, 23),
        title: '旧事项',
        mentorActions: [MentorAction(id: 'follow-up', text: '跟进数据')],
      ),
    ]);
    await _pumpPreview(tester, report, recordCount: 0);

    expect(find.text('所选日期内暂无记录'), findsNothing);
    expect(find.text('记录科研进展、计划或交流后，可在这里查看汇报。'), findsNothing);
    _expectInOrder(_previewTexts(tester), [
      report.sections[3].title,
      '导师待办（当前未完成）：跟进数据',
      '导师后续（状态未记录）：复核方案',
      '未完成计划：历史任务',
      '下周计划（已完成）：下周任务',
    ]);
    expect(find.text('记录日期：2026.10.23 旧事项'), findsOneWidget);
    expect(find.text('记录日期：2026.10.24 旧交流'), findsOneWidget);
    expect(find.text('记录日期：2026.10.25 历史任务'), findsOneWidget);
    expect(find.text('记录日期：2026.11.02 下周任务'), findsOneWidget);
    expect(find.text('暂无相关记录'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('范围内有记录但没有生成事项时不误报零记录', (tester) async {
    final report = _report([
      ResearchRecord(
        id: 'empty-progress',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 28),
        title: '只有标题的记录',
      ),
    ]);
    await _pumpPreview(tester, report, recordCount: 1);

    expect(find.text('所选日期内暂无记录'), findsNothing);
    expect(find.text('暂无相关记录'), findsNWidgets(report.sections.length));
    for (final section in report.sections) {
      expect(find.text(section.title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏大字体下长文本与用户输入的符号完整换行并可滚动', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final longItem = '## 用户原文：${'科研记录' * 100}\n- 保留输入的符号';
    final longTitle = '长期科研项目' * 60;
    final report = _report([
      ResearchRecord(
        id: 'long',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 28),
        title: longTitle,
        detail: longItem,
      ),
    ]);
    await _pumpPreview(tester, report, recordCount: 1, textScale: 1.8);

    final itemFinder = find.text(longItem);
    final sourceFinder = find.text('记录日期：2026.10.28 $longTitle');
    expect(itemFinder, findsOneWidget);
    expect(sourceFinder, findsOneWidget);
    final itemText = tester.widget<Text>(itemFinder);
    expect(itemText.maxLines, isNull);
    expect(itemText.overflow, isNull);
    expect(itemText.softWrap, isNot(false));
    expect(tester.getSize(itemFinder).height, greaterThan(100));
    expect(tester.getSize(sourceFinder).height, greaterThan(100));
    expect(tester.takeException(), isNull);

    final lastSection = find.text('下一阶段工作计划');
    await tester.ensureVisible(lastSection);
    await tester.pumpAndSettle();
    expect(tester.getRect(lastSection).bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });
}
