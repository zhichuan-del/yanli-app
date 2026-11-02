import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('导师交流可填写对象并添加两个独立跟进事项', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(RecordEditor),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.first, '课题讨论');
    final mentorName = find.widgetWithText(TextField, '交流对象 *');
    await tester.ensureVisible(mentorName);
    await tester.enterText(mentorName, '张老师');
    final add = find.text('添加跟进事项');
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    final actions = find.byKey(const ValueKey('mentorActionInput'));
    expect(actions, findsNWidgets(2));
    await tester.enterText(actions.at(0), '整理文献');
    await tester.enterText(actions.at(1), '修改方案');
    await tester.ensureVisible(find.text('保存导师交流'));
    await tester.tap(find.text('保存导师交流'));
    await tester.pumpAndSettle();
    final r = decodeBackup(prefs.getString('yanli_records_v1')!).single;
    expect(r.mentorName, '张老师');
    expect(r.mentorActions.map((a) => a.text), ['整理文献', '修改方案']);
    expect(r.mentorActions.map((a) => a.done), [false, false]);
  });
  testWidgets('导师跟进事项的完成状态独立保存', (tester) async {
    final record = ResearchRecord(
      id: 'mentor',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '导师交流',
      mentorActions: [
        MentorAction(id: 'one', text: '整理文献'),
        MentorAction(id: 'two', text: '修改方案'),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    final statuses = find.byType(MentorStatusPicker);
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    expect(statuses, findsNWidgets(2));
    await tester.ensureVisible(statuses.first);
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(statuses.first),
      matchesSemantics(
        label: '跟进状态：未处理',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasExpandedState: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
        tooltip: '跟进状态：未处理',
      ),
    );
    semantics.dispose();
    await tester.tap(statuses.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();
    final actions = decodeBackup(
      prefs.getString('yanli_records_v1')!,
    ).single.mentorActions;
    expect(actions.map((a) => a.done), [true, false]);
  });

  testWidgets('跟进状态写入失败后保留原状态并允许重试', (tester) async {
    final record = ResearchRecord(
      id: 'mentor',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '导师交流',
      mentorActions: [MentorAction(id: 'one', text: '整理文献')],
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record]),
    });
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (snapshot) async {
            writes++;
            return writes == 1
                ? false
                : prefs.setString('yanli_records_v1', snapshot);
          },
        ),
      ),
    );
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    final picker = find.byType(MentorStatusPicker);
    await tester.tap(find.text('交流详情与跟进'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-completed')));
    await tester.pumpAndSettle();
    expect(find.text('跟进状态保存未确认，请重试'), findsOneWidget);
    expect(
      tester.widget<MentorStatusPicker>(picker).value,
      MentorActionStatus.pending,
    );
    expect(
      decodeBackup(
        prefs.getString('yanli_records_v1')!,
      ).single.mentorActions.single.status,
      MentorActionStatus.pending,
    );

    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mentor-status-inProgress')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MentorStatusPicker>(picker).value,
      MentorActionStatus.inProgress,
    );
    expect(
      decodeBackup(
        prefs.getString('yanli_records_v1')!,
      ).single.mentorActions.single.status,
      MentorActionStatus.inProgress,
    );
  });
}
