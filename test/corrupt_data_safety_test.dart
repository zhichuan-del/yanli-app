import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('原始数据损坏时不能创建记录覆盖原始内容', (tester) async {
    const raw = '{损坏但仍需保留}';
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.scrollUntilVisible(
      find.text('新建计划'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('calendar-agenda-list')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(find.text('新建计划'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('原始数据'), findsOneWidget);
    expect(prefs.getString('yanli_records_v1'), raw);
    expect(find.byType(RecordEditor), findsNothing);
  });
}
