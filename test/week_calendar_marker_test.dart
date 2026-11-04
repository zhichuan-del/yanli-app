import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

const _markers = [
  (RecordKind.task, '计划记录', Icons.check_circle_outline),
  (RecordKind.progress, '科研进展', Icons.auto_stories_outlined),
  (RecordKind.mentor, '导师交流', Icons.forum_outlined),
];

String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
Finder _day(DateTime date) =>
    find.byKey(ValueKey('calendar-week-day-${_dateKey(date)}'));
Finder _marker(DateTime date, RecordKind kind) =>
    find.byKey(ValueKey('calendar-week-marker-${_dateKey(date)}-${kind.name}'));
Finder _legend(RecordKind kind) =>
    find.byKey(ValueKey('calendar-week-legend-${kind.name}'));

Future<DateTime> _mount(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double scale = 1,
}) async {
  final initialWidth = width < 320 || (width == 320 && scale > 2)
      ? 390.0
      : width;
  tester.view.physicalSize = Size(initialWidth, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final start = weekStart(dayOnly(DateTime.now()));
  final dates = List.generate(7, (index) => start.add(Duration(days: index)));
  final records = <ResearchRecord>[
    for (final kind in RecordKind.values)
      ResearchRecord(
        id: 'all-${kind.name}',
        kind: kind,
        date: dates[0],
        title: kind.name,
      ),
    ResearchRecord(
      id: 'task',
      kind: RecordKind.task,
      date: dates[1],
      title: '计划',
    ),
    ResearchRecord(
      id: 'progress',
      kind: RecordKind.progress,
      date: dates[2],
      title: '进展',
    ),
    ResearchRecord(
      id: 'mentor',
      kind: RecordKind.mentor,
      date: dates[3],
      title: '交流',
    ),
  ];
  SharedPreferences.setMockInitialValues({
    'yanli_records_v1': encodeBackup(records),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(YanliApp(prefs: prefs));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('收起月历'));
  await tester.pumpAndSettle();
  if (width != initialWidth) {
    tester.view.physicalSize = Size(width, height);
    await tester.pumpAndSettle();
  }
  return start;
}

void main() {
  testWidgets('周视图标记与图例使用月视图图标并按类型显示', (tester) async {
    final start = await _mount(tester);
    for (final (kind, label, icon) in _markers) {
      expect(tester.widget<Icon>(_marker(start, kind)).icon, icon);
      final legend = _legend(kind);
      expect(
        find.descendant(of: legend, matching: find.text(label)),
        findsOneWidget,
      );
      final legendIcon = tester.widget<Icon>(
        find.descendant(of: legend, matching: find.byType(Icon)),
      );
      expect(legendIcon.icon, icon);
      expect(legendIcon.color, tester.widget<Icon>(_marker(start, kind)).color);
    }
    for (var index = 1; index <= 4; index++) {
      final date = start.add(Duration(days: index));
      for (final kind in RecordKind.values) {
        expect(
          _marker(date, kind),
          index == kind.index + 1 ? findsOneWidget : findsNothing,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('周日期读屏包含具体类型、今天与选中状态并可选择和切周', (tester) async {
    final semantics = tester.ensureSemantics();
    final start = await _mount(tester);
    final today = dayOnly(DateTime.now());
    final first = tester.getSemantics(_day(start)).getSemanticsData();
    expect(
      first.label,
      '${start.month}月${start.day}日，星期一${start == today ? '，今天' : ''}，有记录，有计划，有进展，有导师交流',
    );
    expect(first.flagsCollection.isButton, isTrue);
    expect(
      first.flagsCollection.isSelected,
      start == today ? Tristate.isTrue : Tristate.isFalse,
    );
    expect(first.hasAction(SemanticsAction.tap), isTrue);
    final empty = start.add(const Duration(days: 4));
    expect(
      tester.getSemantics(_day(empty)).getSemanticsData().label,
      '${empty.month}月${empty.day}日，星期五${empty == today ? '，今天' : ''}',
    );
    final task = start.add(const Duration(days: 1));
    expect(
      tester.getSemantics(_day(task)).getSemanticsData().label,
      '${task.month}月${task.day}日，星期二${task == today ? '，今天' : ''}，有记录，有计划',
    );
    for (final (index, weekday, description) in [
      (2, '三', '有进展'),
      (3, '四', '有导师交流'),
    ]) {
      final date = start.add(Duration(days: index));
      expect(
        tester.getSemantics(_day(date)).getSemanticsData().label,
        '${date.month}月${date.day}日，星期$weekday${date == today ? '，今天' : ''}，有记录，$description',
      );
    }
    await tester.tap(_day(start));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(_day(start))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.byTooltip('下一周'));
    await tester.pumpAndSettle();
    expect(_day(start.add(const Duration(days: 7))), findsOneWidget);
    expect(_marker(start, RecordKind.task), findsNothing);
    await tester.tap(find.byTooltip('上一周'));
    await tester.pumpAndSettle();
    expect(_marker(start, RecordKind.task), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('小屏为图例留空间后日程面板仍可手动展开', (tester) async {
    await _mount(tester, width: 320, height: 640, scale: 2);
    final sheet = tester.widget<DraggableScrollableSheet>(
      find.byType(DraggableScrollableSheet),
    );
    final controller = sheet.controller!;
    expect(controller.size, lessThan(.56));
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('calendar-agenda-handle'))),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(controller.size, greaterThan(.56));
    expect(tester.takeException(), isNull);
  });

  for (final (width, height, scale) in [
    (390.0, 844.0, 2.0),
    (320.0, 844.0, 2.0),
    (320.0, 844.0, 2.5),
    (280.0, 844.0, 2.5),
    (320.0, 640.0, 1.5),
    (320.0, 640.0, 2.0),
    (320.0, 640.0, 2.5),
    (280.0, 640.0, 2.5),
  ]) {
    testWidgets('周视图 $width × $height、字体 $scale 时日期、标记、图例可见且不溢出', (
      tester,
    ) async {
      final start = await _mount(
        tester,
        width: width,
        height: height,
        scale: scale,
      );
      final sheetTop = tester
          .getTopLeft(find.byKey(const ValueKey('calendar-agenda-list')))
          .dy;
      for (var index = 0; index < 7; index++) {
        final day = _day(start.add(Duration(days: index)));
        expect(day.hitTestable(), findsOneWidget);
        expect(tester.getBottomLeft(day).dy, lessThanOrEqualTo(sheetTop));
      }
      for (final (kind, label, _) in _markers) {
        final legend = _legend(kind);
        expect(tester.getBottomLeft(legend).dy, lessThanOrEqualTo(sheetTop));
        final text = find.descendant(of: legend, matching: find.text(label));
        expect(tester.getSize(text).height, greaterThanOrEqualTo(12 * scale));
        expect(
          MediaQuery.textScalerOf(tester.element(text)).scale(12),
          12 * scale,
        );
        final markerRect = tester.getRect(_marker(start, kind));
        final dayRect = tester.getRect(_day(start));
        expect(dayRect.contains(markerRect.topLeft), isTrue);
        expect(
          dayRect.contains(markerRect.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
