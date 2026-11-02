import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain.dart';

/// Drafts deliberately live outside snapshots and exported backups. All writes,
/// including removals, share one queue so a delayed write cannot revive a draft.
class EditorDrafts {
  EditorDrafts(this.prefs, {this.writeValue});
  final SharedPreferences prefs;
  final Future<bool> Function(String, String)? writeValue;
  static const prefix = 'yanli_editor_draft_v1_';
  static final _queues = Expando<_DraftQueue>();
  _DraftQueue get _queue => _queues[prefs] ??= _DraftQueue();
  static String key(RecordKind kind, String? id) => '$prefix${id == null ? 'new_${kind.name}' : 'edit_$id'}';
  static String? fingerprint(ResearchRecord? record) => record == null ? null : jsonEncode(record.toJson());

  Map<String, dynamic>? read(String key) {
    final raw = prefs.getString(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  String readable(String key) {
    try {
      final data = read(key);
      if (data == null) return '草稿已清除';
      final labels = {'title': '标题', 'detail': '内容', 'problem': '问题或结论', 'next': '下一步',
        'date': '日期', 'priority': '优先级', 'progressType': '科研类型', 'plannedTime': '计划时间',
        'duration': '投入分钟数', 'mentorName': '交流对象', 'previousFollowUp': '上次要求落实', 'nextMeetingDate': '下次交流'};
      return [
        for (final entry in labels.entries)
          if (data[entry.key] != null && data[entry.key].toString().isNotEmpty) '${entry.value}：${data[entry.key]}',
        for (final a in (data['actions'] as List? ?? []))
          '跟进事项（${MentorActionStatus.values.byName(a['status'] as String).label}）：${a['text']}',
      ].join('\n\n');
    } catch (_) { return '草稿无法完整读取。原始内容：\n${prefs.getString(key) ?? ''}'; }
  }

  Future<void> _enqueue(Future<bool> Function() operation) {
    final result = _queue.pending.then((_) async {
      if (!await operation()) throw StateError('草稿未保存');
    });
    _queue.pending = result.catchError((Object _) {});
    return result;
  }

  Future<void> write(String key, Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    return _enqueue(() => (writeValue ?? prefs.setString)(key, encoded));
  }
  Future<void> remove(String key) => _enqueue(() => prefs.remove(key));
  Future<void> clear() => _enqueue(() async {
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      if (!await prefs.remove(key)) return false;
    }
    return true;
  });
}

class _DraftQueue {
  Future<void> pending = Future.value();
}