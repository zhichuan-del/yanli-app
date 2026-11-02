import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('恢复时先显示数量并要求确认，取消不会覆盖原数据', (tester) async {
    final old = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '原记录',
      ),
    ]);
    final replacement = encodeBackup([
      ResearchRecord(
        id: '2',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '新记录',
      ),
    ]);
    SharedPreferences.setMockInitialValues({'yanli_records_v1': old});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('恢复备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('恢复备份'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, replacement);
    await tester.tap(find.widgetWithText(FilledButton, '恢复'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 条记录'), findsOneWidget);
    expect(prefs.getString('yanli_records_v1'), old);
    await tester.tap(find.text('取消').last);
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), old);
  });
}
