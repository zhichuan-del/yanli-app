import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';

void main() {
  test('周报只整理选中周的已记录内容，未完成的计划不会被当成成果', () {
    final rows = [
      ResearchRecord(
        id: '1',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 27),
        title: '文献阅读',
        detail: '读完两篇论文',
        problem: '实验条件尚未确定',
        next: '整理实验方案',
      ),
      ResearchRecord(
        id: '2',
        kind: RecordKind.task,
        date: DateTime(2026, 10, 28),
        title: '整理笔记',
        done: true,
      ),
      ResearchRecord(
        id: '3',
        kind: RecordKind.task,
        date: DateTime(2026, 10, 28),
        title: '尚未完成的任务',
      ),
      ResearchRecord(
        id: '4',
        kind: RecordKind.mentor,
        date: DateTime(2026, 10, 29),
        title: '课题讨论',
        detail: '建议先明确指标',
        next: '修改方案',
      ),
      ResearchRecord(
        id: '5',
        kind: RecordKind.progress,
        date: DateTime(2026, 10, 19),
        title: '上周记录',
        detail: '旧内容',
      ),
    ];
    final report = WeeklyReport.generate(rows, DateTime(2026, 10, 29));
    expect(report, contains('2026.10.26 - 2026.11.01'));
    expect(report, contains('读完两篇论文'));
    expect(report, contains('整理笔记'));
    expect(report, contains('实验条件尚未确定'));
    expect(report, contains('建议先明确指标'));
    expect(report, contains('修改方案'));
    expect(report, isNot(contains('尚未完成的任务')));
    expect(report, isNot(contains('旧内容')));
  });
  test('备份可以完整还原，格式不对时拒绝恢复', () {
    final row = ResearchRecord(
      id: 'a',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '交流',
      detail: '反馈',
    );
    final restored = decodeBackup(encodeBackup([row]));
    expect(restored.single.detail, '反馈');
    expect(restored.single.kind, RecordKind.mentor);
    expect(
      () => decodeBackup('{"version":2,"records":[]}'),
      throwsFormatException,
    );
  });
}
