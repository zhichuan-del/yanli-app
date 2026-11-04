import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yanli_app/backup_reminder.dart';
import 'package:yanli_app/daily_reminder.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';
import 'package:yanli_app/recycle_bin.dart';

class TestReminderScheduler implements DailyReminderScheduler {
  bool allowed = true;
  bool? requestResult;
  bool supported = true;
  bool failSchedule = false;
  int permissionRequests = 0;
  Future<void>? scheduleWait;
  final scheduled = <int>[];
  int cancellations = 0;

  @override
  bool get isSupported => supported;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> notificationsEnabled() async => allowed;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return requestResult ?? allowed;
  }

  @override
  Future<void> scheduleDaily(int minutesAfterMidnight) async {
    if (failSchedule) throw PlatformException(code: 'schedule_failed');
    if (scheduleWait != null) await scheduleWait;
    scheduled.add(minutesAfterMidnight);
  }

  @override
  Future<void> cancel() async => cancellations++;
}

ResearchRecord record(String id) => ResearchRecord(
  id: id,
  kind: RecordKind.task,
  date: DateTime(2026, 11, 3),
  title: id,
);

const importedSettings = BackupSettings(
  reminderEnabled: true,
  reminderMinutes: 7 * 60 + 30,
  retentionDays: 30,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('org.yanli/files');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('新备份往返设置并兼容旧备份，拒绝非法或未知设置', () {
    final source = encodeBackup([record('新记录')], settings: importedSettings);
    final backup = decodeBackupData(source);
    expect(backup.records.single.id, '新记录');
    expect(backup.settings!.reminderEnabled, isTrue);
    expect(backup.settings!.reminderMinutes, 450);
    expect(backup.settings!.retentionDays, 30);
    expect(decodeBackupData(encodeBackup([record('旧记录')])).settings, isNull);
    expect(decodeBackupData('{"version":1,"records":[]}').settings, isNull);
    final malformed = jsonDecode(source) as Map<String, dynamic>;
    final settings = malformed['settings'] as Map<String, dynamic>;
    settings['reminderMinutes'] = 1440;
    expect(
      () => decodeBackupData(jsonEncode(malformed)),
      throwsFormatException,
    );
    settings['reminderMinutes'] = 450;
    settings['unknown'] = true;
    expect(
      () => decodeBackupData(jsonEncode(malformed)),
      throwsFormatException,
    );
    settings.remove('unknown');
    settings['retentionDays'] = 0;
    expect(
      () => decodeBackupData(jsonEncode(malformed)),
      throwsFormatException,
    );
    settings['retentionDays'] = 30;
    settings['reminderEnabled'] = 'true';
    expect(
      () => decodeBackupData(jsonEncode(malformed)),
      throwsFormatException,
    );
  });

  test('恢复关闭的提醒会取消原通知', () async {
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': true,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler();
    final result = await restoreReminderSettings(
      prefs: prefs,
      scheduler: scheduler,
      settings: const BackupSettings(
        reminderEnabled: false,
        reminderMinutes: 420,
        retentionDays: 3,
      ),
    );
    expect(result.warning, isNull);
    expect(scheduler.cancellations, 1);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 420);
  });

  test('恢复开启的提醒时可请求通知权限', () async {
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler()
      ..allowed = false
      ..requestResult = true;
    final result = await restoreReminderSettings(
      prefs: prefs,
      scheduler: scheduler,
      settings: importedSettings,
    );
    expect(result.warning, isNull);
    expect(scheduler.permissionRequests, 1);
    expect(scheduler.scheduled, [450]);
    expect(prefs.getBool('yanli_daily_reminder_permission_requested'), isTrue);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isTrue);
  });

  test('不支持提醒的平台保存设置并明确提示不能调度', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler()..supported = false;
    final result = await restoreReminderSettings(
      prefs: prefs,
      scheduler: scheduler,
      settings: importedSettings,
    );
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isTrue);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 450);
    expect(scheduler.scheduled, isEmpty);
    expect(result.warning, contains('当前设备不支持'));
  });

  Future<void> openSettings(
    WidgetTester tester,
    SharedPreferences prefs,
    TestReminderScheduler scheduler,
  ) async {
    await tester.pumpWidget(
      YanliApp(prefs: prefs, reminderScheduler: scheduler),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
  }

  Future<void> openImport(WidgetTester tester) async {
    await tester.ensureVisible(find.text('从文件恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('从文件恢复'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmImport(WidgetTester tester) async {
    await tester.tap(find.text('导出当前备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认覆盖'));
    await tester.pumpAndSettle();
  }

  testWidgets('导出的备份包含当前提醒与回收站设置', (tester) async {
    MethodCall? exported;
    messenger.setMockMethodCallHandler(channel, (call) async {
      exported = call;
      return true;
    });
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    await openSettings(tester, prefs, TestReminderScheduler());
    await tester.ensureVisible(find.text('导出备份文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出备份文件'));
    await tester.pumpAndSettle();
    final source = (exported!.arguments as Map)['content'] as String;
    final settings = decodeBackupData(source).settings!;
    expect(settings.reminderEnabled, isFalse);
    expect(settings.reminderMinutes, 600);
    expect(settings.retentionDays, 3);
  });

  testWidgets('默认恢复设置并重新安排提醒', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': encodeBackup([record('旧记录')]),
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
      'yanli_daily_reminder_permission_requested': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler();
    await openSettings(tester, prefs, scheduler);
    await openImport(tester);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('restore-backup-settings')),
          )
          .value,
      isTrue,
    );
    await confirmImport(tester);
    final snapshot = LocalRecordSnapshot.decode(
      prefs.getString('yanli_records_v1')!,
    );
    expect(snapshot.records.single.id, '新记录');
    expect(snapshot.days, 30);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isTrue);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 450);
    expect(scheduler.scheduled.last, 450);
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('周视图'), findsNothing);
    expect(find.byKey(const ValueKey('calendar-agenda-sheet')), findsOneWidget);
  });

  testWidgets('恢复设置确认在窄屏和大字体下可显示', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: YanliApp(
          prefs: prefs,
          reminderScheduler: TestReminderScheduler(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await openImport(tester);
    expect(
      find.byKey(const ValueKey('restore-backup-settings')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('提醒设置恢复期间禁止并发修改，完成后解锁', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<void>();
    final scheduler = TestReminderScheduler()..scheduleWait = pending.future;
    await openSettings(tester, prefs, scheduler);
    await openImport(tester);
    await tester.tap(find.text('导出当前备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认覆盖'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final lock = find.descendant(
      of: find.byType(HomePage),
      matching: find.byType(AbsorbPointer),
    );
    expect(
      tester.widgetList<AbsorbPointer>(lock).any((w) => w.absorbing),
      isTrue,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<AbsorbPointer>(lock).any((w) => w.absorbing),
      isFalse,
    );
  });

  testWidgets('取消恢复设置时只恢复记录', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': LocalRecordSnapshot([
        record('旧记录'),
      ], days: 7).encode(),
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler();
    await openSettings(tester, prefs, scheduler);
    await openImport(tester);
    await tester.tap(find.byKey(const ValueKey('restore-backup-settings')));
    await tester.pumpAndSettle();
    await confirmImport(tester);
    final snapshot = LocalRecordSnapshot.decode(
      prefs.getString('yanli_records_v1')!,
    );
    expect(snapshot.records.single.id, '新记录');
    expect(snapshot.days, 7);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 600);
    expect(scheduler.scheduled, isEmpty);
  });

  testWidgets('旧备份不覆盖当前设置', (tester) async {
    final incoming = encodeBackup([record('旧格式')]);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': LocalRecordSnapshot([
        record('现有记录'),
      ], days: 7).encode(),
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    await openSettings(tester, prefs, TestReminderScheduler());
    await openImport(tester);
    expect(find.text('此备份不含设置，恢复时将保留当前设置。'), findsOneWidget);
    await confirmImport(tester);
    expect(decodeBackup(prefs.getString('yanli_records_v1')!).single.id, '旧格式');
    expect(
      LocalRecordSnapshot.decode(prefs.getString('yanli_records_v1')!).days,
      7,
    );
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 600);
  });

  testWidgets('记录保存失败时不应用备份中的设置', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    final original = encodeBackup([record('旧记录')]);
    SharedPreferences.setMockInitialValues({
      'yanli_records_v1': original,
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          prefs: prefs,
          reminderScheduler: scheduler,
          writeSnapshot: (_) async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await openImport(tester);
    await confirmImport(tester);
    expect(prefs.getString('yanli_records_v1'), original);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 600);
    expect(scheduler.scheduled, isEmpty);
    expect(find.textContaining('恢复未确认成功'), findsOneWidget);
  });

  testWidgets('拒绝通知权限时恢复记录和时间，但不假称开启提醒', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler()..allowed = false;
    await openSettings(tester, prefs, scheduler);
    await openImport(tester);
    await confirmImport(tester);
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 450);
    expect(scheduler.scheduled, isEmpty);
    expect(find.textContaining('未获得通知权限'), findsWidgets);
  });

  testWidgets('调度失败时保留原提醒设置并说明记录已恢复', (tester) async {
    final incoming = encodeBackup([record('新记录')], settings: importedSettings);
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'import' ? incoming : true,
    );
    SharedPreferences.setMockInitialValues({
      'yanli_daily_reminder_enabled': false,
      'yanli_daily_reminder_minutes': 600,
    });
    final prefs = await SharedPreferences.getInstance();
    final scheduler = TestReminderScheduler()..failSchedule = true;
    await openSettings(tester, prefs, scheduler);
    await openImport(tester);
    await confirmImport(tester);
    expect(decodeBackup(prefs.getString('yanli_records_v1')!).single.id, '新记录');
    expect(prefs.getBool('yanli_daily_reminder_enabled'), isFalse);
    expect(prefs.getInt('yanli_daily_reminder_minutes'), 600);
    expect(find.textContaining('提醒设置恢复失败'), findsWidgets);
  });
}
