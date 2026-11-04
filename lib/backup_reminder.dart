import 'package:shared_preferences/shared_preferences.dart';

import 'daily_reminder.dart';
import 'domain.dart';

class ReminderRestoreResult {
  const ReminderRestoreResult({
    required this.enabled,
    required this.minutes,
    this.warning,
  });

  final bool enabled;
  final int minutes;
  final String? warning;
}

Future<ReminderRestoreResult> restoreReminderSettings({
  required SharedPreferences prefs,
  required DailyReminderScheduler scheduler,
  required BackupSettings settings,
}) async {
  const enabledKey = 'yanli_daily_reminder_enabled';
  const minutesKey = 'yanli_daily_reminder_minutes';
  const requestedKey = 'yanli_daily_reminder_permission_requested';
  final previousEnabled = prefs.getBool(enabledKey);
  final previousMinutes = prefs.getInt(minutesKey);
  final oldEnabled = previousEnabled ?? true;
  final oldMinutes = previousMinutes ?? 22 * 60;
  var enabled = settings.reminderEnabled;
  String? warning;

  try {
    if (scheduler.isSupported) {
      await scheduler.initialize();
      if (enabled) {
        var allowed = await scheduler.notificationsEnabled();
        if (!allowed) {
          allowed = await scheduler.requestPermission();
          if (!await prefs.setBool(requestedKey, true)) {
            throw StateError('无法保存提醒权限状态');
          }
        }
        if (allowed) {
          await scheduler.scheduleDaily(settings.reminderMinutes);
        } else {
          enabled = false;
          await scheduler.cancel();
          warning = '未获得通知权限，提醒保持关闭，请在系统设置中允许后再开启';
        }
      } else {
        await scheduler.cancel();
      }
    } else {
      warning = '提醒设置已保存，但当前设备不支持每日提醒';
    }
    if (!await prefs.setInt(minutesKey, settings.reminderMinutes) ||
        !await prefs.setBool(enabledKey, enabled)) {
      throw StateError('无法保存提醒设置');
    }
    return ReminderRestoreResult(
      enabled: enabled,
      minutes: settings.reminderMinutes,
      warning: warning,
    );
  } catch (_) {
    var rolledBack = true;
    try {
      final saved = previousMinutes == null
          ? await prefs.remove(minutesKey)
          : await prefs.setInt(minutesKey, previousMinutes);
      if (!saved) rolledBack = false;
    } catch (_) {
      rolledBack = false;
    }
    try {
      final saved = previousEnabled == null
          ? await prefs.remove(enabledKey)
          : await prefs.setBool(enabledKey, previousEnabled);
      if (!saved) rolledBack = false;
    } catch (_) {
      rolledBack = false;
    }
    try {
      if (scheduler.isSupported) {
        if (oldEnabled && await scheduler.notificationsEnabled()) {
          await scheduler.scheduleDaily(oldMinutes);
        } else {
          await scheduler.cancel();
        }
      }
    } catch (_) {
      rolledBack = false;
    }
    return ReminderRestoreResult(
      enabled: prefs.getBool(enabledKey) ?? oldEnabled,
      minutes: prefs.getInt(minutesKey) ?? oldMinutes,
      warning: rolledBack
          ? '提醒设置恢复失败，已保留原设置，请重试'
          : '提醒设置恢复失败，部分设置可能未回退，请检查提醒开关、时间和系统通知权限',
    );
  }
}
