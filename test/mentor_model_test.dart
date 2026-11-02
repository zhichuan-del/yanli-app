import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';

void main() {
  test('导师字段与待办在备份中完整往返，保留每条状态及稳定 ID', () {
    const input =
        '{"version":1,"records":[{"id":"meeting1","kind":"mentor","date":"2026-10-29T00:00:00.000","title":"组会","mentorName":"王老师","nextMeetingDate":"2026-11-05T00:00:00.000","previousFollowUp":"已完成文献整理","mentorActions":[{"id":"todo1","text":"补充对照","done":false},{"id":"todo2","text":"复核结果","done":true}]}]}';
    final stored = decodeBackup(input).single.toJson();
    expect(stored['mentorName'], '王老师');
    expect(stored['nextMeetingDate'], '2026-11-05T00:00:00.000');
    expect(stored['previousFollowUp'], '已完成文献整理');
    expect(stored['mentorActions'], [
      {'id': 'todo1', 'text': '补充对照', 'done': false},
      {'id': 'todo2', 'text': '复核结果', 'done': true},
    ]);
  });
  test('旧导师记录保留旧跟进文字，不推断完成状态或创建重复事项', () {
    const input =
        '{"version":1,"records":[{"id":"old","kind":"mentor","date":"2026-10-29T00:00:00.000","title":"讨论","next":"修改方案"}]}';
    final record = decodeBackup(input).single;
    expect(record.next, '修改方案');
    expect(record.mentorActions, isEmpty);
    expect(record.nextMeetingDate, isNull);
    final restored = decodeBackup(encodeBackup([record])).single;
    expect(restored.next, '修改方案');
    expect(restored.mentorActions, isEmpty);
  });

  test('事项状态切换保持 ID、顺序及其他字段并可单独清除下次日期', () {
    final record = ResearchRecord(
      id: 'meeting',
      kind: RecordKind.mentor,
      date: DateTime(2026, 10, 29),
      title: '课题讨论',
      mentorName: '林老师',
      nextMeetingDate: DateTime(2026, 11, 5),
      previousFollowUp: '已查文献',
      next: '旧笔记',
      mentorActions: [
        MentorAction(id: 'a', text: '读论文'),
        MentorAction(id: 'b', text: '做实验'),
      ],
    );
    final changed = record.copyWith(
      mentorActions: [
        record.mentorActions.first.copyWith(done: true),
        record.mentorActions.last,
      ],
      clearNextMeetingDate: true,
    );
    expect(changed.mentorActions.map((item) => item.id), ['a', 'b']);
    expect(changed.mentorActions.map((item) => item.done), [true, false]);
    expect(changed.mentorName, '林老师');
    expect(changed.previousFollowUp, '已查文献');
    expect(changed.next, '旧笔记');
    expect(changed.nextMeetingDate, isNull);
    expect(record.mentorActions.first.done, false);
    expect(
      () => changed.mentorActions.add(MentorAction(id: 'c', text: 'x')),
      throwsUnsupportedError,
    );
  });

  test('拒绝空待办、重复待办 ID、无效下次日期和错误状态', () {
    expect(() => MentorAction(id: ' ', text: '内容'), throwsArgumentError);
    expect(() => MentorAction(id: 'a', text: '  '), throwsArgumentError);
    expect(
      () => ResearchRecord(
        id: 'm',
        kind: RecordKind.mentor,
        date: DateTime(2026),
        title: '讨论',
        mentorActions: [
          MentorAction(id: 'a', text: '一'),
          MentorAction(id: 'a', text: '二'),
        ],
      ),
      throwsArgumentError,
    );
    const badDate =
        '{"version":1,"records":[{"id":"x","kind":"mentor","date":"2026-10-29T00:00:00.000","title":"讨论","nextMeetingDate":"2026-02-31T00:00:00.000"}]}';
    expect(() => decodeBackup(badDate), throwsFormatException);
    const badStatus =
        '{"version":1,"records":[{"id":"x","kind":"mentor","date":"2026-10-29T00:00:00.000","title":"讨论","mentorActions":[{"id":"1","text":"任务","done":"是"}]}]}';
    expect(() => decodeBackup(badStatus), throwsA(isA<TypeError>()));
  });
}
