import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('未保存的输入关闭时需要确认，取消后保留内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.task,
            initialDate: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '待保存内容');
    await tester.tap(find.byTooltip('关闭编辑'));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('待保存内容'), findsOneWidget);
  });

  testWidgets('进展至少填写成果、问题或下一步其中一项', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.progress,
            initialDate: DateTime(2026, 10, 29),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, '测试进展');
    await tester.ensureVisible(find.text('保存科研进展'));
    await tester.tap(find.text('保存科研进展'));
    await tester.pumpAndSettle();
    expect(find.text('请至少填写成果、问题或下一步中的一项'), findsOneWidget);
  });
  testWidgets('进展补充项可折叠，填写内容仍会保存', (tester) async {
    ResearchRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.progress,
            initialDate: DateTime(2026, 10, 29),
            onSave: (record) async {
              saved = record;
              return true;
            },
          ),
        ),
      ),
    );
    expect(find.text('成果、问题或下一步至少填写一项。'), findsOneWidget);
    expect(find.text('遇到的问题'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '测试进展');
    await tester.tap(find.text('填写问题、下一步和投入时间'));
    await tester.pumpAndSettle();
    final problem = find.widgetWithText(TextField, '遇到的问题');
    await tester.ensureVisible(problem);
    await tester.enterText(problem, '样本不足');
    await tester.ensureVisible(find.text('收起补充信息'));
    await tester.tap(find.text('收起补充信息'));
    await tester.pumpAndSettle();
    expect(find.text('遇到的问题'), findsNothing);
    await tester.ensureVisible(find.text('保存科研进展'));
    await tester.tap(find.text('保存科研进展'));
    await tester.pumpAndSettle();
    expect(saved?.problem, '样本不足');
  });

  testWidgets('补充项语音识别期间不能收起，取消后可以收起', (tester) async {
    const channel = MethodChannel('org.yanli/voice');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final result = Completer<String?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'start') return result.future;
      if (call.method == 'cancel') result.complete(null);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.progress,
            initialDate: DateTime(2026, 10, 29),
          ),
        ),
      ),
    );
    await tester.tap(find.text('填写问题、下一步和投入时间'));
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextField, '遇到的问题');
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: field, matching: find.byTooltip('语音输入')),
    );
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('收起补充信息'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('取消语音'));
    await tester.pump();
    await tester.tap(find.text('取消语音'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text('收起补充信息'),
              matching: find.byType(TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('编辑已有进展时自动展开已填写的补充信息', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.progress,
            initialDate: DateTime(2026),
            record: ResearchRecord(
              id: 'p',
              kind: RecordKind.progress,
              date: DateTime(2026),
              title: '已有进展',
              next: '整理数据',
              durationMinutes: 25,
            ),
          ),
        ),
      ),
    );
    expect(find.text('收起补充信息'), findsOneWidget);
    expect(find.text('下一步计划'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '下一步计划'))
          .controller!
          .text,
      '整理数据',
    );
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '投入时间（分钟，选填）'))
          .controller!
          .text,
      '25',
    );
  });

  testWidgets('计划编辑显示原优先级，进展编辑显示原科研类型', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.task,
            initialDate: DateTime(2026),
            record: ResearchRecord(
              id: '1',
              kind: RecordKind.task,
              date: DateTime(2026),
              title: '计划',
              priority: '高',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('补充日期和分类'));
    await tester.pumpAndSettle();
    expect(find.text('优先级'), findsOneWidget);
    expect(find.text('高'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordEditor(
            key: const ValueKey('progress'),
            kind: RecordKind.progress,
            initialDate: DateTime(2026),
            record: ResearchRecord(
              id: '2',
              kind: RecordKind.progress,
              date: DateTime(2026),
              title: '进展',
              progressType: '文献阅读',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.textContaining('补充日期和分类'));
    await tester.pumpAndSettle();
    expect(find.text('科研类型'), findsOneWidget);
    expect(find.text('文献阅读'), findsOneWidget);
  });
}
