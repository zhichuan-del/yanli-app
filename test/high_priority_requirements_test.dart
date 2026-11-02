import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/range_report.dart';

void main() {
  test('版本 2 备份保留三态及跨次交流关联并兼容版本 1', () {
    const legacy =
        '{"version":1,"records":[{"id":"old","kind":"mentor","date":"2026-10-01T00:00:00.000","title":"旧交流","mentorActions":[{"id":"a","text":"整理数据","done":false},{"id":"b","text":"阅读文献","done":true}]}]}';
    final old = decodeBackup(legacy).single;
    expect(old.mentorActions.map((a) => a.status), [
      MentorActionStatus.pending,
      MentorActionStatus.completed,
    ]);
    final current = ResearchRecord(
      id: 'new',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 10),
      title: '新交流',
      mentorName: '张老师',
      detail: '补充分析',
      previousDiscussionId: old.id,
      createdAt: DateTime.utc(2026, 10, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 10, 2),
      mentorActions: [
        MentorAction(
          id: 'c',
          text: '完成分析',
          status: MentorActionStatus.inProgress,
        ),
      ],
    );
    final backup = encodeBackup([old, current]);
    final json = jsonDecode(backup) as Map<String, dynamic>;
    expect(json['version'], 3);
    expect(json['schemaVersion'], 3);
    expect(DateTime.tryParse(json['exportedAt'] as String), isNotNull);
    expect(json['settings'], isA<Map>());
    final restored = decodeBackup(backup).last;
    expect(restored.previousDiscussionId, 'old');
    expect(restored.mentorActions.single.status, MentorActionStatus.inProgress);
    expect(restored.createdAt, current.createdAt);
    expect(restored.updatedAt, current.updatedAt);
  });

  test('不支持的备份设置不会被静默丢弃', () {
    final data = jsonDecode(encodeBackup([])) as Map<String, dynamic>;
    data['settings'] = {'futureSetting': true};
    expect(() => decodeBackup(jsonEncode(data)), throwsFormatException);
  });

  test('备份拒绝缺失、循环、时间倒置的交流关联', () {
    ResearchRecord meeting(String id, String? previous, DateTime date) =>
        ResearchRecord(
          id: id,
          kind: RecordKind.mentor,
          date: date,
          title: id,
          previousDiscussionId: previous,
        );
    expect(
      () =>
          decodeBackup(encodeBackup([meeting('a', 'missing', DateTime(2026))])),
      throwsFormatException,
    );
    expect(
      () => decodeBackup(
        encodeBackup([
          meeting('a', 'b', DateTime(2026)),
          meeting('b', 'a', DateTime(2026)),
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => decodeBackup(
        encodeBackup([
          meeting('a', null, DateTime(2026, 10, 10)),
          meeting('b', 'a', DateTime(2026, 10, 1)),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('汇报包含生成时间并保留处理中事项', () {
    final generated = DateTime(2026, 10, 30, 12, 34);
    final report = RangeReport.generate(
      records: [
        ResearchRecord(
          id: 'm',
          kind: RecordKind.mentor,
          date: DateTime(2026, 10, 29),
          title: '讨论',
          mentorActions: [
            MentorAction(
              id: 'a',
              text: '处理数据',
              status: MentorActionStatus.inProgress,
            ),
          ],
        ),
      ],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
      generatedAt: generated,
    );
    expect(report.toMarkdown(), contains('生成时间：2026-10-30T12:34:00.000'));
    expect(report.toMarkdown(), contains('导师待办（处理中）：处理数据'));
  });

  test('上次落实情况保留本次及关联上次交流的来源', () {
    final old = ResearchRecord(
      id: 'old',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 1),
      title: '上次交流',
      detail: '核实数据',
    );
    final current = ResearchRecord(
      id: 'new',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '本次交流',
      previousDiscussionId: 'old',
      previousFollowUp: '已核实',
    );
    final report = RangeReport.generate(
      records: [old, current],
      start: DateTime(2026, 10, 26),
      end: DateTime(2026, 11, 1),
    );
    final item = report.sections[2].items.singleWhere(
      (item) => item.text == '上次要求落实情况：已核实',
    );
    expect(item.sources.map((source) => source.recordId), ['new', 'old']);
  });

  testWidgets('汇报条目可直接打开对应来源记录', (tester) async {
    final now = dayOnly(DateTime.now());
    final record = ResearchRecord(
      id: 'progress',
      kind: RecordKind.progress,
      date: now,
      title: '来源进展',
      detail: '完成实验',
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('周报'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('查看进展：来源进展'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看进展：来源进展'));
    await tester.pumpAndSettle();
    expect(find.text('记录详情'), findsOneWidget);
    expect(find.byType(RecordEditor), findsNothing);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑科研进展'), findsOneWidget);
    expect(find.descendant(of: find.byType(RecordEditor), matching: find.text('来源进展')), findsOneWidget);
  });

  testWidgets('新建交流必须填写对象及建议、结论或事项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.mentor,
            initialDate: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '组会讨论');
    await tester.ensureVisible(find.text('保存导师交流'));
    await tester.tap(find.text('保存导师交流'));
    await tester.pumpAndSettle();
    expect(find.text('请填写交流对象'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    final name = find.widgetWithText(TextField, '交流对象 *');
    await tester.ensureVisible(name);
    await tester.enterText(name, '王老师');
    await tester.ensureVisible(find.text('保存导师交流'));
    await tester.tap(find.text('保存导师交流'));
    await tester.pumpAndSettle();
    expect(find.text('请至少填写建议、结论或一项后续事项'), findsOneWidget);
  });

  testWidgets('新交流可关联并回看上次事项', (tester) async {
    final previous = ResearchRecord(
      id: 'old',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 1),
      title: '上次讨论',
      mentorName: '王老师',
      detail: '完善实验',
      mentorActions: [MentorAction(id: 'a', text: '检查数据')],
    );
    ResearchRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.mentor,
            initialDate: DateTime(2026, 10, 10),
            previousDiscussions: [previous],
            onSave: (record) async {
              saved = record;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '本次讨论');
    await tester.enterText(
      find.widgetWithText(TextField, '导师反馈 / 交流内容'),
      '继续完善',
    );
    final name = find.widgetWithText(TextField, '交流对象 *');
    await tester.ensureVisible(name);
    await tester.enterText(name, '王老师');
    final previousPicker = find.text('不关联');
    await tester.ensureVisible(previousPicker);
    await tester.pumpAndSettle();
    await tester.tap(previousPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026.10.01 · 上次讨论').last);
    await tester.pumpAndSettle();
    expect(find.text('上次事项：检查数据 · 未处理'), findsOneWidget);
    await tester.ensureVisible(find.text('保存导师交流'));
    await tester.tap(find.text('保存导师交流'));
    await tester.pumpAndSettle();
    expect(saved?.previousDiscussionId, 'old');
  });

  testWidgets('交流跟进可以改成处理中并再次读取', (tester) async {
    final record = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '课题讨论',
      mentorName: '李老师',
      detail: '后续安排',
      mentorActions: [MentorAction(id: 'a', text: '复核数据')],
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    final status = find.byType(MentorStatusPicker);
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(status);
    await tester.pumpAndSettle();
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('处理中').last);
    await tester.pumpAndSettle();
    expect(
      decodeBackup(
        prefs.getString('yanli_records_v1')!,
      ).single.mentorActions.single.status,
      MentorActionStatus.inProgress,
    );
  });

  testWidgets('日历默认月视图，所选日期可新建三类记录', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    expect(find.byTooltip('收起月历'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('新建进展'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('新建计划', skipOffstage: false), findsOneWidget);
    expect(find.text('新建交流', skipOffstage: false), findsOneWidget);
    await tester.ensureVisible(find.text('新建进展'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建进展'));
    await tester.pumpAndSettle();
    expect(find.text('新建科研进展'), findsOneWidget);
  });
}
