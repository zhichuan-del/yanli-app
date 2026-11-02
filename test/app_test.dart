import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/domain.dart';

void main() {
  testWidgets('新增计划后保存到本地，并可标记完成', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
    await tester.enterText(find.byType(TextField).first, '阅读文献');
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(find.text('阅读文献'), findsOneWidget);
    expect(
      decodeBackup(prefs.getString('yanli_records_v1')!).single.done,
      false,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(
      decodeBackup(prefs.getString('yanli_records_v1')!).single.done,
      true,
    );
  });
  testWidgets('科研进展保存后会进入本周周报', (tester) async {
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('进展'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建'));
    await tester.pumpAndSettle();
    final editorFields = find.descendant(
      of: find.byType(RecordEditor),
      matching: find.byType(TextField),
    );
    await tester.enterText(editorFields.first, '阅读论文');
    await tester.enterText(editorFields.at(1), '整理了研究方法');
    await tester.ensureVisible(find.text('保存科研进展'));
    await tester.tap(find.text('保存科研进展'));
    await tester.pumpAndSettle();
    expect(
      decodeBackup(prefs.getString('yanli_records_v1')!).single.detail,
      '整理了研究方法',
    );
    await tester.tap(find.text('周报'));
    await tester.pumpAndSettle();
    expect(find.text('整理了研究方法'), findsOneWidget);
    expect(find.text('查看进展：阅读论文'), findsOneWidget);
    expect(find.text('本期完成的研究工作'), findsOneWidget);
    expect(find.text('# 科研汇报'), findsNothing);
    await tester.tap(find.text('复制周报'));
    await tester.pumpAndSettle();
    expect(copied, contains('# 科研汇报'));
    expect(copied, contains('阅读论文'));
    expect(copied, contains('整理了研究方法'));
  });
}
