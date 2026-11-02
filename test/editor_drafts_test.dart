import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/editor_drafts.dart';
import 'package:yanli_app/main.dart';

void main() {
  Future<SharedPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }
  Widget editor(SharedPreferences prefs, {RecordKind kind = RecordKind.task, ResearchRecord? record, Future<bool> Function(ResearchRecord)? save}) =>
    MaterialApp(home: Scaffold(body: RecordEditor(prefs: prefs, kind: kind, record: record,
      initialDate: DateTime(2026, 11, 2), onSave: save)));

  testWidgets('草稿重建继续，按新建类型隔离且不进入正式备份', (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(editor(prefs));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '草稿计划');
    await tester.enterText(find.byType(TextField).at(1), '未完成的正文');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(prefs.getString(EditorDrafts.key(RecordKind.task, null)), contains('未完成的正文'));
    expect(prefs.getString('yanli_records_v1'), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(editor(prefs, kind: RecordKind.progress));
    await tester.pumpAndSettle();
    expect(find.text('发现未保存草稿'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(editor(prefs));
    await tester.pumpAndSettle();
    expect(find.text('发现未保存草稿'), findsOneWidget);
    await tester.tap(find.text('继续草稿'));
    await tester.pumpAndSettle();
    expect(find.text('草稿计划'), findsOneWidget);
    expect(find.text('未完成的正文'), findsOneWidget);
  });

  testWidgets('保存失败保留草稿，重试成功清除草稿', (tester) async {
    final prefs = await preferences();
    var succeeds = false;
    await tester.pumpWidget(editor(prefs, save: (_) async => succeeds));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '失败仍保留');
    await tester.ensureVisible(find.text('保存计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(prefs.getString(EditorDrafts.key(RecordKind.task, null)), contains('失败仍保留'));
    succeeds = true;
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(prefs.getString(EditorDrafts.key(RecordKind.task, null)), isNull);
  });

  testWidgets('明确放弃删除草稿，编辑ID之间独立，较新原记录禁止静默覆盖', (tester) async {
    final prefs = await preferences();
    final original = ResearchRecord(id: 'a', kind: RecordKind.task, date: DateTime(2026), title: '原记录');
    await tester.pumpWidget(editor(prefs, record: original));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '旧版本草稿');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    final other = ResearchRecord(id: 'b', kind: RecordKind.task, date: DateTime(2026), title: '另一个记录');
    await tester.pumpWidget(editor(prefs, record: other));
    await tester.pumpAndSettle();
    expect(find.text('发现未保存草稿'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(editor(prefs, record: original.copyWith(title: '较新内容', updatedAt: DateTime.now())));
    await tester.pumpAndSettle();
    expect(find.text('原记录已更新'), findsOneWidget);
    expect(find.text('继续草稿'), findsNothing);
    await tester.tap(find.text('放弃草稿'));
    await tester.pumpAndSettle();
    expect(find.text('较新内容'), findsOneWidget);
    expect(prefs.getString(EditorDrafts.key(RecordKind.task, 'a')), isNull);
  });

  testWidgets('大字体键盘输入与后台刷新保留正文，不恢复录音状态', (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5), viewInsets: const EdgeInsets.only(bottom: 220)),
      child: child!), home: Scaffold(body: RecordEditor(prefs: prefs, kind: RecordKind.progress, initialDate: DateTime(2026)))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '键盘标题');
    await tester.enterText(find.byType(TextField).at(1), '已识别或手写的正文');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(prefs.getString(EditorDrafts.key(RecordKind.progress, null)), contains('已识别或手写的正文'));
    expect(find.text('正在聆听，请说话'), findsNothing);
    expect(tester.takeException(), isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  test('串行写入后移除不复活，清除所有草稿不影响正式快照', () async {
    final prefs = await preferences();
    await prefs.setString('yanli_records_v1', 'formal');
    final drafts = EditorDrafts(prefs);
    final key = EditorDrafts.key(RecordKind.mentor, null);
    final write = drafts.write(key, {'title': '草稿'});
    final remove = EditorDrafts(prefs).remove(key);
    await Future.wait([write, remove]);
    expect(drafts.read(key), isNull);
    await drafts.write(key, {'title': '草稿'});
    await drafts.clear();
    expect(drafts.read(key), isNull);
    expect(prefs.getString('yanli_records_v1'), 'formal');
  });

  test('草稿写入异常不锁死串行队列，后续可重试', () async {
    final prefs = await preferences();
    var calls = 0;
    final drafts = EditorDrafts(prefs, writeValue: (key, value) async {
      if (++calls == 1) throw StateError('disk unavailable');
      return prefs.setString(key, value);
    });
    final key = EditorDrafts.key(RecordKind.task, null);
    await expectLater(drafts.write(key, {'title': '失败'}), throwsStateError);
    await drafts.write(key, {'title': '重试成功'});
    expect(drafts.read(key)!['title'], '重试成功');
  });

  testWidgets('交流全部字段及未填写完成的事项恢复，状态保持但不恢复录音', (tester) async {
    final prefs = await preferences();
    final key = EditorDrafts.key(RecordKind.mentor, null);
    await EditorDrafts(prefs).write(key, {
      'base': null, 'title': '讨论草稿', 'detail': '详细反馈', 'problem': '结论',
      'next': '旧版下一步', 'duration': '45', 'mentorName': '王老师',
      'previousFollowUp': '已核实', 'date': '2026-10-20T00:00:00.000',
      'priority': '高', 'progressType': '论文写作', 'plannedTime': '09:30',
      'nextMeetingDate': '2026-11-03T00:00:00.000', 'previousDiscussionId': null,
      'actions': [{'id': 'a', 'text': '', 'status': 'inProgress'}],
    });
    await tester.pumpWidget(editor(prefs, kind: RecordKind.mentor));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续草稿'));
    await tester.pumpAndSettle();
    expect(find.text('讨论草稿'), findsOneWidget);
    expect(find.text('详细反馈'), findsOneWidget);
    expect(find.text('2026.10.20'), findsOneWidget);
    await tester.ensureVisible(find.text('处理中'));
    await tester.pumpAndSettle();
    expect(find.text('处理中'), findsOneWidget);
    expect(find.text('正在聆听，请说话'), findsNothing);
    final input = find.byKey(const ValueKey('mentorActionInput'));
    await tester.enterText(input, '补齐事项');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final restored = EditorDrafts(prefs).read(key)!;
    expect(restored['mentorName'], '王老师');
    expect(restored['previousFollowUp'], '已核实');
    expect(restored['priority'], '高');
    expect(restored['progressType'], '论文写作');
    expect(restored['plannedTime'], '09:30');
    expect(restored['duration'], '45');
    expect((restored['actions'] as List).single['text'], '补齐事项');
    expect((restored['actions'] as List).single['status'], 'inProgress');
  });
}