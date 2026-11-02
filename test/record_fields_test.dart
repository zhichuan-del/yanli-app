import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';

void main() {
  test('旧版备份缺少新增字段时仍能读取', () {
    const source =
        '{"version":1,"records":[{"id":"old", "kind":"task", "date":"2026-10-29T00:00:00.000", "title":"旧计划", "done":true}]}';
    final record = decodeBackup(source).single;
    expect(record.priority, '中');
    expect(record.plannedTime, isNull);
    expect(record.completedAt, isNull);
    expect(record.progressType, '其他活动');
    expect(record.durationMinutes, isNull);
  });

  test('新增字段随备份往返并在复制更改状态时保留', () {
    final completed = DateTime(2026, 10, 29, 15, 30);
    final record = ResearchRecord(
      id: 'one',
      kind: RecordKind.progress,
      date: DateTime(2026, 10, 29),
      title: '文献',
      priority: '高',
      plannedTime: '08:05',
      completedAt: completed,
      progressType: '文献阅读',
      durationMinutes: 90,
      done: true,
    );
    final restored = decodeBackup(encodeBackup([record])).single;
    final copy = restored.copyWith(done: true);
    expect(copy.priority, '高');
    expect(copy.plannedTime, '08:05');
    expect(copy.completedAt, completed);
    expect(copy.progressType, '文献阅读');
    expect(copy.durationMinutes, 90);
    expect(copy.copyWith(done: false).completedAt, isNull);
    expect(copy.copyWith(clearCompletedAt: true).completedAt, isNull);
  });

  test('不接受无效的投入时间、时间格式或枚举值', () {
    ResearchRecord make({
      int? duration,
      String? time,
      String priority = '中',
      String type = '其他活动',
    }) => ResearchRecord(
      id: 'x',
      kind: RecordKind.task,
      date: DateTime(2026),
      title: 'x',
      durationMinutes: duration,
      plannedTime: time,
      priority: priority,
      progressType: type,
    );
    expect(() => make(duration: -1), throwsArgumentError);
    expect(() => make(time: '24:00'), throwsArgumentError);
    expect(() => make(time: '8:00'), throwsArgumentError);
    expect(() => make(priority: '未知'), throwsArgumentError);
    expect(() => make(type: '未知'), throwsArgumentError);
    expect(make(duration: 0, time: '23:59').durationMinutes, 0);
  });
  test('拒绝不存在的日期和空记录 ID，保留原数据供调用方处理', () {
    const invalidDate =
        '{"version":1,"records":[{"id":"x","kind":"task","date":"2026-02-31T00:00:00.000","title":"记录"}]}';
    const emptyId =
        '{"version":1,"records":[{"id":" ","kind":"task","date":"2026-02-01T00:00:00.000","title":"记录"}]}';
    expect(() => decodeBackup(invalidDate), throwsFormatException);
    expect(() => decodeBackup(emptyId), throwsFormatException);
  });
}
