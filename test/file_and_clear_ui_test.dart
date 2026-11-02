import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.yanli/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  testWidgets('导出备份把当前 JSON 交给系统文件选择器', (tester) async {
    MethodCall? requested;
    messenger.setMockMethodCallHandler(channel, (call) async {
      requested = call;
      return true;
    });
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      YanliApp(prefs: await SharedPreferences.getInstance()),
    );
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('导出备份文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出备份文件'));
    await tester.pumpAndSettle();
    expect(requested?.method, 'export');
    expect((requested?.arguments as Map)['mime'], 'application/json');
    expect((requested?.arguments as Map)['content'], contains('"records"'));
  });
  testWidgets('清空数据需要两次确认，取消第二次不会清空', (tester) async {
    final raw = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '需要保留',
      ),
    ]);
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('清空数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    expect(find.text('确认清空'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString('yanli_records_v1'), raw);
  });
  testWidgets('确认两次后清空本地记录', (tester) async {
    final raw = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '记录',
      ),
    ]);
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('清空数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();
    expect(decodeBackup(prefs.getString('yanli_records_v1')!), isEmpty);
  });
  testWidgets('从文件恢复前显示确认并保留当前数据', (tester) async {
    final raw = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '旧记录',
      ),
    ]);
    final incoming = encodeBackup([
      ResearchRecord(
        id: '2',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '新记录',
      ),
    ]);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    expect(find.text('确认覆盖'), findsOneWidget);
    expect(prefs.getString('yanli_records_v1'), raw);
    final confirm = find.widgetWithText(FilledButton, '确认覆盖');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.text('导出当前备份'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(find.text('确认覆盖'));
    await tester.pumpAndSettle();
    expect(
      decodeBackup(prefs.getString('yanli_records_v1')!).single.title,
      '新记录',
    );
  });
  testWidgets('备份导出取消时不能确认覆盖', (tester) async {
    final raw = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '旧记录',
      ),
    ]);
    final incoming = encodeBackup([]);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : false,
    );
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出当前备份'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认覆盖'))
          .onPressed,
      isNull,
    );
    expect(prefs.getString('yanli_records_v1'), raw);
  });

  testWidgets('导出汇报是含日期范围的 Markdown 文本', (tester) async {
    MethodCall? call;
    messenger.setMockMethodCallHandler(channel, (request) async {
      call = request;
      return true;
    });
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      YanliApp(prefs: await SharedPreferences.getInstance()),
    );
    await tester.tap(find.text('周报'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('导出 Markdown 文件'));
    await tester.tap(find.text('导出 Markdown 文件'));
    await tester.pumpAndSettle();
    expect(call?.method, 'export');
    final args = call!.arguments as Map;
    expect(args['mime'], 'text/markdown');
    expect(args['filename'], endsWith('.md'));
    expect(args['content'], contains('# 科研汇报'));
  });
  testWidgets('无效文件不会显示覆盖确认，也不会更改记录', (tester) async {
    final raw = encodeBackup([
      ResearchRecord(
        id: '1',
        kind: RecordKind.task,
        date: DateTime(2026),
        title: '原记录',
      ),
    ]);
    messenger.setMockMethodCallHandler(channel, (_) async => '无效备份');
    SharedPreferences.setMockInitialValues({'yanli_records_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(YanliApp(prefs: prefs));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    expect(find.text('确认覆盖'), findsNothing);
    expect(prefs.getString('yanli_records_v1'), raw);
    expect(find.textContaining('备份内容无效'), findsOneWidget);
  });
}
