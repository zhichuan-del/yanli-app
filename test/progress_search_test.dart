import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/progress_search.dart';

ResearchRecord record(
  String id,
  DateTime date,
  String type, {
  String title = '',
  String detail = '',
  String problem = '',
  String next = '',
}) => ResearchRecord(
  id: id,
  kind: RecordKind.progress,
  date: date,
  title: title,
  detail: detail,
  problem: problem,
  next: next,
  progressType: type,
);

void main() {
  final records = [
    record(
      '1',
      DateTime(2026, 10, 1),
      '文献阅读',
      title: '文章甲',
      detail: '框架',
      next: '复习',
    ),
    record(
      '2',
      DateTime(2026, 10, 10),
      '实验或调研',
      title: '实验乙',
      problem: '框架',
      next: '测试',
    ),
    record('3', DateTime(2026, 10, 20), '文献阅读', title: '文章丙', next: '框架'),
    record('4', DateTime(2026, 10, 21), '文献阅读', title: '框架', detail: '结果'),
  ];

  test('关键词匹配标题成果问题下一步，日期边界和类型取交集', () {
    final result = filterProgressRecords(
      records,
      keyword: ' 框架 ',
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 20),
      type: '文献阅读',
    );
    expect(result.map((r) => r.id), ['1', '3']);
    expect(filterProgressRecords(records, keyword: '框架').map((r) => r.id), [
      '1',
      '2',
      '3',
      '4',
    ]);
    expect(filterProgressRecords(records).length, 4);
  });

  testWidgets('关键词与类型组合筛选，并可清除筛选', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressSearch(
              records: records,
              recordBuilder: (r) => Text('结果：${r.id}'),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '框架');
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文献阅读').last);
    await tester.pumpAndSettle();
    expect(find.text('结果：1'), findsOneWidget);
    expect(find.text('结果：2'), findsNothing);
    expect(find.text('结果：3'), findsOneWidget);
    expect(find.text('结果：4'), findsOneWidget);
    await tester.tap(find.text('清除筛选'));
    await tester.pumpAndSettle();
    expect(find.text('结果：2'), findsOneWidget);
    expect(find.text('全部类型'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('没有记录时显示欢迎状态并调用新建回调', (tester) async {
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressSearch(
              records: const [],
              recordBuilder: (r) => Text('结果：${r.id}'),
              onCreate: () => createCalls++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('还没有科研进展'), findsOneWidget);
    expect(find.text('点击新建开始记录'), findsOneWidget);
    expect(find.text('筛选结果 · 0 条'), findsOneWidget);
    expect(find.text('没有符合条件的科研进展'), findsNothing);

    await tester.ensureVisible(find.text('记录第一条进展'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录第一条进展'));
    expect(createCalls, 1);

    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pump();
    expect(find.text('还没有科研进展'), findsOneWidget);
    expect(find.text('没有符合条件的科研进展'), findsNothing);
    await tester.ensureVisible(find.text('记录第一条进展'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记录第一条进展'));
    await tester.pump();
    expect(createCalls, 2);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('未提供新建回调时空状态操作不可用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressSearch(
              records: const [],
              recordBuilder: (r) => Text('结果：${r.id}'),
            ),
          ),
        ),
      ),
    );

    final create = find.widgetWithText(FilledButton, '记录第一条进展');
    expect(create, findsOneWidget);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    expect(find.text('没有符合条件的科研进展'), findsNothing);
  });

  testWidgets('无匹配时可从结果状态同时清除关键词、类型和日期', (tester) async {
    var createCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressSearch(
              records: records,
              recordBuilder: (r) => Text('结果：${r.id}'),
              onCreate: () => createCalls++,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '不存在');
    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('文献阅读').last);
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(find.text('文献阅读'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '不存在',
    );

    await tester.ensureVisible(find.text('开始日期'));
    await tester.tap(find.text('开始日期'));
    await tester.pumpAndSettle();
    final startDate = tester
        .widget<DatePickerDialog>(find.byType(DatePickerDialog))
        .initialDate!;
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束日期'));
    await tester.pumpAndSettle();
    final endDate = tester
        .widget<DatePickerDialog>(find.byType(DatePickerDialog))
        .initialDate!;
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final dateMatches = dateLabel(startDate) == dateLabel(endDate)
        ? findsNWidgets(2)
        : findsOneWidget;
    expect(find.text(dateLabel(startDate)), dateMatches);
    expect(find.text(dateLabel(endDate)), dateMatches);

    expect(find.text('筛选结果 · 0 条'), findsOneWidget);
    expect(find.text('没有符合条件的科研进展'), findsOneWidget);
    expect(find.text('还没有科研进展'), findsNothing);
    expect(find.text('记录第一条进展'), findsNothing);
    expect(createCalls, 0);

    final clear = find.text('清除筛选条件');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的科研进展'), findsNothing);
    expect(find.text('筛选结果 · 4 条'), findsOneWidget);
    for (final r in records) {
      expect(find.text('结果：${r.id}'), findsOneWidget);
    }
    expect(find.text('全部类型'), findsOneWidget);
    expect(find.text('开始日期'), findsOneWidget);
    expect(find.text('结束日期'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('只有日期筛选时也显示无匹配状态', (tester) async {
    final oldRecord = record('old', DateTime(1900), '文献阅读', title: '旧进展');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressSearch(
              records: [oldRecord],
              recordBuilder: (r) => Text('结果：${r.id}'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('筛选'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('没有符合条件的科研进展'), findsOneWidget);
    expect(find.text('还没有科研进展'), findsNothing);
    expect(find.text('记录第一条进展'), findsNothing);

    final clear = find.text('清除筛选条件');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('开始日期'), findsOneWidget);
    expect(find.text('结果：old'), findsOneWidget);
    expect(find.text('筛选结果 · 1 条'), findsOneWidget);
    expect(find.text('没有符合条件的科研进展'), findsNothing);
  });

  testWidgets('记录变化时在空集合、无匹配和结果之间切换', (tester) async {
    Widget buildSearch(List<ResearchRecord> data) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProgressSearch(
            records: data,
            recordBuilder: (r) => Text('结果：${r.id}'),
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildSearch(records));
    await tester.enterText(find.byType(TextField), '文章甲');
    await tester.pump();
    expect(find.text('结果：1'), findsOneWidget);
    expect(find.text('结果：2'), findsNothing);

    await tester.pumpWidget(buildSearch(const []));
    expect(find.text('还没有科研进展'), findsOneWidget);
    expect(find.text('没有符合条件的科研进展'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '文章甲',
    );

    await tester.pumpWidget(buildSearch([records[1]]));
    expect(find.text('还没有科研进展'), findsNothing);
    expect(find.text('没有符合条件的科研进展'), findsOneWidget);

    await tester.pumpWidget(buildSearch(records));
    expect(find.text('没有符合条件的科研进展'), findsNothing);
    expect(find.text('结果：1'), findsOneWidget);
    expect(find.text('结果：2'), findsNothing);
  });

  testWidgets('创建后的第一条记录立即显示', (tester) async {
    final data = <ResearchRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ProgressSearch(
                records: data,
                recordBuilder: (r) => Text('结果：${r.id}'),
                onCreate: () => setState(() => data.add(records.first)),
              ),
            ),
          ),
        ),
      ),
    );

    final create = find.text('记录第一条进展');
    await tester.ensureVisible(create);
    await tester.pumpAndSettle();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('还没有科研进展'), findsNothing);
    expect(find.text('记录第一条进展'), findsNothing);
    expect(find.text('筛选结果 · 1 条'), findsOneWidget);
    expect(find.text('结果：1'), findsOneWidget);
  });
}
