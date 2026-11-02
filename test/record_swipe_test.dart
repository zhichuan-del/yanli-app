import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  for (final kind in RecordKind.values) {
    testWidgets('${kind.name}右滑取消保留、确认后持久化删除', (tester) async {
      final record = ResearchRecord(
        id: 'swipe',
        kind: kind,
        date: DateTime.now(),
        title: '右滑测试记录',
      );
      final snapshot = encodeBackup([record]);
      SharedPreferences.setMockInitialValues({'yanli_records_v1': snapshot});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(YanliApp(prefs: prefs));
      if (kind != RecordKind.task) {
        await tester.tap(find.text(kind == RecordKind.progress ? '进展' : '交流'));
        await tester.pumpAndSettle();
      }
      final row = find.byKey(const ValueKey('record-swipe-swipe'));
      if (kind == RecordKind.task) {
        await tester.scrollUntilVisible(
          row,
          140,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('calendar-agenda-list')),
            matching: find.byType(Scrollable),
          ),
        );
      } else {
        await tester.ensureVisible(row);
      }
      await tester.pumpAndSettle();
      await tester.drag(row, const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(find.text('删除这条记录？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(prefs.getString('yanli_records_v1'), snapshot);
      await tester.drag(row, const Offset(650, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '删除'));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(decodeBackup(prefs.getString('yanli_records_v1')!), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('右滑确认但保存失败时保留记录，更多菜单可取消', (tester) async {
    final snapshot = encodeBackup([
      ResearchRecord(
        id: 'failure',
        kind: RecordKind.mentor,
        date: DateTime.now(),
        title: '不能丢失的记录',
      ),
    ]);
    SharedPreferences.setMockInitialValues({'yanli_records_v1': snapshot});
    final prefs = await SharedPreferences.getInstance();
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          writeSnapshot: (_) async {
            writes++;
            return false;
          },
        ),
      ),
    );
    await tester.tap(find.text('交流'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('record-swipe-failure'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_horiz)),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.drag(row, const Offset(650, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(row, findsOneWidget);
    expect(prefs.getString('yanli_records_v1'), snapshot);
    expect(find.textContaining('删除未确认成功'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
