import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('保存失败时编辑器保留输入，可重试并成功', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (text) async {
            attempts++;
            if (attempts == 1) return false;
            return prefs.setString('yanli_records_v1', text);
          },
        ),
      ),
    );
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
    final field = find
        .descendant(
          of: find.byType(RecordEditor),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(field, '保留的草稿');
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditor), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '保留的草稿');
    expect(find.textContaining('保存未确认'), findsOneWidget);
    expect(find.text('复制上次保存草稿'), findsOneWidget);
    await tester.ensureVisible(find.text('复制上次保存草稿'));
    await tester.tap(find.text('复制上次保存草稿'));
    await tester.pumpAndSettle();
    expect(copied, contains('保留的草稿'));
    expect(copied, contains('不是完整备份'));
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordEditor), findsNothing);
    expect(prefs.getString('yanli_records_v1'), contains('保留的草稿'));
  });
  testWidgets('写入期间锁定编辑器，返回不会关闭，成功后关闭', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final result = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(prefs: prefs, writeSnapshot: (_) => result.future),
      ),
    );
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
    final field = find
        .descendant(
          of: find.byType(RecordEditor),
          matching: find.byType(TextField),
        )
        .first;
    await tester.enterText(field, '等待保存');
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pump();
    final editor = find.byType(RecordEditor);
    final absorbers = tester.widgetList<AbsorbPointer>(
      find.descendant(of: editor, matching: find.byType(AbsorbPointer)),
    );
    expect(absorbers.any((widget) => widget.absorbing), true);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(editor, findsOneWidget);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
  });
}
