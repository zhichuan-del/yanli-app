import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class DailyReminderScheduler {
  bool get isSupported;

  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> notificationsEnabled();
  Future<void> scheduleDaily(int minutesAfterMidnight);
  Future<void> cancel();
}

class LocalDailyReminderScheduler implements DailyReminderScheduler {
  LocalDailyReminderScheduler({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 2200;
  static const _channelId = 'daily_research_reminder';
  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;

    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return await _android?.requestNotificationsPermission() ??
        await notificationsEnabled();
  }

  @override
  Future<bool> notificationsEnabled() async {
    if (!isSupported) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {
    if (!isSupported) return;
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    final hour = minutesAfterMidnight ~/ 60;
    final minute = minutesAfterMidnight % 60;
    final today = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    final nextReminder = today.isAfter(now)
        ? today
        : tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day + 1,
            hour,
            minute,
          );

    await _notifications.zonedSchedule(
      id: _notificationId,
      title: '研历',
      body: '研历提醒：记录一下今天的科研进展吧。',
      scheduledDate: nextReminder,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          '每日科研提醒',
          channelDescription: '每天提醒记录科研进展',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    await _notifications.cancel(id: _notificationId);
  }
}
