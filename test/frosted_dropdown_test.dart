import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/frosted_dropdown.dart';

void main() {
  testWidgets('磨砂下拉当前值、选择、键盘取消与禁用', (tester) async {
    var value = '乙';
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return FrostedDropdown<String>(
                    initialValue: value,
                    decoration: const InputDecoration(labelText: '类型'),
                    items: ['甲', '乙', '丙']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: enabled
                        ? (v) => setState(() => value = v!)
                        : null,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    final picker = find.byType(FrostedDropdown<String>);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final surface = find.byType(FrostedMenuSurface);
    final filter = tester.widget<BackdropFilter>(
      find.descendant(of: surface, matching: find.byType(BackdropFilter)),
    );
    expect(filter.filter, ImageFilter.blur(sigmaX: 12, sigmaY: 12));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, '丙');
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(value, '丙');
    expect(surface, findsNothing);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(value, '丙');
    expect(surface, findsNothing);
    update(() => enabled = false);
    await tester.pump();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(surface, findsNothing);
  });

  testWidgets('窄屏大字长菜单可滚动选择', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var value = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setState) => FrostedDropdown<int>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: '科研类型'),
                  items: List.generate(
                    30,
                    (i) => DropdownMenuItem(value: i, child: Text('选项$i')),
                  ),
                  onChanged: (v) => setState(() => value = v!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(FrostedDropdown<int>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('选项29'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选项29'));
    await tester.pumpAndSettle();
    expect(value, 29);
    expect(tester.takeException(), isNull);
  });
}
