import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/recycle_bin.dart';
import 'package:yanli_app/frosted_dropdown.dart';

ResearchRecord record(String id, {RecordKind kind = RecordKind.progress}) =>
    ResearchRecord(id: id, kind: kind, date: DateTime.now(), title: '记录$id');

TrashedRecord deleted(ResearchRecord r, {DateTime? at}) =>
    TrashedRecord(RecordDeletion([r], r), at ?? DateTime.now().toUtc());

Future<void> openBin(WidgetTester tester) async {
  await tester.tap(find.text('我的'));
  await tester.pumpAndSettle();
  final tile = find.textContaining('回收站（');
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

LocalRecordSnapshot stored(SharedPreferences prefs) =>
    LocalRecordSnapshot.decode(prefs.getString('yanli_records_v1')!);

Future<void> chooseDays(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('保留时间'));
  await tester.pumpAndSettle();
  expect(find.byType(FrostedMenuSurface), findsOneWidget);
  final menu = tester.widget<PopupMenuButton<int>>(
    find.byType(PopupMenuButton<int>),
  );
  expect(menu.elevation, 0);
  expect(menu.shadowColor, Colors.transparent);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> enterCustomDays(WidgetTester tester, String days) async {
  await chooseDays(tester, '自定义…');
  expect(find.text('保留天数'), findsOneWidget);
  await tester.enterText(find.byType(TextFormField), days);
  await tester.tap(find.widgetWithText(FilledButton, '保存'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('无障碍导航下删除提示三秒消失，回收站仍可恢复', (tester) async {
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record('a')]),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: HomePage(prefs: prefs),
      ),
    );
    await tester.tap(find.text('进展'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('record-swipe-a'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.drag(row, const Offset(650, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(stored(prefs).records, isEmpty);
    expect(stored(prefs).trash.single.record.id, 'a');
    expect(find.text('记录已移入回收站'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await openBin(tester);
    expect(find.text('记录a'), findsOneWidget);
  });

  for (final resume in [false, true]) {
    testWidgets(resume ? '返回前台清理到期记录' : '运行计时清理到期记录', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Verify each trigger retries a failed startup cleanup.
      final expired = LocalRecordSnapshot(
        [],
        trash: [
          deleted(
            record('b'),
            at: DateTime.now().subtract(const Duration(days: 4)),
          ),
        ],
      ).encode();
      await prefs.setString('yanli_records_v1', expired);
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            prefs: prefs,
            writeSnapshot: (value) async =>
                fail ? false : prefs.setString('yanli_records_v1', value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(stored(prefs).trash.length, 1);
      fail = false;
      if (resume) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else {
        await tester.pump(const Duration(minutes: 1));
      }
      await tester.pumpAndSettle();
      expect(stored(prefs).trash, isEmpty);
    });
  }

  testWidgets('回收站恢复失败保留有效记录和回收站，重试成功', (tester) async {
    final snapshot = LocalRecordSnapshot(
      [record('a')],
      trash: [deleted(record('b'))],
    ).encode();
    SharedPreferences.setMockInitialValues({'yanli_records_v1': snapshot});
    final prefs = await SharedPreferences.getInstance();
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (value) async =>
              fail ? false : prefs.setString('yanli_records_v1', value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openBin(tester);
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), snapshot);
    expect(find.text('记录b'), findsOneWidget);
    fail = false;
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    expect(stored(prefs).records.length, 2);
    expect(stored(prefs).trash, isEmpty);
  });

  for (final days in [3, 7, 30]) {
    testWidgets('选择 $days 天保留期限持久化', (tester) async {
      SharedPreferences.setMockInitialValues({
        'yanli_records_v1': LocalRecordSnapshot([], days: 9).encode(),
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(YanliApp(prefs: prefs));
      await tester.pumpAndSettle();
      await openBin(tester);
      await chooseDays(tester, '$days 天');
      expect(stored(prefs).days, days);
    });
  }

  testWidgets('自定义天数保存跨重启，菜单显示当前值', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await openBin(tester);
    await enterCustomDays(tester, '19');
    expect(stored(prefs).days, 19);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await openBin(tester);
    expect(find.text('19 天'), findsOneWidget);
    await tester.tap(find.byTooltip('保留时间'));
    await tester.pumpAndSettle();
    expect(find.text('19 天（自定义）'), findsOneWidget);
    final current = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.text('19 天（自定义）'),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.selected == true,
            ),
          )
          .first,
    );
    expect(current.properties.selected, isTrue);
  });

  testWidgets('非法自定义输入不保存，取消保持原数据', (tester) async {
    final raw = LocalRecordSnapshot([], days: 7).encode();
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await openBin(tester);
    await chooseDays(tester, '自定义…');
    for (final value in ['', '0', '-1', '1.5', 'abc', '3651']) {
      await tester.enterText(find.byType(TextFormField), value);
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入 1–3650 天的正整数'), findsWidgets);
      expect(prefs.getString('yanli_records_v1'), raw);
    }
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('7 天'), findsOneWidget);
  });

  testWidgets('缩短自定义期限取消不变、失败保留、确认重试原子清理', (tester) async {
    final raw = LocalRecordSnapshot(
      [record('a')],
      days: 30,
      trash: [
        deleted(
          record('old'),
          at: DateTime.now().subtract(const Duration(days: 10)),
        ),
        deleted(record('new')),
      ],
    ).encode();
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (value) async =>
              fail ? false : prefs.setString('yanli_records_v1', value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openBin(tester);
    await enterCustomDays(tester, '5');
    expect(find.text('缩短保留时间？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), raw);
    expect(find.text('30 天'), findsOneWidget);
    await enterCustomDays(tester, '5');
    await tester.tap(find.text('确认修改'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), raw);
    expect(find.text('记录old'), findsOneWidget);
    expect(find.text('30 天'), findsOneWidget);
    fail = false;
    await enterCustomDays(tester, '5');
    await tester.tap(find.text('确认修改'));
    await tester.pumpAndSettle();
    expect(stored(prefs).days, 5);
    expect(stored(prefs).records.single.id, 'a');
    expect(stored(prefs).trash.single.record.id, 'new');
    expect(find.text('记录old'), findsNothing);
  });

  for (final days in [1, 9, 3650]) {
    test('自定义 $days 天可序列化往返', () {
      expect(
        LocalRecordSnapshot.decode(
          LocalRecordSnapshot([], days: days).encode(),
        ).days,
        days,
      );
    });
  }

  for (final days in [0, -1, 3651, 3.0, '7', null]) {
    test('非法期限 $days (${days.runtimeType}) 拒绝读取', () {
      final data = jsonDecode(LocalRecordSnapshot([]).encode()) as Map;
      (data['localRecycleBin'] as Map)['days'] = days;
      expect(
        () => LocalRecordSnapshot.decode(jsonEncode(data)),
        throwsFormatException,
      );
    });
  }

  testWidgets('损坏回收站不被启动清理覆盖', (tester) async {
    final data =
        jsonDecode(encodeBackup([record('a')])) as Map<String, dynamic>;
    data['localRecycleBin'] = {'version': 1, 'days': 3, 'entries': 'broken'};
    final raw = jsonEncode(data);
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.textContaining('本地数据读取失败'), findsOneWidget);
    expect(prefs.getString('yanli_records_v1'), raw);
  });

  test('旧备份兼容，新本地快照单次携带有效记录、回收站及期限', () {
    final active = record('a');
    final entry = deleted(record('b'));
    expect(LocalRecordSnapshot.decode(encodeBackup([active])).days, 3);
    final encoded = LocalRecordSnapshot(
      [active],
      trash: [entry],
      days: 7,
    ).encode();
    final snapshot = LocalRecordSnapshot.decode(encoded);
    expect(snapshot.days, 7);
    expect(snapshot.trash.single.deletedAt, entry.deletedAt);
    expect(decodeBackup(encoded).single.id, 'a');
    expect(
      jsonDecode(encodeBackup(snapshot.records)),
      isNot(contains('localRecycleBin')),
    );
  });

  for (final days in [3, 7, 30]) {
    test('$days 天精确到期边界', () {
      final at = DateTime.utc(2026, 1, 1);
      final entry = deleted(record('b'), at: at);
      expect(
        entry.expired(
          at
              .add(Duration(days: days))
              .subtract(const Duration(microseconds: 1)),
          days,
        ),
        isFalse,
      );
      expect(entry.expired(at.add(Duration(days: days)), days), isTrue);
    });
  }

  test('损坏回收站、重复 ID、无效元数据拒绝加载', () {
    final data =
        jsonDecode(
              LocalRecordSnapshot([], trash: [deleted(record('b'))]).encode(),
            )
            as Map<String, dynamic>;
    final bin = data['localRecycleBin'] as Map;
    bin['days'] = 3651;
    expect(
      () => LocalRecordSnapshot.decode(jsonEncode(data)),
      throwsFormatException,
    );
    bin['days'] = 3;
    (bin['entries'] as List).add((bin['entries'] as List).first);
    expect(
      () => LocalRecordSnapshot.decode(jsonEncode(data)),
      throwsFormatException,
    );
    data['localRecycleBin'] = null;
    expect(
      () => LocalRecordSnapshot.decode(jsonEncode(data)),
      throwsFormatException,
    );
  });

  test('跨序列化恢复沿用 merge，保留新编辑且不复活其他删除记录', () {
    final mentor = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '导师',
    );
    final child = ResearchRecord(
      id: 'c',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '后续',
      previousDiscussionId: 'm',
    );
    final other = record('other');
    final deletion = RecordDeletion([mentor, child, other], mentor);
    final entry = LocalRecordSnapshot.decode(
      LocalRecordSnapshot(
        [],
        trash: [TrashedRecord(deletion, DateTime.now())],
      ).encode(),
    ).trash.single;
    final edited = deletion
        .apply([mentor, child])
        .single
        .copyWith(title: '新编辑', updatedAt: DateTime.now());
    final restored = entry.restore([edited, record('new')]);
    expect(restored.first.title, '新编辑');
    expect(restored.first.previousDiscussionId, isNull);
    expect(restored.map((r) => r.id), ['c', 'new', 'm']);
  });

  test('同源新计划已占用时恢复旧计划不重复来源，缺失上次交流也安全恢复', () {
    final mentor = ResearchRecord(
      id: 'm',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '导师',
      mentorActions: [MentorAction(id: 'a', text: '事项')],
    );
    final task = ResearchRecord(
      id: 'old',
      kind: RecordKind.task,
      date: DateTime.now(),
      title: '旧计划',
      sourceDiscussionId: 'm',
      sourceMentorActionId: 'a',
    );
    final current = planMentorAction(
      [mentor],
      mentor,
      mentor.mentorActions.single,
      DateTime.now(),
      DateTime.now(),
    );
    final restored = deleted(task).restore(current);
    expect(restored.last.sourceDiscussionId, isNull);
    expect(decodeBackup(encodeBackup(restored)).length, 3);
    final child = ResearchRecord(
      id: 'c',
      kind: RecordKind.mentor,
      date: DateTime.now(),
      title: '后续',
      previousDiscussionId: 'm',
    );
    expect(deleted(child).restore([]).single.previousDiscussionId, isNull);
  });

  testWidgets('跨重启恢复回收站，并持久移回有效记录', (tester) async {
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': LocalRecordSnapshot(
        [record('a')],
        trash: [deleted(record('b'))],
      ).encode(),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    await openBin(tester);
    expect(find.textContaining('删除时间：'), findsOneWidget);
    expect(find.textContaining('剩余时间：'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '恢复'));
    await tester.pumpAndSettle();
    expect(stored(prefs).records.map((r) => r.id), ['a', 'b']);
    expect(stored(prefs).trash, isEmpty);
  });

  for (final days in [3, 7]) {
    testWidgets('启动按 $days 天清理，失败保留完整快照', (tester) async {
      final snapshot = LocalRecordSnapshot(
        [record('a')],
        days: days,
        trash: [
          deleted(
            record('b'),
            at: DateTime.now().subtract(Duration(days: days, minutes: 1)),
          ),
        ],
      ).encode();
      SharedPreferences.setMockInitialValues({'yanli_records_v1': snapshot});
      final prefs = await SharedPreferences.getInstance();
      var fail = true;
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            prefs: prefs,
            writeSnapshot: (value) async {
              final next = LocalRecordSnapshot.decode(value);
              expect(next.records.single.id, 'a');
              expect(next.trash, isEmpty);
              if (fail) return false;
              return prefs.setString('yanli_records_v1', value);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(prefs.getString('yanli_records_v1'), snapshot);
      fail = false;
      await openBin(tester);
      expect(stored(prefs).trash, isEmpty);
      expect(find.text('回收站为空'), findsOneWidget);
    });
  }

  testWidgets('永久删除与清空需确认，失败可重试且不改变两部分记录', (tester) async {
    final snapshot = LocalRecordSnapshot(
      [record('a')],
      trash: [deleted(record('b')), deleted(record('c'))],
    ).encode();
    SharedPreferences.setMockInitialValues({'yanli_records_v1': snapshot});
    final prefs = await SharedPreferences.getInstance();
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (value) async =>
              fail ? false : prefs.setString('yanli_records_v1', value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openBin(tester);
    await tester.tap(find.text('永久删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), snapshot);
    await tester.tap(find.text('清空回收站'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), snapshot);
    fail = false;
    await tester.tap(find.text('永久删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pumpAndSettle();
    expect(stored(prefs).trash.length, 1);
    await tester.tap(find.text('清空回收站'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '永久删除'));
    await tester.pumpAndSettle();
    expect(stored(prefs).trash, isEmpty);
    expect(stored(prefs).records.single.id, 'a');
  });
}
