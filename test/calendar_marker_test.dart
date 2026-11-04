import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/scrolling_calendar.dart';

const _markers = [
  (RecordKind.task, '计划记录', Icons.check_circle_outline),
  (RecordKind.progress, '科研进展', Icons.auto_stories_outlined),
  (RecordKind.mentor, '导师交流', Icons.forum_outlined),
];

Finder _day(int day) => find.byKey(ValueKey('calendar-day-2026-9-$day'));
Finder _marker(int day, RecordKind kind) =>
    find.byKey(ValueKey('calendar-dot-2026-9-$day-${kind.name}'));
Finder _legend(RecordKind kind) =>
    find.byKey(ValueKey('calendar-legend-${kind.name}'));

Future<void> _mount(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  ValueChanged<DateTime>? onSelected,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected = DateTime(2026, 9, 1);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ScrollingCalendar(
            selectedDate: selected,
            records: {
              DateTime(2026, 9, 1): RecordKind.values.toSet(),
              DateTime(2026, 9, 2): {RecordKind.task},
              DateTime(2026, 9, 3): {RecordKind.progress, RecordKind.mentor},
            },
            recordCounts: {
              DateTime(2026, 9, 1): 9999,
              DateTime(2026, 9, 2): 1,
              DateTime(2026, 9, 3): 2,
            },
            buttonStyle: const ButtonStyle(),
            onDateSelected: (date) {
              setState(() => selected = date);
              onSelected?.call(date);
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-month-list')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  testWidgets('图例与日期使用一致且不同形状的图标，只显示已有类型', (tester) async {
    await _mount(tester);
    for (final (kind, label, icon) in _markers) {
      expect(
        find.descendant(of: _legend(kind), matching: find.text(label)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: _legend(kind), matching: find.byType(Icon)),
            )
            .icon,
        icon,
      );
      expect(tester.widget<Icon>(_marker(1, kind)).icon, icon);
    }
    expect(_markers.map((entry) => entry.$3).toSet(), hasLength(3));
    expect(_marker(2, RecordKind.task), findsOneWidget);
    expect(_marker(2, RecordKind.progress), findsNothing);
    expect(_marker(2, RecordKind.mentor), findsNothing);
    expect(_marker(3, RecordKind.task), findsNothing);
    expect(_marker(3, RecordKind.progress), findsOneWidget);
    expect(_marker(3, RecordKind.mentor), findsOneWidget);
    for (final kind in RecordKind.values) {
      expect(_marker(4, kind), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期语义、选择和滚动位置保持不变', (tester) async {
    final semantics = tester.ensureSemantics();
    DateTime? selected;
    await _mount(tester, onSelected: (date) => selected = date);
    final first = tester.getSemantics(_day(1)).getSemanticsData();
    expect(first.label, '2026年9月1日，共9999条记录，有计划，有进展，有导师交流');
    expect(first.flagsCollection.isButton, isTrue);
    expect(first.flagsCollection.isSelected, Tristate.isTrue);
    expect(first.hasAction(SemanticsAction.tap), isTrue);
    final second = tester.getSemantics(_day(2)).getSemanticsData();
    expect(second.label, '2026年9月2日，共1条记录，有计划');
    expect(second.flagsCollection.isSelected, Tristate.isFalse);
    expect(tester.getSemantics(_day(4)).getSemanticsData().label, '2026年9月4日');
    final offset = _position(tester).pixels;
    await tester.tap(_day(2));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 9, 2));
    expect(_position(tester).pixels, offset);
    expect(
      tester
          .getSemantics(_day(2))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(_day(1))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final (width, scale) in [(280.0, 2.0), (320.0, 2.5)]) {
    testWidgets('窄屏 $width、字体 $scale 时图例、图标和日期可见且不溢出', (tester) async {
      DateTime? selected;
      await _mount(
        tester,
        width: width,
        scale: scale,
        onSelected: (date) => selected = date,
      );
      final calendarRect = tester.getRect(find.byType(ScrollingCalendar));
      final dayRect = tester.getRect(_day(1));
      for (final (kind, label, _) in _markers) {
        final legendRect = tester.getRect(_legend(kind));
        expect(calendarRect.contains(legendRect.topLeft), isTrue);
        expect(
          calendarRect.contains(
            legendRect.bottomRight - const Offset(.01, .01),
          ),
          isTrue,
        );
        expect(
          tester
              .getSize(
                find.descendant(of: _legend(kind), matching: find.text(label)),
              )
              .height,
          greaterThan(12),
        );
        final markerRect = tester.getRect(_marker(1, kind));
        expect(dayRect.contains(markerRect.topLeft), isTrue);
        expect(
          dayRect.contains(markerRect.bottomRight - const Offset(.01, .01)),
          isTrue,
        );
      }
      await tester.tap(_day(2));
      await tester.pumpAndSettle();
      expect(selected, DateTime(2026, 9, 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('首条记录增删后日期行高和浏览位置保持正确', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final hasRecords = ValueNotifier(false);
    addTearDown(hasRecords.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: hasRecords,
            builder: (context, present, _) => ScrollingCalendar(
              selectedDate: DateTime(2026, 9, 1),
              records: present
                  ? {DateTime(2026, 9, 1): RecordKind.values.toSet()}
                  : {},
              recordCounts: present ? {DateTime(2026, 9, 1): 3} : {},
              onDateSelected: (_) {},
              buttonStyle: const ButtonStyle(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final position = _position(tester);
    position.jumpTo(position.pixels + 132);
    await tester.pumpAndSettle();
    final originalTop = tester.getTopLeft(_day(15)).dy;
    expect(tester.getSize(_day(1)).height, closeTo(47.5, .1));
    hasRecords.value = true;
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    expect(tester.getTopLeft(_day(15)).dy, closeTo(originalTop, .1));
    expect(tester.getSize(_day(1)).height, closeTo(59.5, .1));
    expect(_marker(1, RecordKind.mentor), findsOneWidget);
    hasRecords.value = false;
    await tester.pumpAndSettle();
    expect(find.text('2026年'), findsOneWidget);
    expect(tester.getTopLeft(_day(15)).dy, closeTo(originalTop, .1));
    expect(tester.getSize(_day(1)).height, closeTo(47.5, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录数变化与外部日期跳转同时发生时仍定位目标月份', (tester) async {
    final state = ValueNotifier((DateTime(2026, 9, 1), false));
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<(DateTime, bool)>(
            valueListenable: state,
            builder: (context, value, _) => ScrollingCalendar(
              selectedDate: value.$1,
              records: value.$2
                  ? {
                      value.$1: {RecordKind.task},
                    }
                  : {},
              recordCounts: value.$2 ? {value.$1: 1} : {},
              onDateSelected: (_) {},
              buttonStyle: const ButtonStyle(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    state.value = (DateTime(2190, 12, 1), true);
    await tester.pumpAndSettle();
    expect(find.text('2190年'), findsOneWidget);
    expect(find.text('十二月'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-day-2190-12-1')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('滚动时图例固定且月份仍惰性构建', (tester) async {
    await _mount(tester);
    final legendPosition = tester.getTopLeft(
      find.byKey(const ValueKey('calendar-marker-legend')),
    );
    final position = _position(tester);
    position.jumpTo(position.pixels + 600);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('calendar-marker-legend'))),
      legendPosition,
    );
    expect(find.byType(InkWell).evaluate().length, lessThan(200));
    expect(tester.takeException(), isNull);
  });
}
