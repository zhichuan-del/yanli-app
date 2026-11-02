import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/scrolling_calendar.dart';

Finder get _agenda => find.byKey(const ValueKey('calendar-agenda-list'));
Finder get _months => find.byKey(const ValueKey('calendar-month-list'));

ScrollPosition _position(WidgetTester tester, Finder list) => tester
    .state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    )
    .position;

Future<void> _mount(
  WidgetTester tester, {
  double scale = 1,
  bool wide = false,
}) async {
  tester.view.physicalSize = wide
      ? const Size(1200, 900)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final today = dayOnly(DateTime.now());
  SharedPreferences.setMockInitialValues({
    'yanli_records_v1': encodeBackup([
      for (var i = 0; i < 8; i++)
        ResearchRecord(
          id: '$i',
          kind: RecordKind.task,
          date: today,
          title: '今日计划 $i',
        ),
    ]),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(YanliApp(prefs: prefs));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('日程拖动和月历浏览相互独立，工具栏新建保留所选日期', (tester) async {
    await _mount(tester);
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    final controller = sheet.controller!;
    final monthPosition = _position(tester, _months);
    final originalMonthOffset = monthPosition.pixels;
    expect(
      tester.getSize(find.byType(ScrollingCalendar)).height,
      greaterThan(700),
    );
    final title = tester
        .widget<Text>(find.byKey(const ValueKey('calendar-month')))
        .data;
    expect(controller.size, closeTo(.32, .01));
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('calendar-agenda-handle'))),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();
    expect(controller.size, greaterThan(.55));
    expect(monthPosition.pixels, originalMonthOffset);
    await tester.scrollUntilVisible(
      find.textContaining('所选周计划 8 项'),
      240,
      scrollable: find.descendant(
        of: _agenda,
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('所选周计划 8 项').hitTestable(), findsOneWidget);
    expect(monthPosition.pixels, originalMonthOffset);
    for (var i = 0; i < 6; i++) {
      await tester.drag(_agenda, const Offset(0, 450));
      await tester.pumpAndSettle();
    }
    expect(controller.size, lessThan(.4));
    final collapsedSize = controller.size;
    await tester.dragFrom(
      tester.getTopLeft(_months) + const Offset(180, 110),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(monthPosition.pixels, greaterThan(originalMonthOffset));
    expect(controller.size, closeTo(collapsedSize, .01));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('calendar-month'))).data,
      isNot(title),
    );
    expect(find.textContaining('今日日程'), findsOneWidget);
    final offsetAfterBrowsing = monthPosition.pixels;
    final sizeAfterBrowsing = controller.size;
    await tester.tap(find.byKey(const ValueKey('calendar-create')));
    await tester.pumpAndSettle();
    final menu = find.byType(BottomSheet);
    await tester.tap(
      find.descendant(of: menu, matching: find.text('新建进展')).last,
    );
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditor), findsOneWidget);
    expect(
      tester.widget<RecordEditor>(find.byType(RecordEditor)).initialDate,
      dayOnly(DateTime.now()),
    );
    await tester.tap(find.byTooltip('关闭编辑'));
    await tester.pumpAndSettle();
    expect(monthPosition.pixels, offsetAfterBrowsing);
    expect(controller.size, closeTo(sizeAfterBrowsing, .01));
    await tester.ensureVisible(find.text('今天'));
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(monthPosition.pixels, originalMonthOffset);
    expect(controller.size, closeTo(.35, .01));
    final day = find.byKey(
      ValueKey('calendar-day-${DateTime.now().year}-${DateTime.now().month}-1'),
    );
    await tester.tap(day);
    await tester.pumpAndSettle();
    expect(monthPosition.pixels, originalMonthOffset);
    expect(controller.size, closeTo(.35, .01));
    expect(tester.takeException(), isNull);
  });

  for (final config in [(1.5, false), (2.0, false), (1.5, true)]) {
    testWidgets('字体${config.$1}，宽屏${config.$2}时日程和工具均可操作且无溢出', (tester) async {
      await _mount(tester, scale: config.$1, wide: config.$2);
      for (final label in ['新建计划', '新建进展', '新建交流']) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('calendar-create')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('收起月历'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('下一周').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('展开月历'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
