import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/scrolling_calendar.dart';

const _names = [
  '一月',
  '二月',
  '三月',
  '四月',
  '五月',
  '六月',
  '七月',
  '八月',
  '九月',
  '十月',
  '十一月',
  '十二月',
];

Future<void> _mount(
  WidgetTester tester, {
  DateTime? initial,
  double scale = 1,
  ValueChanged<DateTime>? onSelected,
  ValueNotifier<DateTime>? external,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected = initial ?? DateTime(2026, 9, 15);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            Widget calendar(DateTime date) => ScrollingCalendar(
              selectedDate: date,
              records: {DateTime(2026, 9, 15): RecordKind.values.toSet()},
              buttonStyle: glassButtonStyle(),
              onDateSelected: (date) {
                setState(() => selected = date);
                onSelected?.call(date);
              },
            );
            return external == null
                ? calendar(selected)
                : ValueListenableBuilder<DateTime>(
                    valueListenable: external,
                    builder: (context, date, _) => calendar(date),
                  );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _title(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('calendar-month'))).data!;

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('calendar-month-list')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

void main() {
  testWidgets('连续滚动按各月实际行数更新固定中文月份及跨年年份', (tester) async {
    await _mount(tester, initial: DateTime(2026, 12, 15));
    final headerY = tester
        .getTopLeft(find.byKey(const ValueKey('calendar-month')))
        .dy;
    expect(_title(tester), '十二月');
    final position = _position(tester);
    // December has five rows at 48 pixels, a 36 pixel title and 12 pixel gap.
    position.jumpTo(position.pixels + 288);
    await tester.pumpAndSettle();
    expect(_title(tester), '一月');
    expect(find.text('2027年'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('calendar-month'))).dy,
      headerY,
    );
    await tester.drag(
      find.byKey(const ValueKey('calendar-month-list')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();
    expect(_title(tester), isNot('一月'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('年份入口可选择另一年和月份并跳转', (tester) async {
    DateTime? picked;
    await _mount(tester, onSelected: (date) => picked = date);
    await tester.tap(find.byKey(const ValueKey('calendar-year')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2028年'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-pick-month-2')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2028, 2));
    expect(_title(tester), '二月');
    expect(find.text('2028年'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-day-2028-2-1')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('今天按钮滚回当前月份并回调今天', (tester) async {
    DateTime? picked;
    await _mount(
      tester,
      initial: DateTime(2020, 1),
      onSelected: (date) => picked = date,
    );
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    final today = dayOnly(DateTime.now());
    expect(picked, today);
    expect(_title(tester), _names[today.month - 1]);
    expect(find.text('${today.year}年'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('点击日期回调、保留滚动位置并显示三类记录圆点', (tester) async {
    DateTime? picked;
    await _mount(tester, onSelected: (date) => picked = date);
    final position = _position(tester);
    position.jumpTo(position.pixels + 20);
    await tester.pumpAndSettle();
    final offset = position.pixels;
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-15')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 9, 15));
    expect(position.pixels, offset);
    for (final kind in RecordKind.values) {
      expect(
        find.byKey(ValueKey('calendar-dot-2026-9-15-${kind.name}')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('calendar-day-2026-9-16')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(2026, 9, 16));
    expect(position.pixels, offset);
  });

  testWidgets('外部日期更新同步到远处月份且懒加载', (tester) async {
    final external = ValueNotifier(DateTime(2026, 9, 15));
    addTearDown(external.dispose);
    await _mount(tester, external: external);
    external.value = DateTime(2040, 2, 29);
    await tester.pumpAndSettle();
    expect(_title(tester), '二月');
    expect(find.text('2040年'), findsOneWidget);
    expect(find.byType(InkWell).evaluate().length, lessThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('390宽与1.5倍字体下日历及年月选择没有溢出', (tester) async {
    await _mount(tester, scale: 1.5, initial: DateTime(2026, 11));
    expect(tester.getSize(find.byType(ScrollingCalendar)).height, 430);
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byKey(const ValueKey('calendar-month-list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-year')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('calendar-pick-month-12')));
    await tester.pumpAndSettle();
    expect(_title(tester), '十二月');
    expect(tester.takeException(), isNull);
  });
}
