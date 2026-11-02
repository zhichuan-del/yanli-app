import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('日历显示本周计划完成率和进展数，无计划不会显示百分百', (tester) async {
    final today = dayOnly(DateTime.now());
    final records = [
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: today,
        title: '已完成',
        done: true,
      ),
      ResearchRecord(id: '2', kind: RecordKind.task, date: today, title: '待完成'),
      ResearchRecord(
        id: '3',
        kind: RecordKind.progress,
        date: today,
        title: '进展',
      ),
    ];
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup(records),
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.byTooltip('收起月历'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('50.0%', skipOffstage: false),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('50.0%', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('进展 1 条', skipOffstage: false), findsOneWidget);
  });
  testWidgets('日历提供回到今天按钮', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('周视图切换日期并可展开月历，收起后保留选中日期', (tester) async {
    final today = dayOnly(DateTime.now());
    final nextWeek = today.add(const Duration(days: 7));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));

    expect(find.byTooltip('收起月历'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('calendar-month-list')),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('收起月历'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日日程'), findsOneWidget);
    expect(find.byTooltip('展开月历'), findsOneWidget);
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(
      find.text('${nextWeek.month}月${nextWeek.day}日 · 科研日程'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('展开月历'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('收起月历'), findsOneWidget);
    await tester.tap(find.byTooltip('收起月历'));
    await tester.pumpAndSettle();
    expect(
      find.text('${nextWeek.month}月${nextWeek.day}日 · 科研日程'),
      findsOneWidget,
    );
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日日程'), findsOneWidget);
  });

  testWidgets('首次打开时今日计划和新建入口在首屏可见', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.pumpAndSettle();
    for (final label in ['新建计划', '新建进展', '新建交流']) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.getBottomLeft(find.text('新建计划')).dy, lessThan(760));
    expect(tester.getBottomLeft(find.textContaining('今日日程')).dy, lessThan(760));
  });
}
