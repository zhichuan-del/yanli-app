import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/range_report.dart';
import 'package:yanli_app/scrolling_calendar.dart';

ResearchRecord discussion() => ResearchRecord(
  id: 'discussion',
  kind: RecordKind.mentor,
  date: DateTime(2026, 11, 1),
  title: '实验讨论',
  mentorName: '王老师',
  detail: '复核实验',
  mentorActions: [MentorAction(id: 'action', text: '复核数据')],
);

void main() {
  testWidgets('月历真实密度保留类别点与所选日计数', (tester) async {
    final date = dayOnly(DateTime.now());
    final rows = [
      for (var i = 0; i < 7; i++)
        ResearchRecord(
          id: 'density-$i',
          kind: i < 5
              ? RecordKind.task
              : i == 5
              ? RecordKind.progress
              : RecordKind.mentor,
          date: date,
          title: '记录$i',
        ),
    ];
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup(rows),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    final calendar = tester.widget<ScrollingCalendar>(
      find.byType(ScrollingCalendar),
    );
    expect(calendar.recordCounts[date], 7);
    expect(find.text('7条'), findsOneWidget);
    expect(find.text('计划 5 · 进展 1 · 交流 1'), findsOneWidget);
    for (final kind in RecordKind.values) {
      expect(
        find.byKey(
          ValueKey(
            'calendar-dot-${date.year}-${date.month}-${date.day}-${kind.name}',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('过期计划移到操作日明天，完成后隐藏改期，计划可回原交流', (tester) async {
    final d = discussion();
    final now = DateTime.now();
    final task = planMentorAction(
      [d],
      d,
      d.mentorActions.single,
      now,
      now,
    ).last;
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([d, task]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    final row = find.byKey(ValueKey('record-swipe-${task.id}'));
    await tester.scrollUntilVisible(
      row,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_horiz)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移到明天'));
    await tester.pumpAndSettle();
    final moved = decodeBackup(prefs.getString('yanli_records_v1')!).last;
    expect(moved.date, DateTime(now.year, now.month, now.day + 1));
    expect(moved.id, task.id);
    expect(moved.createdAt, task.createdAt);
    // Select the moved date through the existing calendar.
    final tomorrow = moved.date;
    tester
        .widget<ScrollingCalendar>(find.byType(ScrollingCalendar))
        .onDateSelected(tomorrow);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      row,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('返回原交流'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回原交流'));
    await tester.pumpAndSettle();
    expect(find.text('记录详情'), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RecordEditor>(find.byType(RecordEditor)).record!.id,
      d.id,
    );
    await tester.tap(find.byTooltip('关闭编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(
      decodeBackup(
        prefs.getString('yanli_records_v1')!,
      ).firstWhere((r) => r.id == d.id).mentorActions.single.done,
      isTrue,
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_horiz)),
    );
    await tester.pumpAndSettle();
    expect(find.text('移到明天'), findsNothing);
    expect(find.text('移到指定日期'), findsNothing);
  });
  test('v3 来源成对校验、往返、防重复并读取 v1 v2', () {
    final d = discussion();
    final now = DateTime.utc(2026, 11, 1, 10);
    final rows = planMentorAction([d], d, d.mentorActions.single, now, now);
    final again = planMentorAction(rows, d, d.mentorActions.single, now, now);
    expect(again.length, 2);
    final task = decodeBackup(encodeBackup(again)).last;
    expect(task.sourceDiscussionId, d.id);
    expect(task.sourceMentorActionId, 'action');
    expect(task.createdAt, now);
    expect(task.copyWith(title: '改名').sourceDiscussionId, d.id);
    final v2 = jsonDecode(encodeBackup([d])) as Map<String, dynamic>;
    v2['version'] = 2;
    v2['schemaVersion'] = 2;
    expect(decodeBackup(jsonEncode(v2)).single.createdAt, isNull);
    v2['version'] = 1;
    expect(decodeBackup(jsonEncode(v2)).single.id, d.id);
    expect(
      () => ResearchRecord(
        id: 'bad',
        kind: RecordKind.task,
        date: now,
        title: 'bad',
        sourceDiscussionId: d.id,
      ),
      throwsArgumentError,
    );
    expect(() => decodeBackup(encodeBackup([task])), throwsFormatException);
    expect(
      () => decodeBackup(
        encodeBackup([
          ...rows,
          ResearchRecord(
            id: 'duplicate',
            kind: RecordKind.task,
            date: now,
            title: '重复',
            sourceDiscussionId: d.id,
            sourceMentorActionId: 'action',
          ),
        ]),
      ),
      throwsFormatException,
    );
  });

  test('撤销不覆盖较新编辑的关联，也不重复占用重新转出的来源', () {
    final d = discussion();
    final now = DateTime.utc(2026, 11, 1);
    final rows = planMentorAction([d], d, d.mentorActions.single, now, now);
    final task = rows.last;
    final deletedDiscussion = RecordDeletion(rows, d);
    final later = deletedDiscussion
        .apply(rows)
        .single
        .copyWith(title: '后续编辑', updatedAt: now.add(const Duration(hours: 1)));
    final restored = deletedDiscussion.restore([later]);
    expect(restored.first.title, '后续编辑');
    expect(restored.first.sourceDiscussionId, isNull);
    final deletedTask = RecordDeletion(rows, task);
    final replanned = planMentorAction(
      deletedTask.apply(rows),
      d,
      d.mentorActions.single,
      now,
      now.add(const Duration(hours: 2)),
    );
    final merged = deletedTask.restore(replanned);
    expect(merged.where((r) => r.sourceDiscussionId == d.id).length, 1);
    expect(decodeBackup(encodeBackup(merged)).length, 3);
  });

  test('改期保留 ID 创建时间和所有字段，完成计划拒绝改期', () {
    final d = discussion();
    final now = DateTime(2026, 12, 31, 23);
    final task = planMentorAction(
      [d],
      d,
      d.mentorActions.single,
      DateTime(2020),
      now,
    ).last.copyWith(priority: '高', plannedTime: '10:20', detail: '备注');
    final moved = rescheduleTask(
      task,
      DateTime(now.year, now.month, now.day + 1),
      now,
    );
    expect(moved.date, DateTime(2027, 1, 1));
    final expected = task.toJson()..['date'] = moved.date.toIso8601String();
    expect(moved.toJson(), expected);
    expect(
      () => rescheduleTask(task.copyWith(done: true), now, now),
      throwsStateError,
    );
  });

  test('完成双向同步，处理中重开计划，移除事项解除来源', () {
    final d = discussion();
    final now = DateTime.utc(2026, 11, 1, 12);
    var rows = planMentorAction([d], d, d.mentorActions.single, now, now);
    rows = upsertLinkedRecord(
      rows,
      rows.last.copyWith(done: true, completedAt: now, updatedAt: now),
    );
    expect(rows.first.mentorActions.single.done, isTrue);
    rows = upsertLinkedRecord(
      rows,
      rows.first.copyWith(
        mentorActions: [
          rows.first.mentorActions.single.copyWith(
            status: MentorActionStatus.inProgress,
          ),
        ],
        updatedAt: now,
      ),
    );
    final task = rows.firstWhere((r) => r.kind == RecordKind.task);
    expect(task.done, isFalse);
    expect(task.completedAt, isNull);
    final mentor = rows.firstWhere((r) => r.kind == RecordKind.mentor);
    rows = upsertLinkedRecord(rows, mentor.copyWith(mentorActions: []));
    expect(
      rows.firstWhere((r) => r.kind == RecordKind.task).sourceDiscussionId,
      isNull,
    );
  });

  test('删除清理关联，撤销合并保留后续编辑和新记录，不复活另一次删除', () {
    final d = discussion();
    final now = DateTime(2026, 11, 1);
    final task = planMentorAction(
      [d],
      d,
      d.mentorActions.single,
      now,
      now,
    ).last;
    final follow = ResearchRecord(
      id: 'follow',
      kind: RecordKind.mentor,
      date: now,
      title: '后续',
      previousDiscussionId: d.id,
    );
    final deletion = RecordDeletion([d, task, follow], d);
    final deleted = deletion.apply([d, task, follow]);
    expect(deleted.first.sourceDiscussionId, isNull);
    expect(deleted.last.previousDiscussionId, isNull);
    final newRecord = ResearchRecord(
      id: 'new',
      kind: RecordKind.progress,
      date: now,
      title: '新进展',
    );
    final restored = deletion.restore([
      deleted.first.copyWith(title: '后续改名'),
      newRecord,
    ]);
    expect(restored.map((r) => r.id), containsAll([task.id, 'new', d.id]));
    expect(restored.any((r) => r.id == follow.id), isFalse);
    expect(restored.first.title, '后续改名');
    expect(restored.first.sourceDiscussionId, d.id);
    expect(decodeBackup(encodeBackup(restored)).length, 3);
  });

  testWidgets('异常保存解除锁定、保留内容、重试 ID 和创建时间稳定', (tester) async {
    final attempts = <ResearchRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.task,
            initialDate: DateTime(2026),
            onSave: (record) async {
              attempts.add(record);
              throw StateError('write failed');
            },
          ),
        ),
      ),
    );
    expect(find.text('优先级'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '不能丢的草稿');
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('保存计划'));
      await tester.tap(find.text('保存计划'));
      await tester.pumpAndSettle();
    }
    expect(attempts.length, 2);
    expect(attempts[0].id, attempts[1].id);
    expect(attempts[0].createdAt, attempts[1].createdAt);
    expect(find.text('不能丢的草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('删除撤销写入失败后可重试，真实恢复记录', (tester) async {
    final task = ResearchRecord(
      id: 'task',
      kind: RecordKind.task,
      date: DateTime.now(),
      title: '撤销测试',
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([task]),
    });
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (value) async {
            writes++;
            return writes == 2
                ? false
                : prefs.setString('yanli_records_v1', value);
          },
        ),
      ),
    );
    final tile = find.byKey(const ValueKey('record-swipe-task'));
    await tester.scrollUntilVisible(
      tile,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: tile, matching: find.byIcon(Icons.more_horiz)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(tile, findsNothing);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(find.text('重试撤销'), findsOneWidget);
    expect(decodeBackup(prefs.getString('yanli_records_v1')!), isEmpty);
    await tester.tap(find.text('重试撤销'));
    await tester.pumpAndSettle();
    expect(
      decodeBackup(prefs.getString('yanli_records_v1')!).single.id,
      task.id,
    );
  });

  testWidgets('真实转计划防重复、返回原交流并保留编辑来源', (tester) async {
    final d = discussion();
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([d]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('转为计划'));
    await tester.tap(find.text('转为计划'));
    await tester.pumpAndSettle();
    expect(decodeBackup(prefs.getString('yanli_records_v1')!).length, 2);
    await tester.ensureVisible(find.text('查看关联计划'));
    await tester.tap(find.text('查看关联计划'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RecordEditor>(find.byType(RecordEditor))
          .record!
          .sourceDiscussionId,
      d.id,
    );
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(decodeBackup(prefs.getString('yanli_records_v1')!).length, 2);
  });

  testWidgets('周报缺项仅提示且补写打开原记录，事实导出不含提示', (tester) async {
    final d = discussion().copyWith(date: DateTime.now(), mentorActions: []);
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([d]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('周报'));
    await tester.pumpAndSettle();
    expect(find.text('缺交流结论、缺下一步'), findsOneWidget);
    await tester.ensureVisible(find.text('补写'));
    await tester.tap(find.text('补写'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RecordEditor>(find.byType(RecordEditor)).record!.id,
      d.id,
    );
    final report = RangeReport.generate(
      records: [d],
      start: weekStart(d.date),
      end: weekStart(d.date).add(const Duration(days: 6)),
      generatedAt: DateTime.now(),
    );
    expect(report.toMarkdown(), isNot(contains('缺交流结论')));
  });

  testWidgets('低动态大字键盘输入和补充分类可操作，无布局溢出', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
            viewInsets: EdgeInsets.only(bottom: 260),
          ),
          child: Scaffold(
            body: RecordEditor(
              kind: RecordKind.progress,
              initialDate: DateTime(2026),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, '键盘草稿');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.ensureVisible(find.textContaining('补充日期和分类'));
    await tester.tap(find.textContaining('补充日期和分类'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('其他活动'));
    await tester.tap(find.text('其他活动'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('保存科研进展'));
    expect(find.text('保存科研进展').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
