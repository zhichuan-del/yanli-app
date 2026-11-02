import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/demo_records.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/recycle_bin.dart';

const storageKey = 'yanli_records_v1';

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.text('我的'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('开发与测试'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('添加测试进展'));
}

Future<void> confirmDemo(WidgetTester tester) async {
  await tester.tap(find.text('添加测试进展'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认添加'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('设置确认追加保留真实记录与回收站，重启重复新增0条', (tester) async {
    final now = DateTime.now();
    final real = ResearchRecord(
      id: 'real',
      kind: RecordKind.progress,
      date: now,
      title: '真实科研记录',
      detail: '真实正文',
    );
    final recycled = generateDemoProgress(now).first;
    final entry = TrashedRecord(
      RecordDeletion([recycled], recycled),
      now.toUtc(),
    );
    final initial = LocalRecordSnapshot(
      [real],
      trash: [entry],
      days: 30,
    ).encode();
    SharedPreferences.setMockInitialValues({storageKey: initial});
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    Future<bool> write(String text) async {
      writes++;
      return prefs.setString(storageKey, text);
    }

    Future<void> mount() => tester.pumpWidget(
      MaterialApp(
        home: HomePage(prefs: prefs, writeSnapshot: write),
      ),
    );
    await mount();
    await tester.pumpAndSettle();
    expect(writes, 0);
    await openSettings(tester);
    await tester.tap(find.text('添加测试进展'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(prefs.getString(storageKey), initial);
    await confirmDemo(tester);
    expect(find.textContaining('实际新增11条'), findsOneWidget);
    expect(find.text('科研进展'), findsOneWidget);
    var saved = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(saved.records, hasLength(12));
    expect(saved.records.first.toJson(), real.toJson());
    expect(saved.trash.single.toJson(), entry.toJson());
    expect(saved.days, 30);
    await tester.pumpWidget(const SizedBox());
    await mount();
    await tester.pumpAndSettle();
    await openSettings(tester);
    await confirmDemo(tester);
    expect(find.textContaining('实际新增0条'), findsOneWidget);
    expect(writes, 1);
    saved = LocalRecordSnapshot.decode(prefs.getString(storageKey)!);
    expect(saved.records, hasLength(12));
  });

  testWidgets('进展空页入口保存失败不变，重试成功新增12条', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (text) async {
            writes++;
            if (writes == 1) return false;
            return prefs.setString(storageKey, text);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('进展'));
    await tester.pumpAndSettle();
    await confirmDemo(tester);
    expect(find.textContaining('测试进展保存失败，实际新增0条'), findsOneWidget);
    expect(find.text('已记录 0 条'), findsOneWidget);
    expect(prefs.getString(storageKey), isNull);
    await confirmDemo(tester);
    expect(find.textContaining('实际新增12条'), findsOneWidget);
    expect(find.text('已记录 12 条'), findsOneWidget);
    expect(
      LocalRecordSnapshot.decode(prefs.getString(storageKey)!).records,
      hasLength(12),
    );
    expect(writes, 2);
  });

  testWidgets('坏数据时两个入口禁止写入并保留原始数据', (tester) async {
    SharedPreferences.setMockInitialValues({storageKey: 'bad-data'});
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (_) async {
            writes++;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '添加测试进展'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('进展'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '添加测试进展'))
          .onPressed,
      isNull,
    );
    expect(writes, 0);
    expect(prefs.getString(storageKey), 'bad-data');
  });
}
