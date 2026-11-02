import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/range_report.dart';
import 'package:yanli_app/report_summary.dart';

void main() {
  testWidgets('总结可以生成、编辑、保存并恢复，重新生成需确认', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final report = RangeReport.generate(
      records: [],
      start: DateTime(2026, 11, 2),
      end: DateTime(2026, 11, 8),
    );
    Widget app() => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReportSummary(
            report: report,
            prefs: prefs,
            onOpenSource: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.tap(find.text('生成总结'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(4));
    await tester.enterText(find.byType(TextField).first, '手动补充的总结');
    await tester.tap(find.text('保存总结草稿'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新生成总结'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '手动补充的总结',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      '手动补充的总结',
    );
  });
}
