import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.yanli/voice');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> openEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.task,
            initialDate: DateTime(2026, 10, 29),
          ),
        ),
      ),
    );
  }

  for (final kind in RecordKind.values) {
    testWidgets('${kind.name} 所有输入框在语音结束后可以继续键盘输入', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'start' ? '语音' : null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecordEditor(kind: kind, initialDate: DateTime(2026, 11, 2)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expand = find.text('填写问题、下一步和投入时间');
      if (expand.evaluate().isNotEmpty) {
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
      }
      final addAction = find.text('添加跟进事项');
      if (addAction.evaluate().isNotEmpty) {
        await tester.ensureVisible(addAction);
        await tester.tap(addAction);
        await tester.pumpAndSettle();
      }
      final fields = find.byType(TextField);
      for (var i = 0; i < fields.evaluate().length; i++) {
        final field = fields.at(i);
        await tester.ensureVisible(field);
        final widget = tester.widget<TextField>(field);
        final numeric = widget.keyboardType == TextInputType.number;
        await tester.enterText(field, numeric ? '10' : '原文');
        if (!numeric) {
          final mic = find.descendant(
            of: field,
            matching: find.byTooltip('语音输入'),
          );
          await tester.tap(mic);
          await tester.pumpAndSettle();
          expect(tester.testTextInput.isVisible, isFalse);
        }
        expect(tester.widget<TextField>(field).readOnly, isFalse);
        await tester.enterText(field, numeric ? '20' : '键盘继续输入');
        expect(widget.controller!.text, numeric ? '20' : '键盘继续输入');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('语音识别文字插入已有文本的光标位置', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'start' ? '语音' : null,
    );
    await openEditor(tester);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '前后');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pumpAndSettle();
    expect(controller.text, '前语音后');
  });

  testWidgets('取消语音输入后保留原文字', (tester) async {
    final result = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return result.future;
      if (call.method == 'cancel') result.complete('不应插入');
      return null;
    });
    await openEditor(tester);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '原文字');
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pump();
    await tester.tap(find.text('取消语音'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '原文字');
  });

  testWidgets('语音识别失败时提示并保留原文字', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') {
        throw PlatformException(code: 'unavailable', message: '离线语音不可用');
      }
      return null;
    });
    await openEditor(tester);
    final field = find.byType(TextField).first;
    await tester.enterText(field, '原文字');
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '原文字');
    expect(find.textContaining('离线语音不可用'), findsOneWidget);
  });
  testWidgets('标题已达上限时提示语音内容未插入', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'start' ? '新增文字' : null,
    );
    await openEditor(tester);
    final field = find.byType(TextField).first;
    final original = '甲' * 100;
    await tester.enterText(field, original);
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, original);
    expect(find.textContaining('字数上限'), findsOneWidget);
  });

  testWidgets('识别期间锁定目标输入框并在取消后恢复', (tester) async {
    final result = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return result.future;
      if (call.method == 'cancel') result.complete(null);
      return null;
    });
    await openEditor(tester);
    final field = find.byType(TextField).first;
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pump();
    expect(tester.widget<TextField>(field).readOnly, true);
    await tester.tap(find.text('取消语音'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).readOnly, false);
  });
  testWidgets('语音识别未结束时不能保存，避免遗漏识别内容', (tester) async {
    final result = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return result.future;
      if (call.method == 'cancel') result.complete(null);
      return null;
    });
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, '已有文字');
    await tester.tap(find.byTooltip('语音输入').first);
    await tester.pump();
    await tester.ensureVisible(find.text('保存计划'));
    await tester.tap(find.text('保存计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('先完成或取消语音'), findsOneWidget);
    expect(find.byType(RecordEditor), findsOneWidget);
    await tester.tap(find.text('取消语音'));
    await tester.pumpAndSettle();
  });
}
