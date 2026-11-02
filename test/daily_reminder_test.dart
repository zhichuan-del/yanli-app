import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/daily_reminder.dart';
import 'package:yanli_app/main.dart';

class FakeDailyReminderScheduler implements DailyReminderScheduler {
  final scheduledMinutes = <int>[];
  int cancelCount = 0;
  int permissionRequestCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequestCount++;
    return true;
  }

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {
    scheduledMinutes.add(minutesAfterMidnight);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

void main() {
  testWidgets('默认安排每天 22:00 提醒，并可关闭', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scheduler = FakeDailyReminderScheduler();
    await tester.pumpWidget(
      YanliApp(prefs: prefs, reminderScheduler: scheduler),
    );
    await tester.pumpAndSettle();

    expect(scheduler.permissionRequestCount, 1);
    expect(scheduler.scheduledMinutes, [22 * 60]);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isNull);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), isNull);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    final reminderSwitch = find.byKey(const ValueKey('daily-reminder-switch'));
    await tester.scrollUntilVisible(reminderSwitch, 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    expect(scheduler.cancelCount, 1);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(find.text('提醒时间'), findsOneWidget);
  });
}
