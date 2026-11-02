import 'dart:convert';

import 'domain.dart';

const maxRetentionDays = 3650;

bool isValidRetentionDays(Object? days) =>
    days is int && days >= 1 && days <= maxRetentionDays;

class TrashedRecord {
  TrashedRecord(this.deletion, this.deletedAt);
  final RecordDeletion deletion;
  final DateTime deletedAt;
  ResearchRecord get record => deletion.target;
  bool expired(DateTime now, int days) =>
      !now.isBefore(deletedAt.add(Duration(days: days)));

  Map<String, dynamic> toJson() => {
    'record': record.toJson(),
    'affected': deletion.affected.map((r) => r.toJson()).toList(),
    'deletedAt': deletedAt.toUtc().toIso8601String(),
  };

  List<ResearchRecord> restore(List<ResearchRecord> current) {
    final merged = deletion.restore(current);
    try {
      return decodeBackup(encodeBackup(merged));
    } catch (_) {
      // A source, previous discussion, or its dates may have changed since
      // deletion. Keep current records intact when associations cannot return.
      return [
        ...current,
        if (!current.any((r) => r.id == record.id))
          record.copyWith(clearSource: true, clearPreviousDiscussion: true),
      ];
    }
  }
}

class LocalRecordSnapshot {
  LocalRecordSnapshot(this.records, {this.trash = const [], this.days = 3});
  final List<ResearchRecord> records;
  final List<TrashedRecord> trash;
  final int days;

  String encode() {
    final data = jsonDecode(encodeBackup(records)) as Map<String, dynamic>;
    data['localRecycleBin'] = {
      'version': 1,
      'days': days,
      'entries': trash.map((entry) => entry.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  factory LocalRecordSnapshot.decode(String source) {
    final records = decodeBackup(source);
    final data = jsonDecode(source) as Map<String, dynamic>;
    if (!data.containsKey('localRecycleBin')) {
      return LocalRecordSnapshot(records);
    }
    final bin = data['localRecycleBin'];
    if (bin is! Map ||
        bin['version'] != 1 ||
        !isValidRetentionDays(bin['days']) ||
        bin['entries'] is! List) {
      throw const FormatException('回收站格式无效');
    }
    final ids = records.map((r) => r.id).toSet();
    final trash = <TrashedRecord>[];
    for (final raw in bin['entries'] as List) {
      final entry = Map<String, dynamic>.from(raw as Map);
      final deletedAt = DateTime.parse(entry['deletedAt'] as String);
      final target = ResearchRecord.fromJson(
        Map<String, dynamic>.from(entry['record'] as Map),
      );
      final affected = (entry['affected'] as List)
          .map(
            (r) => ResearchRecord.fromJson(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
      // Validate record fields through the existing strict backup decoder.
      // Historical links can point to records subsequently removed.
      final historical = [target, ...affected];
      decodeBackup(
        encodeBackup([
          for (final r in historical)
            r.copyWith(clearSource: true, clearPreviousDiscussion: true),
        ]),
      );
      if (!ids.add(target.id) ||
          affected.any(
            (r) =>
                r.previousDiscussionId != target.id &&
                r.sourceDiscussionId != target.id,
          )) {
        throw const FormatException('回收站记录重复或关联无效');
      }
      trash.add(TrashedRecord(RecordDeletion(affected, target), deletedAt));
    }
    return LocalRecordSnapshot(records, trash: trash, days: bin['days'] as int);
  }
}
