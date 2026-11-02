import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/demo_records.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/recycle_bin.dart';

void main() {
  test('12条示例覆盖5类型、连续12个日历日及完整模拟字段，合法往返', () {
    final now = DateTime(2026, 11, 1, 15);
    final records = generateDemoProgress(now);
    expect(records, hasLength(12));
    expect(records.map((r) => r.id).toSet(), hasLength(12));
    expect(records.map((r) => r.progressType).toSet(), researchTypes.toSet());
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      expect(r.kind, RecordKind.progress);
      expect(r.date, DateTime(2026, 11, 1 - 11 + i));
      for (final text in [r.title, r.detail, r.problem, r.next]) {
        expect(text, startsWith('【测试】'));
      }
      expect(r.durationMinutes, greaterThan(0));
      expect(r.createdAt, now.toUtc());
      expect(r.updatedAt, now.toUtc());
    }
    final decoded = LocalRecordSnapshot.decode(
      LocalRecordSnapshot(records).encode(),
    );
    expect(
      decoded.records.map((r) => r.toJson()),
      records.map((r) => r.toJson()),
    );
  });

  test('固定ID跨日期去重并保留现有记录，回收站ID也跳过', () {
    final now = DateTime(2026, 11, 1);
    final demo = generateDemoProgress(now);
    final existing = [
      ResearchRecord(
        id: 'real',
        kind: RecordKind.progress,
        date: now,
        title: '真实记录',
      ),
      demo.first.copyWith(title: '用户修改过的测试标题'),
    ];
    final before = existing.map((r) => r.toJson()).toList();
    final additions = missingDemoProgress(
      existing,
      now: now,
      reservedIds: [demo[1].id],
    );
    expect(additions, hasLength(10));
    expect(existing.map((r) => r.toJson()).toList(), before);
    expect(
      missingDemoProgress(
        [...existing, ...additions],
        now: DateTime(2027),
        reservedIds: [demo[1].id],
      ),
      isEmpty,
    );
    expect(
      generateDemoProgress(DateTime(2027)).map((r) => r.id),
      demo.map((r) => r.id),
    );
  });
}
