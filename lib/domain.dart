import 'dart:convert';

enum RecordKind { task, progress, mentor }

const recordPriorities = ['高', '中', '低'];
const researchTypes = ['文献阅读', '实验或调研', '论文写作', '数据或材料整理', '其他活动'];

enum MentorActionStatus { pending, inProgress, completed }

extension MentorActionStatusLabel on MentorActionStatus {
  String get label => switch (this) {
    MentorActionStatus.pending => '未处理',
    MentorActionStatus.inProgress => '处理中',
    MentorActionStatus.completed => '已完成',
  };
}

/// A mentor follow-up recorded by the user, with an independent status.
class MentorAction {
  MentorAction({
    required this.id,
    required this.text,
    bool done = false,
    MentorActionStatus? status,
  }) : status =
           status ??
           (done ? MentorActionStatus.completed : MentorActionStatus.pending) {
    if (id.trim().isEmpty || text.trim().isEmpty) {
      throw ArgumentError('导师待办的 ID 和内容不能为空');
    }
  }

  final String id;
  final String text;
  final MentorActionStatus status;
  bool get done => status == MentorActionStatus.completed;

  MentorAction copyWith({
    String? text,
    bool? done,
    MentorActionStatus? status,
  }) => MentorAction(
    id: id,
    text: text ?? this.text,
    status:
        status ??
        (done == null
            ? this.status
            : done
            ? MentorActionStatus.completed
            : MentorActionStatus.pending),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    if (status != MentorActionStatus.pending &&
        status != MentorActionStatus.completed)
      'status': status.name,
  };
  factory MentorAction.fromJson(Map<String, dynamic> json) {
    final done = json['done'] as bool;
    final status = json['status'] == null
        ? null
        : MentorActionStatus.values.byName(json['status'] as String);
    if (status != null && done != (status == MentorActionStatus.completed)) {
      throw const FormatException('导师待办状态不一致');
    }
    return MentorAction(
      id: json['id'] as String,
      text: json['text'] as String,
      done: done,
      status: status,
    );
  }
}

class ResearchRecord {
  ResearchRecord({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    this.detail = '',
    this.problem = '',
    this.next = '',
    this.done = false,
    this.priority = '中',
    this.plannedTime,
    this.completedAt,
    this.progressType = '其他活动',
    this.durationMinutes,
    this.mentorName = '',
    this.nextMeetingDate,
    this.previousFollowUp = '',
    this.previousDiscussionId,
    this.sourceDiscussionId,
    this.sourceMentorActionId,
    this.createdAt,
    this.updatedAt,
    List<MentorAction> mentorActions = const [],
  }) : mentorActions = List.unmodifiable(mentorActions) {
    if ((sourceDiscussionId == null) != (sourceMentorActionId == null) ||
        (sourceDiscussionId != null &&
            (kind != RecordKind.task ||
                sourceDiscussionId!.trim().isEmpty ||
                sourceMentorActionId!.trim().isEmpty))) {
      throw ArgumentError('计划来源必须成对且有效');
    }
    if (previousDiscussionId != null &&
        (previousDiscussionId!.trim().isEmpty || previousDiscussionId == id)) {
      throw ArgumentError('上次交流 ID 无效');
    }
    if (previousDiscussionId != null && kind != RecordKind.mentor) {
      throw ArgumentError('只有导师交流可关联上次交流');
    }
    if (mentorActions.map((action) => action.id).toSet().length !=
        mentorActions.length) {
      throw ArgumentError('导师待办 ID 不得重复');
    }
    if (!recordPriorities.contains(priority)) {
      throw ArgumentError.value(priority, 'priority', '无效的计划优先级');
    }
    if (!researchTypes.contains(progressType)) {
      throw ArgumentError.value(progressType, 'progressType', '无效的科研类型');
    }
    if (plannedTime != null &&
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(plannedTime!)) {
      throw ArgumentError.value(plannedTime, 'plannedTime', '时间必须为 HH:mm');
    }
    if (durationMinutes != null && durationMinutes! < 0) {
      throw ArgumentError.value(
        durationMinutes,
        'durationMinutes',
        '投入时间不能为负数',
      );
    }
  }

  final String id;
  final RecordKind kind;
  final DateTime date;
  final String title;
  final String detail;
  final String problem;
  final String next;
  final bool done;
  final String priority;
  final String? plannedTime;
  final DateTime? completedAt;
  final String progressType;
  final int? durationMinutes;
  final String mentorName;
  final DateTime? nextMeetingDate;
  final String previousFollowUp;
  final String? previousDiscussionId;
  final String? sourceDiscussionId;
  final String? sourceMentorActionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MentorAction> mentorActions;

  ResearchRecord copyWith({
    DateTime? date,
    String? title,
    String? detail,
    String? problem,
    String? next,
    String? sourceDiscussionId,
    String? sourceMentorActionId,
    bool clearSource = false,
    bool? done,
    String? priority,
    String? plannedTime,
    bool clearPlannedTime = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? progressType,
    int? durationMinutes,
    bool clearDurationMinutes = false,
    String? mentorName,
    DateTime? nextMeetingDate,
    bool clearNextMeetingDate = false,
    String? previousFollowUp,
    String? previousDiscussionId,
    bool clearPreviousDiscussion = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MentorAction>? mentorActions,
  }) => ResearchRecord(
    id: id,
    kind: kind,
    date: date ?? this.date,
    title: title ?? this.title,
    detail: detail ?? this.detail,
    problem: problem ?? this.problem,
    next: next ?? this.next,
    sourceDiscussionId: clearSource
        ? null
        : sourceDiscussionId ?? this.sourceDiscussionId,
    sourceMentorActionId: clearSource
        ? null
        : sourceMentorActionId ?? this.sourceMentorActionId,
    done: done ?? this.done,
    priority: priority ?? this.priority,
    plannedTime: clearPlannedTime ? null : plannedTime ?? this.plannedTime,
    completedAt: (clearCompletedAt || done == false)
        ? null
        : completedAt ?? this.completedAt,
    progressType: progressType ?? this.progressType,
    durationMinutes: clearDurationMinutes
        ? null
        : durationMinutes ?? this.durationMinutes,
    mentorName: mentorName ?? this.mentorName,
    nextMeetingDate: clearNextMeetingDate
        ? null
        : nextMeetingDate ?? this.nextMeetingDate,
    previousFollowUp: previousFollowUp ?? this.previousFollowUp,
    previousDiscussionId: clearPreviousDiscussion
        ? null
        : previousDiscussionId ?? this.previousDiscussionId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mentorActions: mentorActions ?? this.mentorActions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'date': date.toIso8601String(),
    'title': title,
    'detail': detail,
    'problem': problem,
    'next': next,
    'done': done,
    'priority': priority,
    'plannedTime': plannedTime,
    'completedAt': completedAt?.toIso8601String(),
    'progressType': progressType,
    'durationMinutes': durationMinutes,
    'mentorName': mentorName,
    'nextMeetingDate': nextMeetingDate?.toIso8601String(),
    'previousFollowUp': previousFollowUp,
    if (sourceDiscussionId != null) 'sourceDiscussionId': sourceDiscussionId,
    if (sourceMentorActionId != null)
      'sourceMentorActionId': sourceMentorActionId,
    if (previousDiscussionId != null)
      'previousDiscussionId': previousDiscussionId,
    if (createdAt != null) 'createdAt': createdAt!.toUtc().toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    'mentorActions': mentorActions.map((action) => action.toJson()).toList(),
  };
  factory ResearchRecord.fromJson(Map<String, dynamic> json) => ResearchRecord(
    id: json['id'] as String,
    kind: RecordKind.values.byName(json['kind'] as String),
    date: DateTime.parse(json['date'] as String),
    title: json['title'] as String,
    detail: json['detail'] as String? ?? '',
    problem: json['problem'] as String? ?? '',
    next: json['next'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    priority: json['priority'] as String? ?? '中',
    plannedTime: json['plannedTime'] as String?,
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String),
    progressType: json['progressType'] as String? ?? '其他活动',
    durationMinutes: json['durationMinutes'] as int?,
    mentorName: json['mentorName'] as String? ?? '',
    nextMeetingDate: json['nextMeetingDate'] == null
        ? null
        : DateTime.parse(json['nextMeetingDate'] as String),
    previousFollowUp: json['previousFollowUp'] as String? ?? '',
    previousDiscussionId: json['previousDiscussionId'] as String?,
    sourceDiscussionId: json['sourceDiscussionId'] as String?,
    sourceMentorActionId: json['sourceMentorActionId'] as String?,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String),
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.parse(json['updatedAt'] as String),
    mentorActions: json['mentorActions'] == null
        ? const []
        : (json['mentorActions'] as List)
              .map(
                (item) => MentorAction.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList(),
  );
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime weekStart(DateTime d) {
  final day = dayOnly(d);
  return day.subtract(Duration(days: day.weekday - 1));
}

String dateLabel(DateTime d) =>
    '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

class WeeklyReport {
  static String generate(List<ResearchRecord> records, DateTime date) {
    final start = weekStart(date);
    final end = start.add(const Duration(days: 6));
    final week = records.where((r) {
      final day = dayOnly(r.date);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));
    final work = <String>[];
    final issues = <String>[];
    final feedback = <String>[];
    final next = <String>[];
    for (final r in week) {
      final stamp = dateLabel(r.date);
      if (r.kind == RecordKind.task && r.done) {
        work.add('[$stamp] 已完成计划：${r.title}');
      } else if (r.kind == RecordKind.progress) {
        work.add(
          '[$stamp] ${r.title}${r.detail.isEmpty ? '' : '：${r.detail}'}',
        );
        if (r.problem.isNotEmpty) {
          issues.add('[$stamp] ${r.title}：${r.problem}');
        }
        if (r.next.isNotEmpty) next.add('[$stamp] ${r.title}：${r.next}');
      } else if (r.kind == RecordKind.mentor) {
        final details = [
          r.detail,
          r.problem,
        ].where((s) => s.isNotEmpty).join('；');
        feedback.add(
          '[$stamp] ${r.title}${details.isEmpty ? '' : '：$details'}',
        );
        if (r.next.isNotEmpty) next.add('[$stamp] ${r.title}跟进：${r.next}');
      }
    }
    String section(String heading, List<String> items) =>
        '## $heading\n${items.isEmpty ? '本周暂无相关记录' : items.map((s) => '- $s').join('\n')}';
    return [
      '# 科研周报',
      '${dateLabel(start)} - ${dateLabel(end)}',
      section('本周研究工作', work),
      section('遇到的问题', issues),
      section('导师反馈与交流结论', feedback),
      section('下一步计划', next),
    ].join('\n\n');
  }
}

String encodeBackup(List<ResearchRecord> records) => jsonEncode({
  'version': 3,
  'schemaVersion': 3,
  'exportedAt': DateTime.now().toUtc().toIso8601String(),
  'settings': <String, dynamic>{},
  'records': records.map((r) => r.toJson()).toList(),
});
List<ResearchRecord> decodeBackup(String source) {
  final data = jsonDecode(source) as Map<String, dynamic>;
  final version = data['version'];
  if ((version != 1 && version != 2 && version != 3) ||
      data['records'] is! List) {
    throw const FormatException('备份格式或版本不支持');
  }
  if (version != 1 &&
      (data['schemaVersion'] != version ||
          data['exportedAt'] is! String ||
          data['settings'] is! Map)) {
    throw const FormatException('备份元数据不完整');
  }
  if (version != 1 && DateTime.tryParse(data['exportedAt'] as String) == null) {
    throw const FormatException('备份时间无效');
  }
  if (version != 1 && (data['settings'] as Map).isNotEmpty) {
    throw const FormatException('备份包含当前版本不支持的设置');
  }
  DateTime checkedDate(Object? value) {
    if (value is! String) throw const FormatException('日期格式不正确');
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
    if (match == null) throw const FormatException('日期格式不正确');
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final checked = DateTime(year, month, day);
    if (checked.year != year || checked.month != month || checked.day != day) {
      throw const FormatException('日期不存在');
    }
    return DateTime.parse(value);
  }

  final records = (data['records'] as List).map((item) {
    final map = Map<String, dynamic>.from(item as Map);
    if (map['id'] is! String || (map['id'] as String).trim().isEmpty) {
      throw const FormatException('记录 ID 不能为空');
    }
    if (map['title'] is! String || (map['title'] as String).trim().isEmpty) {
      throw const FormatException('记录标题不能为空');
    }
    checkedDate(map['date']);
    if (map['completedAt'] != null) checkedDate(map['completedAt']);
    if (map['nextMeetingDate'] != null) checkedDate(map['nextMeetingDate']);
    if (map['createdAt'] != null) checkedDate(map['createdAt']);
    if (map['updatedAt'] != null) checkedDate(map['updatedAt']);
    if (version != 1 &&
        map['createdAt'] != null &&
        map['updatedAt'] != null &&
        DateTime.parse(
          map['updatedAt'] as String,
        ).isBefore(DateTime.parse(map['createdAt'] as String))) {
      throw const FormatException('更新时间不能早于创建时间');
    }
    return ResearchRecord.fromJson(map);
  }).toList();
  if (records.map((r) => r.id).toSet().length != records.length) {
    throw const FormatException('备份中存在重复记录');
  }
  final byId = {for (final record in records) record.id: record};
  final sourcePairs = <String>{};
  for (final record in records) {
    if (record.sourceDiscussionId != null) {
      final source = byId[record.sourceDiscussionId];
      if (source?.kind != RecordKind.mentor ||
          !source!.mentorActions.any(
            (a) => a.id == record.sourceMentorActionId,
          ) ||
          !sourcePairs.add(
            jsonEncode([
              record.sourceDiscussionId,
              record.sourceMentorActionId,
            ]),
          )) {
        throw const FormatException('计划来源不存在或重复');
      }
    }
    final previousId = record.previousDiscussionId;
    if (previousId != null && byId[previousId]?.kind != RecordKind.mentor) {
      throw const FormatException('关联的上次交流不存在');
    }
    if (previousId != null &&
        dayOnly(byId[previousId]!.date).isAfter(dayOnly(record.date))) {
      throw const FormatException('上次交流日期不能晚于当前交流');
    }
  }
  final checked = <String>{};
  for (final record in records) {
    final path = <String>{};
    String? cursor = record.id;
    while (cursor != null && !checked.contains(cursor)) {
      if (!path.add(cursor)) throw const FormatException('交流关联不能形成循环');
      cursor = byId[cursor]?.previousDiscussionId;
    }
    checked.addAll(path);
  }
  return records;
}

ResearchRecord rescheduleTask(
  ResearchRecord task,
  DateTime target,
  DateTime now,
) {
  if (task.kind != RecordKind.task || task.done) throw StateError('只能改期未完成计划');
  return task.copyWith(date: dayOnly(target), updatedAt: now.toUtc());
}

/// The edited side wins: completed maps to done; pending/inProgress map to open.
List<ResearchRecord> upsertLinkedRecord(
  List<ResearchRecord> records,
  ResearchRecord edited,
) {
  final result = [
    for (final r in records)
      if (r.id != edited.id) r,
    edited,
  ];
  return result.map((r) {
    if (edited.kind == RecordKind.task && edited.sourceDiscussionId == r.id) {
      return r.copyWith(
        updatedAt: edited.updatedAt,
        mentorActions: [
          for (final a in r.mentorActions)
            a.id == edited.sourceMentorActionId && a.done != edited.done
                ? a.copyWith(done: edited.done)
                : a,
        ],
      );
    }
    if (edited.kind == RecordKind.mentor && r.sourceDiscussionId == edited.id) {
      final actions = edited.mentorActions.where(
        (a) => a.id == r.sourceMentorActionId,
      );
      if (actions.isEmpty) {
        return r.copyWith(clearSource: true, updatedAt: edited.updatedAt);
      }
      final done = actions.first.done;
      return r.copyWith(
        done: done,
        completedAt: done ? r.completedAt ?? edited.updatedAt : null,
        updatedAt: edited.updatedAt,
      );
    }
    return r;
  }).toList();
}

List<ResearchRecord> planMentorAction(
  List<ResearchRecord> records,
  ResearchRecord discussion,
  MentorAction action,
  DateTime date,
  DateTime now,
) {
  if (!records.any(
    (r) =>
        r.id == discussion.id && r.mentorActions.any((a) => a.id == action.id),
  )) {
    throw StateError('来源事项已不存在');
  }
  if (records.any(
    (r) =>
        r.sourceDiscussionId == discussion.id &&
        r.sourceMentorActionId == action.id,
  )) {
    return List.of(records);
  }
  return [
    ...records,
    ResearchRecord(
      id: 'plan-${now.microsecondsSinceEpoch}',
      kind: RecordKind.task,
      date: dayOnly(date),
      title: action.text,
      done: action.done,
      completedAt: action.done ? now : null,
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      sourceDiscussionId: discussion.id,
      sourceMentorActionId: action.id,
    ),
  ];
}

class RecordDeletion {
  RecordDeletion(List<ResearchRecord> records, this.target)
    : affected = records
          .where(
            (r) =>
                r.previousDiscussionId == target.id ||
                r.sourceDiscussionId == target.id,
          )
          .toList();
  final ResearchRecord target;
  final List<ResearchRecord> affected;
  List<ResearchRecord> apply(List<ResearchRecord> current) => [
    for (final r in current)
      if (r.id != target.id)
        r.copyWith(
          clearPreviousDiscussion: r.previousDiscussionId == target.id,
          clearSource: r.sourceDiscussionId == target.id,
        ),
  ];
  List<ResearchRecord> restore(List<ResearchRecord> current) {
    final sourceOccupied =
        target.sourceDiscussionId != null &&
        current.any(
          (r) =>
              r.sourceDiscussionId == target.sourceDiscussionId &&
              r.sourceMentorActionId == target.sourceMentorActionId,
        );
    final sourceMissing =
        target.sourceDiscussionId != null &&
        !current.any(
          (r) =>
              r.id == target.sourceDiscussionId &&
              r.mentorActions.any((a) => a.id == target.sourceMentorActionId),
        );
    final result = [
      for (final r in current) r,
      if (!current.any((r) => r.id == target.id))
        target.copyWith(clearSource: sourceOccupied || sourceMissing),
    ];
    return result.map((r) {
      final old = affected.where((a) => a.id == r.id);
      if (old.isEmpty) return r;
      final before = old.first;
      // Later edits own their associations; restoring the target never replaces
      // a newer record or revives another deleted record.
      if (r.updatedAt != before.updatedAt) return r;
      return r.copyWith(
        previousDiscussionId: r.previousDiscussionId == null
            ? before.previousDiscussionId
            : null,
        sourceDiscussionId: r.sourceDiscussionId == null
            ? before.sourceDiscussionId
            : null,
        sourceMentorActionId: r.sourceDiscussionId == null
            ? before.sourceMentorActionId
            : null,
      );
    }).toList();
  }
}
