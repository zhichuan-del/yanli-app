import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/recycle_bin.dart';
import 'package:yanli_app/scrolling_calendar.dart';

const storageKey = 'yanli_records_v1';

ResearchRecord mentor({
  MentorActionStatus status = MentorActionStatus.pending,
}) => ResearchRecord(
  id: 'mentor',
  kind: RecordKind.mentor,
  date: dayOnly(DateTime.now()),
  title: '课题交流',
  mentorActions: [MentorAction(id: 'action', text: '整理文献', status: status)],
);

ResearchRecord linkedPlan(ResearchRecord source) => planMentorAction(
  [source],
  source,
  source.mentorActions.single,
  DateTime.now(),
  DateTime.now(),
).last;

Future<SharedPreferences> start(
  WidgetTester tester,
  List<ResearchRecord> records, {
  Future<bool> Function(String)? write,
}) async {
  SharedPreferences.setMockInitialValues({storageKey: encodeBackup(records)});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    write == null
        ? YanliApp(prefs: prefs)
        : MaterialApp(
            home: HomePage(prefs: prefs, writeSnapshot: write),
          ),
  );
  await tester.pumpAndSettle();
  return prefs;
}

Future<void> openMentorAction(WidgetTester tester) async {
  await tester.tap(find.text('交流'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('交流详情与跟进').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('转为计划'));
  await tester.tap(find.text('转为计划'));
  await tester.pumpAndSettle();
}

Future<void> openDelete(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('record-swipe-$id'));
  if (find
      .byKey(const ValueKey('calendar-agenda-list'))
      .evaluate()
      .isNotEmpty) {
    await tester.scrollUntilVisible(
      row,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
  } else {
    await tester.ensureVisible(row);
  }
  await tester.pumpAndSettle();
  await tester.drag(row, const Offset(650, 0));
  await tester.pumpAndSettle();
}

String dialogText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Text),
      ),
    )
    .map((widget) => widget.data ?? '')
    .join('\n');

void main() {
  testWidgets('转计划可选日期和标题，保留来源、完成状态及双向同步', (tester) async {
    final source = mentor(status: MentorActionStatus.completed);
    final prefs = await start(tester, [source]);
    final initial = DateTime(2026, 11, 10);
    tester
        .widget<ScrollingCalendar>(find.byType(ScrollingCalendar))
        .onDateSelected(initial);
    await tester.pumpAndSettle();
    await openMentorAction(tester);
    final title = find.byKey(const ValueKey('mentor-plan-title'));
    expect(tester.widget<TextField>(title).controller!.text, '整理文献');
    expect(find.text('计划日期：${dateLabel(initial)}'), findsOneWidget);
    await tester.enterText(title, '  文献综述  ');

    await tester.tap(find.byKey(const ValueKey('mentor-plan-date')));
    await tester.pumpAndSettle();
    final picker = find.byType(DatePickerDialog);
    final cancel = MaterialLocalizations.of(
      tester.element(picker),
    ).cancelButtonLabel;
    await tester.tap(find.descendant(of: picker, matching: find.text(cancel)));
    await tester.pumpAndSettle();
    expect(find.text('计划日期：${dateLabel(initial)}'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mentor-plan-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: picker, matching: find.text('15')));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(picker)).okButtonLabel;
    await tester.tap(find.descendant(of: picker, matching: find.text(ok)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pumpAndSettle();

    var rows = decodeBackup(prefs.getString(storageKey)!);
    final plan = rows.singleWhere((r) => r.kind == RecordKind.task);
    final savedSource = rows.singleWhere((r) => r.id == source.id);
    expect(plan.title, '文献综述');
    expect(plan.date, DateTime(2026, 11, 15));
    expect(plan.sourceDiscussionId, source.id);
    expect(plan.sourceMentorActionId, 'action');
    expect(plan.done, isTrue);
    expect(plan.completedAt, isNotNull);
    expect(savedSource.mentorActions.single.text, '整理文献');
    expect(
      savedSource.mentorActions.single.status,
      MentorActionStatus.completed,
    );

    await tester.ensureVisible(find.text('查看关联计划'));
    await tester.tap(find.text('查看关联计划'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RecordEditor>(find.byType(RecordEditor)).record!.id,
      plan.id,
    );
    await tester.tap(find.byTooltip('关闭编辑'));
    await tester.pumpAndSettle();
    expect(decodeBackup(prefs.getString(storageKey)!).length, 2);
    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-inProgress')));
    await tester.pumpAndSettle();
    rows = decodeBackup(prefs.getString(storageKey)!);
    expect(
      rows.singleWhere((r) => r.id == source.id).mentorActions.single.status,
      MentorActionStatus.inProgress,
    );
    expect(rows.singleWhere((r) => r.id == plan.id).done, isFalse);
    expect(rows.singleWhere((r) => r.id == plan.id).completedAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空标题禁止保存，取消和返回不写入', (tester) async {
    final source = mentor();
    final prefs = await start(tester, [source]);
    final original = prefs.getString(storageKey);
    await openMentorAction(tester);
    await tester.enterText(
      find.byKey(const ValueKey('mentor-plan-title')),
      '  ',
    );
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('计划标题不能为空'), findsOneWidget);
    expect(prefs.getString(storageKey), original);
    await tester.enterText(
      find.byKey(const ValueKey('mentor-plan-title')),
      '未保存的标题',
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString(storageKey), original);
    await tester.tap(find.text('转为计划'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mentor-plan-title')), findsNothing);
    expect(prefs.getString(storageKey), original);
  });

  testWidgets('转计划失败保留输入可重试，保存期间禁止取消', (tester) async {
    final source = mentor(status: MentorActionStatus.inProgress);
    final pending = Completer<bool>();
    var attempts = 0;
    late SharedPreferences prefs;
    prefs = await start(
      tester,
      [source],
      write: (snapshot) async {
        attempts++;
        if (attempts == 1) return false;
        if (!await pending.future) return false;
        return prefs.setString(storageKey, snapshot);
      },
    );
    final original = prefs.getString(storageKey);
    tester
        .widget<ScrollingCalendar>(find.byType(ScrollingCalendar))
        .onDateSelected(DateTime(2026, 11, 10));
    await tester.pumpAndSettle();
    await openMentorAction(tester);
    await tester.enterText(
      find.byKey(const ValueKey('mentor-plan-title')),
      '保留标题',
    );
    await tester.tap(find.byKey(const ValueKey('mentor-plan-date')));
    await tester.pumpAndSettle();
    final picker = find.byType(DatePickerDialog);
    await tester.tap(find.descendant(of: picker, matching: find.text('15')));
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(picker)).okButtonLabel;
    await tester.tap(find.descendant(of: picker, matching: find.text(ok)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('转计划失败，请重试'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('mentor-plan-title')))
          .controller!
          .text,
      '保留标题',
    );
    expect(
      find.text('计划日期：${dateLabel(DateTime(2026, 11, 15))}'),
      findsOneWidget,
    );
    expect(prefs.getString(storageKey), original);
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pump();
    expect(find.text('保存中…'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byKey(const ValueKey('mentor-plan-title')), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
          .onPressed,
      isNull,
    );
    pending.complete(true);
    await tester.pumpAndSettle();
    final rows = decodeBackup(prefs.getString(storageKey)!);
    expect(attempts, 2);
    expect(rows.singleWhere((r) => r.kind == RecordKind.task).title, '保留标题');
    expect(
      rows.singleWhere((r) => r.kind == RecordKind.task).date,
      DateTime(2026, 11, 15),
    );
    expect(
      rows.singleWhere((r) => r.id == source.id).mentorActions.single.status,
      MentorActionStatus.inProgress,
    );
    expect(rows.singleWhere((r) => r.kind == RecordKind.task).done, isFalse);
    expect(find.byKey(const ValueKey('mentor-plan-title')), findsNothing);
  });

  testWidgets('删除关联计划说明导师事项保留，取消及撤销均保留关联', (tester) async {
    final source = mentor(status: MentorActionStatus.completed);
    final plan = linkedPlan(source);
    final prefs = await start(tester, [source, plan]);
    final original = prefs.getString(storageKey);
    await openDelete(tester, plan.id);
    expect(dialogText(tester), contains('导师交流及对应跟进事项保留，事项状态不变'));
    expect(dialogText(tester), contains('计划在回收站期间不再同步'));
    expect(dialogText(tester), contains('可再次将该事项转为计划'));
    expect(dialogText(tester), contains('来源不存在或事项已有其他计划'));
    expect(dialogText(tester), contains('旧计划将不再关联原事项'));
    expect(dialogText(tester), contains('状态也可能因期间更改而不一致'));
    expect(dialogText(tester), contains('关联也可能因后续编辑'));
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString(storageKey), original);
    await openDelete(tester, plan.id);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    var snapshot = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(snapshot.records.single.id, source.id);
    expect(
      snapshot.records.single.mentorActions.single.status,
      MentorActionStatus.completed,
    );
    expect(snapshot.trash.single.record.id, plan.id);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    snapshot = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(
      snapshot.records.singleWhere((r) => r.id == plan.id).sourceMentorActionId,
      'action',
    );
    expect(
      snapshot.records
          .singleWhere((r) => r.id == source.id)
          .mentorActions
          .single
          .status,
      MentorActionStatus.completed,
    );
    expect(snapshot.trash, isEmpty);
  });

  testWidgets('删除交流时事项进入回收站，计划保留并解除关联，撤销恢复', (tester) async {
    final source = mentor(status: MentorActionStatus.inProgress);
    final plan = linkedPlan(source);
    final next = ResearchRecord(
      id: 'next',
      kind: RecordKind.mentor,
      date: source.date,
      title: '后续交流',
      previousDiscussionId: source.id,
    );
    final prefs = await start(tester, [source, plan, next]);
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    await openDelete(tester, source.id);
    final text = dialogText(tester);
    expect(text, contains('跟进事项将随交流一起移入回收站'));
    expect(text, contains('1 项关联计划会保留'));
    expect(text, contains('关联将解除，状态不再同步'));
    expect(text, contains('1 条后续交流的上次交流关联将被移除，正文保留'));
    expect(text, contains('关联也可能因后续编辑'));
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    var snapshot = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(
      snapshot.trash.single.record.mentorActions.single.status,
      MentorActionStatus.inProgress,
    );
    expect(
      snapshot.records.singleWhere((r) => r.id == plan.id).sourceDiscussionId,
      isNull,
    );
    expect(snapshot.records.singleWhere((r) => r.id == plan.id).done, isFalse);
    expect(
      snapshot.records.singleWhere((r) => r.id == next.id).previousDiscussionId,
      isNull,
    );
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    snapshot = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(
      snapshot.records.singleWhere((r) => r.id == plan.id).sourceDiscussionId,
      source.id,
    );
    expect(
      snapshot.records.singleWhere((r) => r.id == next.id).previousDiscussionId,
      source.id,
    );
    expect(
      snapshot.records
          .singleWhere((r) => r.id == source.id)
          .mentorActions
          .single
          .status,
      MentorActionStatus.inProgress,
    );
  });

  testWidgets('多次打开转计划时以最新事项状态保存并防止重复', (tester) async {
    final source = mentor();
    final prefs = await start(tester, [source]);
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('转为计划'));
    final convert = tester
        .widget<TextButton>(find.widgetWithText(TextButton, '转为计划'))
        .onPressed!;
    final changeStatus = tester
        .widget<MentorStatusPicker>(find.byType(MentorStatusPicker))
        .onChanged!;
    convert();
    await tester.pumpAndSettle();
    changeStatus(MentorActionStatus.completed);
    await tester.pumpAndSettle();
    convert();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mentor-plan-title')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('该事项已有对应计划，请取消后查看关联计划'), findsOneWidget);
    final rows = decodeBackup(prefs.getString(storageKey)!);
    expect(rows.length, 2);
    expect(rows.singleWhere((r) => r.kind == RecordKind.task).done, isTrue);
    expect(
      rows.singleWhere((r) => r.id == source.id).mentorActions.single.done,
      isTrue,
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
  });

  testWidgets('删除关联计划后重建，再恢复旧计划不会重复占用来源', (tester) async {
    final source = mentor(status: MentorActionStatus.completed);
    final oldPlan = linkedPlan(source);
    final prefs = await start(tester, [source, oldPlan]);
    await openDelete(tester, oldPlan.id);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await openMentorAction(tester);
    await tester.enterText(
      find.byKey(const ValueKey('mentor-plan-title')),
      '新计划',
    );
    await tester.tap(find.byKey(const ValueKey('mentor-plan-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    final bin = find.textContaining('回收站（');
    await tester.ensureVisible(bin);
    await tester.pumpAndSettle();
    await tester.tap(bin);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    final snapshot = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    final plans = snapshot.records
        .where((r) => r.kind == RecordKind.task)
        .toList();
    expect(plans.length, 2);
    expect(
      plans.singleWhere((r) => r.id == oldPlan.id).sourceDiscussionId,
      isNull,
    );
    expect(
      plans.singleWhere((r) => r.title == '新计划').sourceMentorActionId,
      'action',
    );
    expect(
      snapshot.records
          .singleWhere((r) => r.id == source.id)
          .mentorActions
          .single
          .done,
      isTrue,
    );
    expect(snapshot.trash, isEmpty);
  });

  testWidgets('回收站期间状态不同步，恢复后状态变更才重新同步', (tester) async {
    final source = mentor();
    final plan = linkedPlan(source);
    final prefs = await start(tester, [source, plan]);
    await openDelete(tester, plan.id);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(MentorStatusPicker));
    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-completed')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    final bin = find.textContaining('回收站（');
    await tester.ensureVisible(bin);
    await tester.pumpAndSettle();
    await tester.tap(bin);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    var rows = decodeBackup(prefs.getString(storageKey)!);
    expect(
      rows.singleWhere((r) => r.id == plan.id).sourceMentorActionId,
      'action',
    );
    expect(rows.singleWhere((r) => r.id == plan.id).done, isFalse);
    expect(
      rows.singleWhere((r) => r.id == source.id).mentorActions.single.done,
      isTrue,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    if (find.byType(MentorStatusPicker).evaluate().isEmpty) {
      await tester.tap(find.text('交流详情与跟进'));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byType(MentorStatusPicker));
    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-inProgress')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-completed')));
    await tester.pumpAndSettle();
    rows = decodeBackup(prefs.getString(storageKey)!);
    expect(rows.singleWhere((r) => r.id == plan.id).done, isTrue);
    expect(
      rows.singleWhere((r) => r.id == source.id).mentorActions.single.done,
      isTrue,
    );
  });

  testWidgets('关联记录删除写入失败时保留计划、事项及关联', (tester) async {
    final source = mentor(status: MentorActionStatus.completed);
    final plan = linkedPlan(source);
    var writes = 0;
    final prefs = await start(
      tester,
      [source, plan],
      write: (_) async {
        writes++;
        return false;
      },
    );
    final original = prefs.getString(storageKey);
    await openDelete(tester, plan.id);
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(prefs.getString(storageKey), original);
    expect(find.text('删除未确认成功，请重试'), findsOneWidget);
    expect(find.byKey(ValueKey('record-swipe-${plan.id}')), findsOneWidget);
  });

  testWidgets('未关联记录不出现关联影响提示', (tester) async {
    final plain = ResearchRecord(
      id: 'plain',
      kind: RecordKind.task,
      date: DateTime.now(),
      title: '普通计划',
    );
    await start(tester, [plain]);
    await openDelete(tester, plain.id);
    final text = dialogText(tester);
    expect(text, isNot(contains('跟进事项')));
    expect(text, isNot(contains('关联计划')));
    expect(text, isNot(contains('关联可能')));
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
  });
}
