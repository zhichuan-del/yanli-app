import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_reminder.dart';
import 'demo_records.dart';
import 'domain.dart';
import 'progress_search.dart';
import 'range_report.dart';
import 'report_preview.dart';
import 'report_summary.dart';
import 'storage_safety.dart';
import 'recycle_bin.dart';
import 'document_files.dart';
import 'splash_screen.dart';
import 'scrolling_calendar.dart';
import 'frosted_dropdown.dart';
import 'record_details.dart';
import 'editor_drafts.dart';
import 'voice_input.dart';

const ink = Color(0xff1c1c1e);
const calendarRed = Color(0xffd93025);
const paper = Color(0xfff2f2f7);
const muted = Color(0xff6c6c70);
const accent = Color(0xffffefed);

class DailyReminderPreferenceSaveException implements Exception {
  const DailyReminderPreferenceSaveException();
}

ButtonStyle glassButtonStyle({bool prominent = false}) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? muted.withValues(alpha: .45)
        : prominent
        ? const Color(0xffb42318)
        : calendarRed,
  ),
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  elevation: const WidgetStatePropertyAll(0),
  side: const WidgetStatePropertyAll(BorderSide.none),
  shape: const WidgetStatePropertyAll(StadiumBorder()),
  backgroundBuilder: (context, states, child) {
    final disabled = states.contains(WidgetState.disabled);
    final pressed = states.contains(WidgetState.pressed);
    final highlighted = pressed || states.contains(WidgetState.hovered);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: disabled
            ? const []
            : [
                BoxShadow(
                  color: ink.withValues(alpha: pressed ? .015 : .035),
                  blurRadius: pressed ? 3 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: disabled
                          ? [
                              Colors.white.withValues(alpha: .12),
                              paper.withValues(alpha: .06),
                            ]
                          : prominent
                          ? [
                              const Color(0xffffe4e0).withValues(alpha: .30),
                              const Color(
                                0xffffb9b1,
                              ).withValues(alpha: highlighted ? .28 : .14),
                            ]
                          : [
                              Colors.white.withValues(alpha: .24),
                              const Color(
                                0xffe9e9f0,
                              ).withValues(alpha: highlighted ? .20 : .08),
                            ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .50),
                      width: .75,
                    ),
                  ),
                ),
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  },
);

class MentorStatusPicker extends StatelessWidget {
  const MentorStatusPicker({super.key, required this.value, this.onChanged});

  final MentorActionStatus value;
  final ValueChanged<MentorActionStatus>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final foreground = enabled ? calendarRed : muted;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: '跟进状态：${value.label}',
      child: PopupMenuButton<MentorActionStatus>(
        enabled: enabled,
        tooltip: '跟进状态：${value.label}',
        position: PopupMenuPosition.under,
        offset: const Offset(0, 6),
        constraints: const BoxConstraints(minWidth: 184, maxWidth: 224),
        menuPadding: EdgeInsets.zero,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        onSelected: onChanged,
        // The blur wraps all options, so the rounded menu filters the backdrop once.
        itemBuilder: (context) => [_MentorStatusMenuEntry(value: value)],
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: enabled
                ? const Color(0xffffefed).withValues(alpha: .75)
                : const Color(0xffe5e5ea).withValues(alpha: .55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: .8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(
                  value.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: foreground,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentorStatusMenuEntry extends PopupMenuEntry<MentorActionStatus> {
  const _MentorStatusMenuEntry({required this.value});

  final MentorActionStatus value;

  @override
  double get height => 160;

  @override
  bool represents(MentorActionStatus? value) => false;

  @override
  State<_MentorStatusMenuEntry> createState() => _MentorStatusMenuEntryState();
}

class _MentorStatusMenuEntryState extends State<_MentorStatusMenuEntry> {
  late final List<FocusNode> optionFocusNodes;

  @override
  void initState() {
    super.initState();
    optionFocusNodes = [
      for (final status in MentorActionStatus.values)
        FocusNode(debugLabel: 'mentor-status-${status.name}'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) optionFocusNodes[widget.value.index].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in optionFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    key: const ValueKey('mentor-status-menu'),
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .38),
              const Color(0xfff2f2f7).withValues(alpha: .28),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final status in MentorActionStatus.values)
                Focus(
                  focusNode: optionFocusNodes[status.index],
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                      return KeyEventResult.ignored;
                    }
                    if (event is KeyDownEvent &&
                        (event.logicalKey == LogicalKeyboardKey.enter ||
                            event.logicalKey == LogicalKeyboardKey.space ||
                            event.logicalKey ==
                                LogicalKeyboardKey.numpadEnter)) {
                      Navigator.pop(context, status);
                      return KeyEventResult.handled;
                    }
                    final direction =
                        event.logicalKey == LogicalKeyboardKey.arrowDown
                        ? 1
                        : event.logicalKey == LogicalKeyboardKey.arrowUp
                        ? -1
                        : 0;
                    if (direction == 0) return KeyEventResult.ignored;
                    final next =
                        (status.index + direction) % optionFocusNodes.length;
                    optionFocusNodes[next].requestFocus();
                    return KeyEventResult.handled;
                  },
                  child: PopupMenuItem<MentorActionStatus>(
                    key: ValueKey('mentor-status-${status.name}'),
                    value: status,
                    padding: EdgeInsets.zero,
                    child: Semantics(
                      checked: status == widget.value,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: status == widget.value
                              ? calendarRed.withValues(alpha: .05)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                status.label,
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 15,
                                  fontWeight: status == widget.value
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (status == widget.value)
                              const Icon(
                                Icons.check_rounded,
                                color: calendarRed,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(YanliApp(prefs: prefs, showSplash: true));
}

class YanliApp extends StatelessWidget {
  const YanliApp({
    super.key,
    required this.prefs,
    this.showSplash = false,
    this.reminderScheduler,
  });
  final SharedPreferences prefs;
  final bool showSplash;
  final DailyReminderScheduler? reminderScheduler;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '研历',
    locale: const Locale('zh', 'CN'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: calendarRed,
        onPrimary: Colors.white,
        secondary: Color(0xff007aff),
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: Color(0xffc7c7cc),
        outlineVariant: Color(0xffe5e5ea),
        surfaceContainerHighest: paper,
      ),
      scaffoldBackgroundColor: paper,
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? calendarRed : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: states.contains(WidgetState.selected) ? calendarRed : muted,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: calendarRed),
        selectedLabelTextStyle: TextStyle(color: calendarRed),
        unselectedIconTheme: IconThemeData(color: muted),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xffe5e5ea),
        thickness: .5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: glassButtonStyle(prominent: true),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(style: glassButtonStyle()),
      textButtonTheme: TextButtonThemeData(style: glassButtonStyle()),
      iconButtonTheme: IconButtonThemeData(style: glassButtonStyle()),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink),
        bodyLarge: TextStyle(color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe5e5ea)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xffe5e5ea)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    ),
    home: showSplash
        ? SplashScreen(
            child: HomePage(prefs: prefs, reminderScheduler: reminderScheduler),
          )
        : HomePage(prefs: prefs, reminderScheduler: reminderScheduler),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.prefs,
    this.writeSnapshot,
    this.reminderScheduler,
  });
  final SharedPreferences prefs;
  final Future<bool> Function(String)? writeSnapshot;
  final DailyReminderScheduler? reminderScheduler;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int tab = 0;
  bool monthExpanded = true;
  int dateNavigationRevision = 0;
  final agendaController = DraggableScrollableController();
  DateTime selected = dayOnly(DateTime.now());
  DateTime reportWeek = weekStart(DateTime.now());
  DateTime reportGeneratedAt = DateTime.now();
  DateTimeRange? customReportRange;
  List<ResearchRecord> records = [];
  List<TrashedRecord> trash = [];
  int retentionDays = 3;
  Timer? cleanupTimer;
  Timer? undoTimer;
  final recycleRevision = ValueNotifier<int>(0);
  late final StorageSafety storage;
  String? loadError;
  bool restoring = false;
  bool demoConfirmationOpen = false;
  int progressSearchRevision = 0;
  bool dataReadFailed = false;
  String? rawStoredData;
  late final DailyReminderScheduler reminderScheduler;
  bool reminderEnabled = true;
  int reminderMinutesAfterMidnight = 22 * 60;
  bool reminderSettingsReady = false;
  bool reminderBusy = false;
  String? reminderError;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cleanupTimer?.cancel();
    undoTimer?.cancel();
    recycleRevision.dispose();
    agendaController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    reminderScheduler =
        widget.reminderScheduler ?? LocalDailyReminderScheduler();
    unawaited(_loadDailyReminder());
    storage = StorageSafety(
      widget.writeSnapshot ??
          (snapshot) => widget.prefs.setString('yanli_records_v1', snapshot),
    );
    final saved = widget.prefs.getString('yanli_records_v1');
    if (saved != null) {
      try {
        final snapshot = LocalRecordSnapshot.decode(saved);
        records = snapshot.records;
        trash = snapshot.trash;
        retentionDays = snapshot.days;
      } catch (_) {
        dataReadFailed = true;
        rawStoredData = saved;
        loadError = '本地数据读取失败，请先复制原始数据或恢复备份；已暂停修改。';
      }
    }
    cleanupTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(cleanupTrash());
      recycleRevision.value++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(cleanupTrash());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(cleanupTrash());
  }

  Future<void> cleanupTrash() async {
    if (!mounted || restoring || dataReadFailed) return;
    final remaining = trash
        .where((entry) => !entry.expired(DateTime.now(), retentionDays))
        .toList();
    if (remaining.length != trash.length) {
      await commitRecords(records, replacementTrash: remaining);
    }
  }

  Future<void> _loadDailyReminder() async {
    final enabled =
        widget.prefs.getBool('yanli_daily_reminder_enabled') ?? true;
    final minutes =
        widget.prefs.getInt('yanli_daily_reminder_minutes') ?? 22 * 60;
    if (mounted) {
      setState(() {
        reminderEnabled = enabled;
        reminderMinutesAfterMidnight = minutes;
      });
    }

    if (!reminderScheduler.isSupported) {
      if (mounted) {
        setState(() {
          reminderError = '每日提醒目前仅支持 Android';
          reminderSettingsReady = true;
        });
      }
      return;
    }

    try {
      await reminderScheduler.initialize();
      if (!enabled) {
        await reminderScheduler.cancel();
      } else {
        final permissionWasRequested =
            widget.prefs.getBool('yanli_daily_reminder_permission_requested') ??
            false;
        final allowed = permissionWasRequested
            ? await reminderScheduler.notificationsEnabled()
            : await reminderScheduler.requestPermission();
        if (!permissionWasRequested) {
          await _saveReminderBool(
            'yanli_daily_reminder_permission_requested',
            true,
          );
        }
        if (allowed) {
          await reminderScheduler.scheduleDaily(minutes);
        } else {
          await _saveReminderBool('yanli_daily_reminder_enabled', false);
          if (mounted) {
            setState(() {
              reminderEnabled = false;
              reminderError = '未获得通知权限，请允许研历发送通知后再开启提醒';
            });
          }
        }
      }
    } on DailyReminderPreferenceSaveException {
      if (mounted) setState(() => reminderError = '提醒设置无法保存，请重试');
    } on PlatformException {
      if (mounted) setState(() => reminderError = '每日提醒初始化失败，请检查系统通知设置');
    } on MissingPluginException {
      if (mounted) setState(() => reminderError = '当前设备无法初始化每日提醒');
    } finally {
      if (mounted) setState(() => reminderSettingsReady = true);
    }
  }

  Future<void> _setDailyReminderEnabled(bool enabled) async {
    if (reminderBusy || !reminderSettingsReady) return;
    if (!reminderScheduler.isSupported) {
      snack('每日提醒目前仅支持 Android');
      return;
    }
    setState(() {
      reminderBusy = true;
      reminderError = null;
    });
    try {
      await reminderScheduler.initialize();
      if (!mounted) return;
      if (enabled) {
        final allowed = await reminderScheduler.requestPermission();
        await _saveReminderBool(
          'yanli_daily_reminder_permission_requested',
          true,
        );
        if (!mounted) return;
        if (!allowed) {
          await _saveReminderBool('yanli_daily_reminder_enabled', false);
          setState(() {
            reminderEnabled = false;
            reminderError = '未获得通知权限，请在系统设置中允许后重试';
          });
          return;
        }
        await reminderScheduler.scheduleDaily(reminderMinutesAfterMidnight);
      } else {
        await reminderScheduler.cancel();
      }
      await _saveReminderBool('yanli_daily_reminder_enabled', enabled);
      if (mounted) setState(() => reminderEnabled = enabled);
    } on DailyReminderPreferenceSaveException {
      if (mounted) setState(() => reminderError = '提醒设置无法保存，请重试');
    } on PlatformException {
      if (mounted) setState(() => reminderError = '提醒设置失败，请检查系统通知设置后重试');
    } on MissingPluginException {
      if (mounted) setState(() => reminderError = '当前设备无法设置每日提醒');
    } finally {
      if (mounted) setState(() => reminderBusy = false);
    }
  }

  Future<void> _chooseDailyReminderTime() async {
    if (!reminderSettingsReady || reminderBusy) return;
    final initialTime = TimeOfDay(
      hour: reminderMinutesAfterMidnight ~/ 60,
      minute: reminderMinutesAfterMidnight % 60,
    );
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: '选择每日提醒时间',
    );
    if (selectedTime == null || !mounted) return;
    final minutes = selectedTime.hour * 60 + selectedTime.minute;
    setState(() {
      reminderBusy = true;
      reminderError = null;
    });
    try {
      if (reminderEnabled) {
        await reminderScheduler.scheduleDaily(minutes);
      }
      if (!mounted) return;
      final saved = await widget.prefs.setInt(
        'yanli_daily_reminder_minutes',
        minutes,
      );
      if (!saved) {
        if (reminderEnabled) {
          await reminderScheduler.scheduleDaily(reminderMinutesAfterMidnight);
        }
        throw const DailyReminderPreferenceSaveException();
      }
      if (mounted) {
        setState(() => reminderMinutesAfterMidnight = minutes);
      }
    } on DailyReminderPreferenceSaveException {
      if (mounted) setState(() => reminderError = '提醒时间无法保存，请重试');
    } on PlatformException {
      if (mounted) setState(() => reminderError = '提醒时间保存失败，请重试');
    } on MissingPluginException {
      if (mounted) setState(() => reminderError = '当前设备无法设置每日提醒');
    } finally {
      if (mounted) setState(() => reminderBusy = false);
    }
  }

  Future<void> _saveReminderBool(String key, bool value) async {
    if (!await widget.prefs.setBool(key, value)) {
      throw const DailyReminderPreferenceSaveException();
    }
  }

  Future<bool> commitRecords(
    List<ResearchRecord> replacement, {
    bool allowRecovery = false,
    List<TrashedRecord>? replacementTrash,
    int? replacementDays,
  }) async {
    if (restoring || (dataReadFailed && !allowRecovery)) return false;
    setState(() => restoring = true);
    bool success;
    try {
      success = await storage.enqueue(
        LocalRecordSnapshot(
          replacement,
          trash: replacementTrash ?? trash,
          days: replacementDays ?? retentionDays,
        ).encode(),
      );
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => restoring = false);
    }
    if (!mounted) return false;
    if (success) {
      setState(() {
        records = List.of(replacement);
        trash = List.of(replacementTrash ?? trash);
        retentionDays = replacementDays ?? retentionDays;
        reportGeneratedAt = DateTime.now();
        loadError = null;
        dataReadFailed = false;
        rawStoredData = null;
        restoring = false;
      });
      recycleRevision.value++;
      return true;
    }
    setState(() {
      restoring = false;
      loadError = '保存未确认成功，请重试或复制备份。';
    });
    recycleRevision.value++;
    return false;
  }

  Future<void> addDemoProgress() async {
    if (restoring || dataReadFailed || demoConfirmationOpen) return;
    demoConfirmationOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('添加测试进展？'),
          content: const Text(
            '将在当前浏览器或设备添加12条【测试】模拟进展，覆盖5种类型和过去11天至今天，含模拟正文、问题、下一步和投入时间。'
            '不覆盖已有记录，不清空回收站。固定测试ID已存在于记录或回收站时会跳过；其他ID的旧示例可能并存。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('确认添加'),
            ),
          ],
        ),
      );
    } finally {
      demoConfirmationOpen = false;
    }
    if (confirmed != true || !mounted || restoring || dataReadFailed) return;
    final additions = missingDemoProgress(
      records,
      now: DateTime.now(),
      reservedIds: trash.map((entry) => entry.record.id),
    );
    if (additions.isNotEmpty &&
        !await commitRecords([...records, ...additions])) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        snack('测试进展保存失败，实际新增0条；已有记录未变，请重试');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      tab = 1;
      progressSearchRevision++;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    snack(
      '实际新增${additions.length}条【测试】进展，跳过${12 - additions.length}条已有测试ID（含回收站）',
    );
  }

  Future<void> edit(RecordKind kind, {ResearchRecord? record}) async {
    if (restoring) return;
    if (dataReadFailed) {
      snack('原始数据读取失败，请先到“我的”复制原始数据或恢复备份');
      return;
    }
    await showModalBottomSheet<ResearchRecord>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordEditor(
        prefs: widget.prefs,
        kind: kind,
        initialDate: selected,
        record: record,
        previousDiscussions: records
            .where(
              (r) =>
                  r.kind == RecordKind.mentor &&
                  r.id != record?.id &&
                  (record == null || !createsDiscussionCycle(r, record.id)),
            )
            .toList(),
        onSave: (result) async {
          if (record != null && !records.any((r) => r.id == record.id && jsonEncode(r.toJson()) == jsonEncode(record.toJson()))) {
            snack('原记录已删除或更新，请关闭编辑后重新打开；草稿已保留');
            return false;
          }
          if (records.any(
            (item) =>
                item.previousDiscussionId == result.id &&
                dayOnly(item.date).isBefore(dayOnly(result.date)),
          )) {
            if (mounted) snack('已有后续交流关联此记录，日期不能晚于后续交流');
            return false;
          }
          final updated = upsertLinkedRecord(records, result);
          final saved = await commitRecords(updated);
          if (saved && mounted) {
            setState(() {
              selected = dayOnly(result.date);
              dateNavigationRevision++;
            });
            snack('记录已保存');
          }
          return saved;
        },
      ),
    );
  }

  Future<void> openDetails(ResearchRecord record) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RecordDetails(
        recordId: record.id,
        lookup: (id) => records.where((r) => r.id == id).firstOrNull,
        revision: recycleRevision,
        onEdit: (r) => edit(r.kind, record: r),
        onOpenSource: openDetails,
      ),
    ));
  }

  Future<void> remove(ResearchRecord r) async {
    if (restoring) return;
    if (dataReadFailed) {
      snack('原始数据读取失败，请先恢复备份');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条记录？'),
        content: Text(
          '删除“${r.title}”后可在回收站恢复，保留 $retentionDays 天。'
          '${records.any((record) => record.previousDiscussionId == r.id) ? '其他交流的关联将被移除，但其正文会保留。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      final deletion = RecordDeletion(records, r);
      final entry = TrashedRecord(deletion, DateTime.now().toUtc());
      if (await commitRecords(
        deletion.apply(records),
        replacementTrash: [...trash, entry],
      )) {
        if (mounted) showUndo(entry);
      } else if (mounted) {
        snack('删除未确认成功，请重试');
      }
    }
  }

  void showUndo(TrashedRecord entry, {bool failed = false}) {
    final messenger = ScaffoldMessenger.of(context);
    undoTimer?.cancel();
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(failed ? '撤销保存失败，请到回收站重试' : '记录已移入回收站'),
        action: SnackBarAction(
          label: failed ? '重试撤销' : '撤销',
          onPressed: () async {
            final success = await restoreTrash(entry);
            if (mounted && !success) showUndo(entry, failed: true);
          },
        ),
      ),
    );
    // SnackBarAction otherwise stays indefinitely with accessibleNavigation.
    undoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) messenger.removeCurrentSnackBar();
    });
  }

  Future<bool> restoreTrash(TrashedRecord entry) async {
    if (!trash.contains(entry) || restoring || dataReadFailed) return false;
    if (entry.expired(DateTime.now(), retentionDays)) {
      await cleanupTrash();
      if (mounted) snack('记录已到期，无法恢复');
      return false;
    }
    return commitRecords(
      entry.restore(records),
      replacementTrash: trash.where((r) => r != entry).toList(),
    );
  }

  Future<void> discardTrash(
    BuildContext pageContext, {
    TrashedRecord? entry,
  }) async {
    if (restoring || dataReadFailed) return;
    final yes = await showDialog<bool>(
      context: pageContext,
      builder: (c) => AlertDialog(
        title: Text(entry == null ? '清空回收站？' : '永久删除这条记录？'),
        content: const Text('永久删除后无法恢复，导出的备份也不包含回收站。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final success = await commitRecords(
      records,
      replacementTrash: entry == null
          ? []
          : trash.where((r) => r != entry).toList(),
    );
    if (mounted && pageContext.mounted) {
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(SnackBar(content: Text(success ? '已永久删除' : '删除保存失败，请重试')));
    }
  }

  Future<int?> customRetentionDays(BuildContext pageContext) async {
    final controller = TextEditingController(text: '$retentionDays');
    final formKey = GlobalKey<FormState>();
    final route = DialogRoute<int>(
      context: pageContext,
      builder: (c) => AlertDialog(
        title: const Text('自定义保留时间'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '保留天数',
              helperText: '请输入 1–3650 天的正整数',
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              return RegExp(r'^[0-9]+$').hasMatch(text) &&
                      isValidRetentionDays(int.tryParse(text))
                  ? null
                  : '请输入 1–3650 天的正整数';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(c, int.parse(controller.text.trim()));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    final result = await Navigator.of(pageContext).push(route);
    unawaited(route.completed.then((_) => controller.dispose()));
    return result;
  }

  Future<void> changeRetentionDays(BuildContext pageContext, int choice) async {
    final days = choice == 0 ? await customRetentionDays(pageContext) : choice;
    if (!mounted ||
        !pageContext.mounted ||
        restoring ||
        dataReadFailed ||
        days == null ||
        !isValidRetentionDays(days) ||
        days == retentionDays) {
      return;
    }
    final expired = trash.any((r) => r.expired(DateTime.now(), days));
    if (expired) {
      final yes = await showDialog<bool>(
        context: pageContext,
        builder: (c) => AlertDialog(
          title: const Text('缩短保留时间？'),
          content: const Text('超过新期限的记录将立即永久删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('确认修改'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted || !pageContext.mounted) return;
    }
    final success = await commitRecords(
      records,
      replacementDays: days,
      replacementTrash: trash
          .where((r) => !r.expired(DateTime.now(), days))
          .toList(),
    );
    if (!success && pageContext.mounted) {
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(const SnackBar(content: Text('保留时间保存失败，请重试')));
    }
  }

  Future<void> openRecycleBin() async {
    await cleanupTrash();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => ValueListenableBuilder<int>(
          valueListenable: recycleRevision,
          builder: (_, revision, child) => Scaffold(
            appBar: AppBar(
              title: Text('回收站（${trash.length}）'),
              actions: [
                TextButton(
                  onPressed: restoring || trash.isEmpty
                      ? null
                      : () => discardTrash(pageContext),
                  child: const Text('清空回收站'),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '到期记录会在启动、打开回收站、返回前台及运行时自动清理。应用关闭或离线未运行时，下次打开清理。备份仅包含有效记录。',
                ),
                Row(
                  children: [
                    const Text('保留时间：'),
                    FrostedPopupMenu<int>(
                      tooltip: '保留时间',
                      value: retentionDays,
                      items: [
                        for (final days in [3, 7, 30])
                          DropdownMenuItem(value: days, child: Text('$days 天')),
                        if (![3, 7, 30].contains(retentionDays))
                          DropdownMenuItem(
                            value: retentionDays,
                            child: Text('$retentionDays 天（自定义）'),
                          ),
                        const DropdownMenuItem(value: 0, child: Text('自定义…')),
                      ],
                      onSelected: restoring || dataReadFailed
                          ? null
                          : (days) => changeRetentionDays(pageContext, days),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$retentionDays 天'),
                            const Icon(Icons.keyboard_arrow_down_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (loadError != null)
                  Text(loadError!, style: const TextStyle(color: Colors.red)),
                if (trash.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('回收站为空')),
                  ),
                for (final entry in trash.reversed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.record.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '删除时间：${entry.deletedAt.toLocal().toString().split('.').first}',
                          ),
                          Text('剩余时间：${remainingTrashTime(entry)}'),
                          Wrap(
                            spacing: 12,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.restore),
                                label: const Text('恢复'),
                                onPressed: restoring
                                    ? null
                                    : () async {
                                        final success = await restoreTrash(
                                          entry,
                                        );
                                        if (pageContext.mounted) {
                                          ScaffoldMessenger.of(
                                            pageContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                success
                                                    ? '记录已恢复'
                                                    : '恢复未保存或记录已到期，请检查后重试',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                              ),
                              TextButton(
                                onPressed: restoring
                                    ? null
                                    : () => discardTrash(
                                        pageContext,
                                        entry: entry,
                                      ),
                                child: const Text('永久删除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String remainingTrashTime(TrashedRecord entry) {
    final remaining = entry.deletedAt
        .add(Duration(days: retentionDays))
        .difference(DateTime.now());
    if (remaining <= Duration.zero) return '已到期，等待清理';
    if (remaining.inHours >= 24) {
      return '约 ${(remaining.inHours / 24).ceil()} 天';
    }
    if (remaining.inMinutes >= 60) {
      return '约 ${(remaining.inMinutes / 60).ceil()} 小时';
    }
    return '不足 1 小时';
  }

  Future<void> moveTask(ResearchRecord r, {bool tomorrow = false}) async {
    if (restoring || dataReadFailed) return;
    final now = DateTime.now();
    final target = tomorrow
        ? DateTime(now.year, now.month, now.day + 1)
        : await showDatePicker(
            context: context,
            initialDate: r.date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100, 12, 31),
          );
    if (target == null || !mounted) return;
    final updated = rescheduleTask(r, target, now);
    if (!await commitRecords(upsertLinkedRecord(records, updated)) && mounted) {
      snack('改期未保存，请重试');
    }
  }

  List<ResearchRecord> sorted(Iterable<ResearchRecord> input) =>
      input.toList()..sort((a, b) => b.date.compareTo(a.date));

  bool createsDiscussionCycle(ResearchRecord candidate, String currentId) {
    final seen = <String>{currentId};
    ResearchRecord? cursor = candidate;
    while (cursor != null) {
      if (!seen.add(cursor.id)) return true;
      final previousId = cursor.previousDiscussionId;
      if (previousId == null) return false;
      final matches = records.where((record) => record.id == previousId);
      cursor = matches.isEmpty ? null : matches.first;
    }
    return false;
  }

  void snack(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating),
  );

  Future<void> openDrafts() async {
    await showDialog<void>(context: context, builder: (c) => StatefulBuilder(
      builder: (c, refresh) {
        final keys = widget.prefs.getKeys().where((k) => k.startsWith(EditorDrafts.prefix)).toList()..sort();
        return AlertDialog(title: const Text('本地草稿'), content: SizedBox(
          width: double.maxFinite,
          child: keys.isEmpty ? const Text('没有未保存草稿') : ListView(shrinkWrap: true, children: [
            const Text('草稿未保存为正式记录，不参与周报和备份。来源已删除的草稿可复制后重新整理。'),
            for (final key in keys) ListTile(
              title: Text(() { try { return EditorDrafts(widget.prefs).read(key)?['title'] as String? ?? '未命名草稿'; } catch (_) { return '无法读取的草稿'; } }()),
              subtitle: Text(key.contains('${EditorDrafts.prefix}new_') ? '新建草稿' : records.any((r) => EditorDrafts.key(r.kind, r.id) == key) ? '编辑草稿：打开原记录编辑时可继续' : '原记录已删除，不能覆盖或恢复为正式记录'),
              onTap: () => showDialog<void>(context: c, builder: (preview) => AlertDialog(
                title: const Text('草稿内容'),
                content: SingleChildScrollView(child: SelectableText(EditorDrafts(widget.prefs).readable(key))),
                actions: [
                  TextButton(onPressed: () async {
                    try { await Clipboard.setData(ClipboardData(text: EditorDrafts(widget.prefs).readable(key))); if (mounted) snack('草稿已复制'); }
                    catch (_) { if (mounted) snack('复制失败，可选择草稿文字手动复制'); }
                  }, child: const Text('复制草稿')),
                  TextButton(onPressed: () async {
                    try {
                      await EditorDrafts(widget.prefs).remove(key);
                      if (preview.mounted) Navigator.pop(preview);
                      if (c.mounted) refresh(() {});
                    } catch (_) { if (mounted) snack('草稿清除失败，请重试'); }
                  }, child: const Text('放弃草稿')),
                  TextButton(onPressed: () => Navigator.pop(preview), child: const Text('关闭')),
                ],
              )),
            ),
          ]),
        ), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('关闭'))]);
      },
    ));
  }
  Future<void> restore() async {
    final source = await showDialog<String>(
      context: context,
      builder: (_) => const BackupImportDialog(),
    );
    if (source == null || !mounted) return;
    await restoreSource(source);
  }

  Future<void> restoreSource(String source) async {
    late final List<ResearchRecord> restored;
    try {
      restored = decodeBackup(
        source.startsWith('\ufeff') ? source.substring(1) : source,
      );
    } catch (_) {
      snack('备份内容无效，当前数据未更改');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var backedUp = false;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('确认恢复备份？'),
            content: Text(
              '备份包含 ${restored.length} 条记录。恢复会替换当前 ${records.length} 条记录，并永久清空本地回收站。独立草稿保留，旧记录草稿需核对冲突。请先复制或导出当前备份，再确认覆盖。',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                      ClipboardData(
                        text: dataReadFailed
                            ? (rawStoredData ?? '')
                            : encodeBackup(records),
                      ),
                    );
                    if (dialogContext.mounted) {
                      setDialogState(() => backedUp = true);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('当前备份已复制，请粘贴保存')),
                      );
                    }
                  } on PlatformException catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('复制失败，请先导出备份')),
                      );
                    }
                  } on MissingPluginException catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('复制不可用，请先导出备份')),
                      );
                    }
                  }
                },
                child: const Text('复制当前备份'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final saved = await DocumentFiles.exportText(
                      filename: '研历备份_${dateLabel(DateTime.now())}.json',
                      mime: 'application/json',
                      content: dataReadFailed
                          ? (rawStoredData ?? '')
                          : encodeBackup(records),
                    );
                    if (saved && dialogContext.mounted) {
                      setDialogState(() => backedUp = true);
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(const SnackBar(content: Text('当前备份已导出')));
                    }
                  } on PlatformException catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('导出失败，请重试或取消恢复')),
                      );
                    }
                  } on MissingPluginException catch (_) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('当前平台不支持导出，请复制备份')),
                      );
                    }
                  }
                },
                child: const Text('导出当前备份'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: backedUp
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('确认覆盖'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final success = await commitRecords(
      restored,
      allowRecovery: true,
      replacementTrash: [],
    );
    if (!mounted) return;
    snack(success ? '备份已恢复' : '恢复未确认成功，请检查当前数据和备份');
  }

  Future<void> importBackupFile() async {
    try {
      final content = await DocumentFiles.importText();
      if (content != null && mounted) await restoreSource(content);
    } on PlatformException catch (_) {
      if (mounted) snack('无法读取备份文件，请检查文件后重试');
    } on MissingPluginException catch (_) {
      if (mounted) snack('当前平台不支持文件选择，请使用粘贴恢复');
    }
  }

  Future<void> exportDocument({
    required String filename,
    required String mime,
    required String content,
  }) async {
    try {
      final saved = await DocumentFiles.exportText(
        filename: filename,
        mime: mime,
        content: content,
      );
      if (saved && mounted) snack('文件已导出');
    } on PlatformException catch (_) {
      if (mounted) snack('导出未完成，文件可能不完整，请重新导出');
    } on MissingPluginException catch (_) {
      if (mounted) snack('当前平台不支持文件导出，请使用复制功能');
    }
  }

  Future<void> clearAllData() async {
    if (dataReadFailed) {
      snack('请先复制原始数据并恢复有效备份');
      return;
    }
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部记录？'),
        content: const Text('此操作会永久删除本机全部计划、进展、交流记录、回收站及本地草稿，请先备份。备份不包含草稿。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('再次确认清空'),
        content: const Text('清空后无法在应用内撤销。请确认已经保存需要的备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
    if (second != true || !mounted) return;
    final success = await commitRecords([], replacementTrash: []);
    if (success) {
      try { await EditorDrafts(widget.prefs).clear(); }
      catch (_) { if (mounted) snack('记录已清空，部分草稿清除失败，请再次清空重试'); return; }
    }
    if (mounted) snack(success ? '数据已清空' : '清空未确认成功，请检查数据和备份');
  }

  @override
  Widget build(BuildContext context) {
    final pageBuilders = <Widget Function()>[
      calendarPage,
      () => recordsPage(RecordKind.progress),
      () => recordsPage(RecordKind.mentor),
      reportPage,
      settingsPage,
    ];
    return AbsorbPointer(
      absorbing: restoring,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      selectedIndex: tab,
                      onDestinationSelected: (i) => setState(() => tab = i),
                      backgroundColor: Colors.white,
                      indicatorColor: Colors.transparent,
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month),
                          label: Text('日历'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.auto_stories_outlined),
                          selectedIcon: Icon(Icons.auto_stories),
                          label: Text('进展'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.forum_outlined),
                          selectedIcon: Icon(Icons.forum),
                          label: Text('交流'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.summarize_outlined),
                          selectedIcon: Icon(Icons.summarize),
                          label: Text('周报'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          selectedIcon: Icon(Icons.person),
                          label: Text('我的'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: IndexedStack(index: tab, children: [
                          for (var i = 0; i < pageBuilders.length; i++)
                            _RetainedPage(key: ValueKey('tab-$i'), active: tab == i, builder: pageBuilders[i]),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: tab,
                    backgroundColor: Colors.white,
                    indicatorColor: Colors.transparent,
                    onDestinationSelected: (i) => setState(() => tab = i),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        selectedIcon: Icon(Icons.calendar_month),
                        label: '日历',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.auto_stories_outlined),
                        selectedIcon: Icon(Icons.auto_stories),
                        label: '进展',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.forum_outlined),
                        selectedIcon: Icon(Icons.forum),
                        label: '交流',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.summarize_outlined),
                        selectedIcon: Icon(Icons.summarize),
                        label: '周报',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: '我的',
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget header(
    String eyebrow,
    String title, {
    String? subtitle,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
  Widget panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe5e5ea), width: .5),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  void selectDate(DateTime date) {
    if (agendaController.isAttached) {
      agendaController.jumpTo(agendaController.size);
    }
    setState(() {
      selected = dayOnly(date);
      dateNavigationRevision++;
    });
    if (agendaController.isAttached) {
      if (MediaQuery.disableAnimationsOf(context)) {
        agendaController.jumpTo(.35);
        return;
      }
      agendaController.animateTo(
        .35,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> chooseCalendarRecord() async {
    final kind = await showModalBottomSheet<RecordKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              (RecordKind.task, '新建计划', Icons.edit_calendar_outlined),
              (RecordKind.progress, '新建进展', Icons.auto_stories_outlined),
              (RecordKind.mentor, '新建交流', Icons.forum_outlined),
            ])
              ListTile(
                leading: Icon(entry.$3, color: calendarRed),
                title: Text(entry.$2),
                onTap: () => Navigator.pop(context, entry.$1),
              ),
          ],
        ),
      ),
    );
    if (kind != null && mounted) await edit(kind);
  }

  Widget calendarTools() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const ValueKey('calendar-view-toggle'),
        tooltip: monthExpanded ? '收起月历' : '展开月历',
        onPressed: () => setState(() => monthExpanded = !monthExpanded),
        icon: Icon(
          monthExpanded
              ? Icons.view_week_outlined
              : Icons.calendar_month_outlined,
        ),
      ),
      IconButton(
        key: const ValueKey('calendar-create'),
        tooltip: '新建',
        onPressed: chooseCalendarRecord,
        icon: const Icon(Icons.add),
      ),
    ],
  );

  Widget weekCalendar(Map<DateTime, Set<RecordKind>> visibleRecords) {
    final start = weekStart(selected);
    final today = dayOnly(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: panel(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: '上一周',
                  onPressed: () =>
                      selectDate(selected.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${selected.year}年${selected.month}月',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '下一周',
                  onPressed: () =>
                      selectDate(selected.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (index) {
                final date = start.add(Duration(days: index));
                final active = date == selected;
                final isToday = date == today;
                final hasRecords = visibleRecords.containsKey(date);
                final weekday = ['一', '二', '三', '四', '五', '六', '日'][index];
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: active,
                    onTap: () => selectDate(date),
                    label:
                        '${date.month}月${date.day}日，星期$weekday'
                        '${isToday ? '，今天' : ''}'
                        '${hasRecords ? '，有记录' : ''}',
                    child: ExcludeSemantics(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => selectDate(date),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                weekday,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 34,
                                  minHeight: 34,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? calendarRed
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${date.day}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : isToday
                                        ? calendarRed
                                        : ink,
                                    fontWeight: active || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: hasRecords
                                      ? muted
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget calendarPage() {
    final rows = sorted(records.where((r) => dayOnly(r.date) == selected))
      ..sort((a, b) {
        int rank(ResearchRecord r) =>
            r.kind == RecordKind.task ? (r.done ? 3 : 0) : r.kind.index;
        final group = rank(a).compareTo(rank(b));
        if (group != 0) return group;
        if (a.kind == RecordKind.task) {
          return recordPriorities
              .indexOf(a.priority)
              .compareTo(recordPriorities.indexOf(b.priority));
        }
        return b.date.compareTo(a.date);
      });
    final done = rows.where((r) => r.kind == RecordKind.task && r.done).length;
    final tasks = rows.where((r) => r.kind == RecordKind.task).length;
    final start = weekStart(selected);
    final end = start.add(const Duration(days: 7));
    final weekly = records
        .where(
          (r) =>
              !dayOnly(r.date).isBefore(start) && dayOnly(r.date).isBefore(end),
        )
        .toList();
    final weekTasks = weekly.where((r) => r.kind == RecordKind.task).toList();
    final weekDone = weekTasks.where((r) => r.done).length;
    final weekProgress = weekly
        .where((r) => r.kind == RecordKind.progress)
        .length;
    final rate = weekTasks.isEmpty
        ? '暂无计划'
        : '${(weekDone * 100 / weekTasks.length).toStringAsFixed(1)}%';
    final visibleRecords = <DateTime, Set<RecordKind>>{};
    for (final record in records) {
      final date = dayOnly(record.date);
      visibleRecords.putIfAbsent(date, () => <RecordKind>{}).add(record.kind);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final initialSize = MediaQuery.textScalerOf(context).scale(14) > 18
            ? .56
            : .32;
        return ColoredBox(
          color: Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (monthExpanded)
                ScrollingCalendar(
                  expand: true,
                  selectedDate: selected,
                  navigationRevision: dateNavigationRevision,
                  records: visibleRecords,
                  recordCounts: {
                    for (final date in visibleRecords.keys)
                      date: records
                          .where((r) => dayOnly(r.date) == date)
                          .length,
                  },
                  onDateSelected: selectDate,
                  buttonStyle: glassButtonStyle(),
                  headerActions: calendarTools(),
                ),
              if (!monthExpanded)
                Column(
                  children: [
                    SizedBox(
                      height: 76,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '周视图',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            calendarTools(),
                          ],
                        ),
                      ),
                    ),
                    weekCalendar(visibleRecords),
                  ],
                ),
              DraggableScrollableSheet(
                key: const ValueKey('calendar-agenda-sheet'),
                controller: agendaController,
                minChildSize: .18,
                initialChildSize: initialSize,
                maxChildSize: .85,
                builder: (context, scrollController) => ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  child: BackdropFilter(
                    enabled: false,
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                        border: Border.all(
                          color: const Color(0xffe5e5ea),
                          width: .5,
                        ),
                      ),
                      child: ListView(
                        key: const ValueKey('calendar-agenda-list'),
                        controller: scrollController,
                        primary: false,
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          Center(
                            child: Container(
                              key: const ValueKey('calendar-agenda-handle'),
                              width: 38,
                              height: 5,
                              margin: const EdgeInsets.only(top: 10, bottom: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xffc7c7cc),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${selected.month}月${selected.day}日 · '
                                        '${selected == dayOnly(DateTime.now()) ? '今日日程' : '科研日程'}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          selectDate(DateTime.now()),
                                      child: const Text('今天'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '已完成 $done / $tasks 项计划',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: muted,
                                  ),
                                ),
                                Text(
                                  '计划 ${rows.where((r) => r.kind == RecordKind.task).length} · 进展 ${rows.where((r) => r.kind == RecordKind.progress).length} · 交流 ${rows.where((r) => r.kind == RecordKind.mentor).length}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => edit(RecordKind.task),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('新建计划'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          edit(RecordKind.progress),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('新建进展'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => edit(RecordKind.mentor),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: const Text('新建交流'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (rows.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: emptyState(
                                Icons.edit_calendar_outlined,
                                '这一天还没有记录',
                                '点击新建添加计划、进展或交流',
                              ),
                            )
                          else
                            ...List.generate(rows.length, (index) {
                              final r = rows[index];
                              String group(ResearchRecord item) =>
                                  switch (item.kind) {
                                    RecordKind.task =>
                                      item.done ? '已完成计划' : '未完成计划',
                                    RecordKind.progress => '科研进展',
                                    RecordKind.mentor => '导师交流',
                                  };
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  9,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (index == 0 ||
                                        group(rows[index - 1]) != group(r))
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          group(r),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    recordTile(r),
                                  ],
                                ),
                              );
                            }),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                            child: Text(
                              '所选周计划 ${weekTasks.length} 项 · 已完成 $weekDone 项 · 完成率 $rate · 进展 $weekProgress 条',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget emptyState(IconData icon, String title, String desc) => panel(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, size: 31, color: calendarRed),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
  Widget recordTile(ResearchRecord r) {
    final kindLabel = switch (r.kind) {
      RecordKind.task => '计划',
      RecordKind.progress => '进展',
      RecordKind.mentor => '交流',
    };
    final icon = switch (r.kind) {
      RecordKind.task => Icons.check_circle_outline,
      RecordKind.progress => Icons.auto_stories_outlined,
      RecordKind.mentor => Icons.forum_outlined,
    };
    return Dismissible(
      key: ValueKey('record-swipe-${r.id}'),
      direction: dataReadFailed || restoring
          ? DismissDirection.none
          : DismissDirection.startToEnd,
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: calendarRed,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await remove(r);
        // Persistence owns removal; never optimistically dismiss a record.
        return false;
      },
      child: panel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.kind == RecordKind.task)
              Checkbox(
                value: r.done,
                onChanged: dataReadFailed || restoring
                    ? null
                    : (v) async {
                        if (records.any((e) => e.id == r.id)) {
                          final changed = r.copyWith(
                            done: v ?? false,
                            completedAt: (v ?? false) ? DateTime.now() : null,
                            updatedAt: DateTime.now().toUtc(),
                          );
                          final updated = upsertLinkedRecord(records, changed);
                          if (!await commitRecords(updated) && mounted) {
                            snack('状态保存未确认，请重试');
                          }
                        }
                      },
                activeColor: calendarRed,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Icon(icon, color: calendarRed, size: 23),
              ),
            Expanded(
              child: InkWell(
                onTap: () => openDetails(r),
                child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        decoration: r.done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$kindLabel · ${dateLabel(r.date)}${r.kind == RecordKind.task
                          ? ' · ${r.priority}优先级${r.plannedTime == null ? '' : ' · ${r.plannedTime}'}'
                          : r.kind == RecordKind.progress
                          ? ' · ${r.progressType}${r.durationMinutes == null ? '' : ' · ${r.durationMinutes}分钟'}'
                          : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    if (r.detail.isNotEmpty)
                      Text(
                        r.detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    if (r.sourceDiscussionId != null)
                      TextButton(
                        onPressed: () {
                          final source = records.where(
                            (item) => item.id == r.sourceDiscussionId,
                          );
                          if (source.isNotEmpty) {
                            openDetails(source.first);
                          }
                        },
                        child: const Text('返回原交流'),
                      ),
                    if (r.kind == RecordKind.mentor)
                      Material(
                        type: MaterialType.transparency,
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text(
                            '交流详情与跟进',
                            style: TextStyle(fontSize: 13),
                          ),
                          children: [
                            if (r.detail.isNotEmpty) Text(r.detail),
                            if (r.kind == RecordKind.mentor &&
                                r.mentorName.isNotEmpty)
                              Text(
                                '交流对象：${r.mentorName}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            if (r.kind == RecordKind.mentor &&
                                r.nextMeetingDate != null)
                              Text(
                                '下次交流：${dateLabel(r.nextMeetingDate!)}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            if (r.kind == RecordKind.mentor &&
                                r.previousFollowUp.isNotEmpty)
                              Text(
                                '上次要求落实：${r.previousFollowUp}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            if (r.previousDiscussionId != null)
                              ...records
                                  .where(
                                    (previous) =>
                                        previous.id == r.previousDiscussionId,
                                  )
                                  .map(
                                    (previous) => TextButton(
                                      onPressed: () => openDetails(previous),
                                      child: Text(
                                        '查看上次交流：${dateLabel(previous.date)} ${previous.title}',
                                      ),
                                    ),
                                  ),
                            for (final action in r.mentorActions)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      action.text,
                                      style: TextStyle(
                                        decoration: action.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    MentorStatusPicker(
                                      value: action.status,
                                      onChanged: dataReadFailed || restoring
                                          ? null
                                          : (value) async {
                                              final updated =
                                                  List<ResearchRecord>.of(
                                                    records,
                                                  );
                                              final index = updated.indexWhere(
                                                (record) => record.id == r.id,
                                              );
                                              if (index < 0) return;
                                              final current = updated[index];
                                              updated[index] = current.copyWith(
                                                updatedAt: DateTime.now()
                                                    .toUtc(),
                                                mentorActions: current
                                                    .mentorActions
                                                    .map(
                                                      (a) => a.id == action.id
                                                          ? a.copyWith(
                                                              status: value,
                                                            )
                                                          : a,
                                                    )
                                                    .toList(),
                                              );
                                              if (!await commitRecords(
                                                    upsertLinkedRecord(
                                                      records,
                                                      updated[index],
                                                    ),
                                                  ) &&
                                                  mounted) {
                                                snack('跟进状态保存未确认，请重试');
                                              }
                                            },
                                    ),
                                    TextButton(
                                      onPressed: restoring || dataReadFailed
                                          ? null
                                          : () async {
                                              final linked = records.where(
                                                (item) =>
                                                    item.sourceDiscussionId ==
                                                        r.id &&
                                                    item.sourceMentorActionId ==
                                                        action.id,
                                              );
                                              if (linked.isNotEmpty) {
                                                await edit(
                                                  RecordKind.task,
                                                  record: linked.first,
                                                );
                                              } else {
                                                final success =
                                                    await commitRecords(
                                                      planMentorAction(
                                                        records,
                                                        r,
                                                        action,
                                                        selected,
                                                        DateTime.now(),
                                                      ),
                                                    );
                                                if (mounted) {
                                                  snack(
                                                    success
                                                        ? '已转为计划，可从计划返回原交流'
                                                        : '转计划失败，请重试',
                                                  );
                                                }
                                              }
                                            },
                                      child: Text(
                                        records.any(
                                              (item) =>
                                                  item.sourceDiscussionId ==
                                                      r.id &&
                                                  item.sourceMentorActionId ==
                                                      action.id,
                                            )
                                            ? '查看关联计划'
                                            : '转为计划',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (r.problem.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${r.kind == RecordKind.mentor ? '交流结论' : '遇到的问题'}：${r.problem}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    if (r.next.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '下一步：${r.next}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              ),
            ),
            FrostedPopupMenu<String>(
              icon: const Icon(Icons.more_horiz, color: muted),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    edit(r.kind, record: r);
                  case 'tomorrow':
                    moveTask(r, tomorrow: true);
                  case 'date':
                    moveTask(r);
                  case 'delete':
                    remove(r);
                }
              },
              items: [
                const DropdownMenuItem(value: 'edit', child: Text('编辑')),
                if (r.kind == RecordKind.task && !r.done) ...[
                  const DropdownMenuItem(
                    value: 'tomorrow',
                    child: Text('移到明天'),
                  ),
                  const DropdownMenuItem(value: 'date', child: Text('移到指定日期')),
                ],
                const DropdownMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget recordsPage(RecordKind kind) {
    final progress = kind == RecordKind.progress;
    final rows = sorted(records.where((r) => r.kind == kind));
    return ListView(
      key: ValueKey('records-${kind.name}-$progressSearchRevision'),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        header(
          '',
          progress ? '科研进展' : '导师交流',
          subtitle: '已记录 ${rows.length} 条',
          trailing: FilledButton(onPressed: () => edit(kind), child: const Text('新建')),
        ),
        if (progress && rows.isEmpty)
          Center(
            child: TextButton(
              style: glassButtonStyle(),
              onPressed: restoring || dataReadFailed ? null : addDemoProgress,
              child: const Text('添加测试进展'),
            ),
          ),
          ProgressSearch(
            key: ValueKey('search-${kind.name}-$progressSearchRevision'),
            mentor: !progress,
            records: rows,
            onCreate: () => edit(kind),
            recordBuilder: (r) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
              child: recordTile(r),
            ),
          ),
      ],
    );
  }

  Widget reportPage() {
    final start = customReportRange?.start ?? reportWeek;
    final end =
        customReportRange?.end ?? reportWeek.add(const Duration(days: 6));
    final reportData = RangeReport.generate(
      records: records,
      start: start,
      end: end,
      generatedAt: reportGeneratedAt,
    );
    final report = reportData.toMarkdown();
    final within = records
        .where(
          (r) =>
              !dayOnly(r.date).isBefore(start) && !dayOnly(r.date).isAfter(end),
        )
        .length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        header('', '科研周报'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择汇报范围',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      tooltip: '上一周',
                      onPressed: () => setState(() {
                        reportWeek = weekStart(
                          start,
                        ).subtract(const Duration(days: 7));
                        customReportRange = null;
                        reportGeneratedAt = DateTime.now();
                      }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${dateLabel(start)}  —  ${dateLabel(end)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '下一周',
                      onPressed: () => setState(() {
                        reportWeek = weekStart(
                          start,
                        ).add(const Duration(days: 7));
                        customReportRange = null;
                        reportGeneratedAt = DateTime.now();
                      }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100, 12, 31),
                        initialDateRange: DateTimeRange(start: start, end: end),
                      );
                      if (range != null && mounted) {
                        setState(() {
                          customReportRange = range;
                          reportGeneratedAt = DateTime.now();
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: const Text('自选日期'),
                  ),
                ),
                Center(
                  child: Text(
                    '范围内共 $within 条记录',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 2, 22, 10),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '周报预览',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              TextButton(
                onPressed: () {
                  final ids = reportData.sections
                      .expand((section) => section.items)
                      .expand((item) => item.sources)
                      .map((source) => source.recordId)
                      .toSet();
                  final sources = records
                      .where((record) => ids.contains(record.id))
                      .toList();
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('汇报来源记录'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: sources.isEmpty
                            ? const Text('暂无来源记录')
                            : ListView(
                                shrinkWrap: true,
                                children: sources
                                    .map(
                                      (record) => ListTile(
                                        title: Text(record.title),
                                        subtitle: Text(
                                          '${dateLabel(record.date)} · ${switch (record.kind) {
                                            RecordKind.task => '计划',
                                            RecordKind.progress => '进展',
                                            RecordKind.mentor => '交流',
                                          }}',
                                        ),
                                        onTap: () {
                                          Navigator.pop(dialogContext);
                                          openDetails(record);
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('查看来源'),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await Clipboard.setData(ClipboardData(text: report));
                    if (mounted) snack('周报已复制');
                  } on PlatformException catch (_) {
                    if (mounted) snack('复制失败，可选择下方汇报文字手动复制');
                  } on MissingPluginException catch (_) {
                    if (mounted) snack('复制不可用，可选择下方汇报文字手动复制');
                  }
                },
                icon: const Icon(Icons.copy, size: 17),
                label: const Text('复制周报'),
              ),
            ],
          ),
        ),
        for (final r in records.where(
          (r) =>
              !dayOnly(r.date).isBefore(start) &&
              !dayOnly(r.date).isAfter(end) &&
              ((r.kind == RecordKind.mentor && r.problem.trim().isEmpty) ||
                  (r.kind != RecordKind.task &&
                      r.next.trim().isEmpty &&
                      r.mentorActions.isEmpty)),
        ))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: ListTile(
              title: Text(r.title),
              subtitle: Text(
                [
                  if (r.kind == RecordKind.mentor && r.problem.trim().isEmpty)
                    '缺交流结论',
                  if (r.next.trim().isEmpty && r.mentorActions.isEmpty) '缺下一步',
                ].join('、'),
              ),
              trailing: TextButton(
                onPressed: () => edit(r.kind, record: r),
                child: const Text('补写'),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => exportDocument(
                filename: '研历汇报_${dateLabel(start)}_${dateLabel(end)}.md',
                mime: 'text/markdown',
                content: report,
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('导出 Markdown 文件'),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: panel(
            child: Column(children: [
              ReportSummary(
                key: ValueKey('summary:${dateLabel(start)}:${dateLabel(end)}'),
                report: reportData,
                prefs: widget.prefs,
                onOpenSource: (source) {
                  final matches = records.where((r) => r.id == source.recordId);
                  if (matches.isEmpty) { snack('来源记录已删除'); return; }
                  openDetails(matches.first);
                },
              ),
              const Divider(height: 32),
              ReportPreview(
              report: reportData,
              recordCount: within,
              onOpenSource: (source) {
                final matches = records.where((r) => r.id == source.recordId);
                if (matches.isEmpty) {
                  snack('来源记录已删除，请重新查看汇报');
                  return;
                }
                openDetails(matches.first);
              },
            ),
          ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Text(
            '内容来自你填写的记录，复制后可按需要继续修改。',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget settingsPage() => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      header('', '我的研历'),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 5, 20, 16),
        child: panel(
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: calendarRed,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '研历 YanLi',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '本地科研记录',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (loadError != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Text(loadError!, style: const TextStyle(color: Colors.red)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: panel(
          child: ExpansionTile(
            title: const Text('开发与测试'),
            tilePadding: EdgeInsets.zero,
            children: [Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '测试数据',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '确认后添加12条【测试】示例，不覆盖已有记录。各浏览器数据独立；重复添加按固定ID跳过，回收站内容保留。',
                style: TextStyle(color: muted, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: glassButtonStyle(),
                onPressed: restoring || dataReadFailed ? null : addDemoProgress,
                child: const Text('添加测试进展'),
              ),
            ],
          )],),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '数据管理',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '数据保存在当前设备。备份仅包含有效记录，不含回收站和草稿；恢复会清空回收站，保留独立草稿并检查冲突。清空数据会同时清除草稿。',
                style: TextStyle(color: muted, height: 1.5, fontSize: 13),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: const Text('本地草稿'),
                subtitle: const Text('查看、复制或放弃未保存内容'),
                trailing: const Icon(Icons.chevron_right),
                onTap: openDrafts,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline),
                title: Text('回收站（${trash.length}）'),
                subtitle: Text('保留 $retentionDays 天，可恢复误删记录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: dataReadFailed ? null : openRecycleBin,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: dataReadFailed
                                ? (rawStoredData ?? '')
                                : encodeBackup(records),
                          ),
                        );
                        if (mounted) {
                          snack(
                            dataReadFailed ? '原始数据已复制，请粘贴保存' : '备份已复制，请粘贴保存',
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(dataReadFailed ? '复制原始数据' : '复制备份'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: restore,
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('恢复备份'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => exportDocument(
                      filename: '研历备份_${dateLabel(DateTime.now())}.json',
                      mime: 'application/json',
                      content: dataReadFailed
                          ? (rawStoredData ?? '')
                          : encodeBackup(records),
                    ),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(dataReadFailed ? '导出原始数据' : '导出备份文件'),
                  ),
                  OutlinedButton.icon(
                    onPressed: importBackupFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('从文件恢复'),
                  ),
                  TextButton.icon(
                    onPressed: clearAllData,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('清空数据'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: panel(
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '每日提醒',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const ValueKey('daily-reminder-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('提醒记录科研进展'),
                  subtitle: const Text('每天提醒一次，帮助持续记录'),
                  value: reminderEnabled,
                  onChanged: reminderSettingsReady && !reminderBusy
                      ? _setDailyReminderEnabled
                      : null,
                ),
                ListTile(
                  key: const ValueKey('daily-reminder-time'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('提醒时间'),
                  trailing: Text(
                    TimeOfDay(
                      hour: reminderMinutesAfterMidnight ~/ 60,
                      minute: reminderMinutesAfterMidnight % 60,
                    ).format(context),
                    style: const TextStyle(
                      color: calendarRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  enabled: reminderSettingsReady && !reminderBusy,
                  onTap: _chooseDailyReminderTime,
                ),
                if (reminderError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      reminderError!,
                      style: const TextStyle(color: calendarRed, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(24, 22, 24, 0),
        child: Text(
          '第一版 · 离线使用',
          style: TextStyle(color: muted, fontSize: 12, height: 1.7),
        ),
      ),
    ],
  );
}

class _RetainedPage extends StatefulWidget {
  const _RetainedPage({super.key, required this.active, required this.builder});
  final bool active;
  final Widget Function() builder;
  @override
  State<_RetainedPage> createState() => _RetainedPageState();
}

class _RetainedPageState extends State<_RetainedPage> {
  Widget? cached;
  @override
  Widget build(BuildContext context) {
    if (widget.active) cached = widget.builder();
    return Offstage(offstage: !widget.active, child: TickerMode(enabled: widget.active,
      child: PrimaryScrollController.none(child: cached ?? const SizedBox.shrink())));
  }
}

class BackupImportDialog extends StatefulWidget {
  const BackupImportDialog({super.key});
  @override
  State<BackupImportDialog> createState() => _BackupImportDialogState();
}

class _BackupImportDialogState extends State<BackupImportDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('恢复备份'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('粘贴之前复制的备份内容。恢复会替换当前全部记录。'),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          minLines: 4,
          maxLines: 7,
          decoration: const InputDecoration(hintText: '在此粘贴备份内容'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('恢复'),
      ),
    ],
  );
}

class MentorActionDraft {
  MentorActionDraft({
    required this.id,
    required String text,
    this.status = MentorActionStatus.pending,
  }) : controller = TextEditingController(text: text);
  final String id;
  final TextEditingController controller;
  MentorActionStatus status;
}

class RecordEditor extends StatefulWidget {
  const RecordEditor({
    super.key,
    required this.kind,
    required this.initialDate,
    this.record,
    this.onSave,
    this.previousDiscussions = const [],
    this.prefs,
  });
  final SharedPreferences? prefs;
  final Future<bool> Function(ResearchRecord)? onSave;
  final RecordKind kind;
  final DateTime initialDate;
  final ResearchRecord? record;
  final List<ResearchRecord> previousDiscussions;
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor>
    with WidgetsBindingObserver {
  static const voiceChannel = VoiceInput();
  TextEditingController? voiceTarget;
  int voiceSession = 0;
  bool finishingVoice = false;
  bool savingEditor = false;
  late final String draftId;
  late final DateTime draftCreatedAt;
  bool showMetadata = false;
  late bool showProgressDetails;
  late bool hasLegacyNext;
  ResearchRecord? lastFailedDraft;
  late DateTime date;
  late final TextEditingController title;
  late final TextEditingController detail;
  late final TextEditingController problem;
  late final TextEditingController next;
  late final TextEditingController duration;
  late final TextEditingController mentorName;
  late final TextEditingController previousFollowUp;
  late final List<MentorActionDraft> mentorActions;
  DateTime? nextMeetingDate;
  String? previousDiscussionId;
  int actionCounter = 0;
  final retiredActionControllers = <TextEditingController>[];
  late String priority;
  late String progressType;
  String? plannedTime;
  EditorDrafts? drafts;
  late final String draftKey;
  Timer? draftTimer;
  bool draftReady = false;
  bool draftFinished = false;
  bool applyingDraft = false;
  String? draftError;

  List<TextEditingController> get draftControllers => [title, detail, problem, next, duration, mentorName, previousFollowUp, ...mentorActions.map((a) => a.controller)];

  Map<String, dynamic> draftData() => {
    'base': EditorDrafts.fingerprint(widget.record),
    'title': title.text, 'detail': detail.text, 'problem': problem.text,
    'next': next.text, 'duration': duration.text, 'mentorName': mentorName.text,
    'previousFollowUp': previousFollowUp.text, 'date': date.toIso8601String(),
    'priority': priority, 'progressType': progressType, 'plannedTime': plannedTime,
    'nextMeetingDate': nextMeetingDate?.toIso8601String(),
    'previousDiscussionId': previousDiscussionId,
    'actions': [for (final a in mentorActions) {'id': a.id, 'text': a.controller.text, 'status': a.status.name}],
  };

  void scheduleDraft() {
    if (!draftReady || draftFinished || applyingDraft || drafts == null) return;
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 350), () => unawaited(flushDraft()));
  }

  Future<bool> flushDraft() async {
    draftTimer?.cancel();
    if (!draftReady || draftFinished || drafts == null) return true;
    try {
      if (hasChanges) {
        await drafts!.write(draftKey, draftData());
      } else {
        await drafts!.remove(draftKey);
      }
      if (mounted && draftError != null) super.setState(() => draftError = null);
      return true;
    } catch (_) {
      if (mounted) super.setState(() => draftError = '草稿暂未保存到设备，请重试；当前输入仍保留');
      return false;
    }
  }

  Future<bool> clearDraft() async {
    draftTimer?.cancel();
    try {
      await drafts?.remove(draftKey);
      draftFinished = true;
      return true;
    } catch (_) {
      if (mounted) super.setState(() => draftError = '草稿清除失败，请重试');
      return false;
    }
  }

  Future<void> restoreDraft() async {
    Map<String, dynamic>? data;
    try { data = drafts?.read(draftKey); } catch (_) {
      draftError = '草稿无法读取，可放弃此草稿后重新填写';
    }
    if (!mounted) return;
    if (data != null || draftError != null) {
      final conflict = data != null && data['base'] != EditorDrafts.fingerprint(widget.record);
      final choice = await showDialog<String>(context: context, barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text(conflict ? '原记录已更新' : '发现未保存草稿'),
          content: SingleChildScrollView(child: Text(conflict
            ? '此草稿基于旧记录，不能直接覆盖当前记录。可复制草稿后对照补写。\n${data!['title'] ?? ''}'
            : '草稿仅保存在此设备，尚未保存为正式记录。'),),
          actions: [
            if (conflict) TextButton(onPressed: () async {
              try { await Clipboard.setData(ClipboardData(text: drafts!.readable(draftKey))); }
              catch (_) { return; }
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('草稿已复制')));
            }, child: const Text('复制草稿')),
            TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('放弃草稿')),
            if (!conflict && data != null) FilledButton(onPressed: () => Navigator.pop(c, 'resume'), child: const Text('继续草稿')),
            if (conflict) TextButton(onPressed: () => Navigator.pop(c, 'keep'), child: const Text('保留草稿并关闭')),
          ],
        ));
      if (!mounted) return;
      if (choice == 'keep') { Navigator.pop(context); return; }
      if (choice == 'discard') {
        if (!await clearDraft()) {
          if (mounted) super.setState(() => draftReady = true);
          return;
        }
        draftFinished = false;
      } else if (data != null) {
        try {
          applyingDraft = true;
          final d = data;
          // Parse before mutating controllers, preserving the current record on malformed data.
          final restoredDate = DateTime.parse(d['date'] as String);
          final actions = (d['actions'] as List).map((item) => MentorActionDraft(
            id: item['id'] as String, text: item['text'] as String,
            status: MentorActionStatus.values.byName(item['status'] as String))).toList();
          if (!recordPriorities.contains(d['priority']) || !researchTypes.contains(d['progressType'])) throw const FormatException();
          title.text = d['title'] as String; detail.text = d['detail'] as String;
          problem.text = d['problem'] as String; next.text = d['next'] as String;
          duration.text = d['duration'] as String; mentorName.text = d['mentorName'] as String;
          previousFollowUp.text = d['previousFollowUp'] as String;
          date = restoredDate; priority = d['priority'] as String;
          progressType = d['progressType'] as String; plannedTime = d['plannedTime'] as String?;
          nextMeetingDate = d['nextMeetingDate'] == null ? null : DateTime.parse(d['nextMeetingDate'] as String);
          final previousId = d['previousDiscussionId'] as String?;
          previousDiscussionId = widget.previousDiscussions.any((r) => r.id == previousId) ? previousId : null;
          for (final a in mentorActions) { retiredActionControllers.add(a.controller); }
          mentorActions..clear()..addAll(actions);
          for (final a in actions) { a.controller.addListener(scheduleDraft); }
          hasLegacyNext = widget.kind == RecordKind.mentor && next.text.isNotEmpty;
          showProgressDetails = problem.text.isNotEmpty || next.text.isNotEmpty || duration.text.isNotEmpty;
          showMetadata = true;
        } catch (_) { draftError = '草稿内容不完整，请核对后重试或放弃草稿'; }
        finally { applyingDraft = false; }
      }
    }
    if (mounted) super.setState(() => draftReady = true);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    scheduleDraft();
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    draftId = widget.record?.id ?? '${DateTime.now().microsecondsSinceEpoch}';
    draftCreatedAt = DateTime.now().toUtc();
    date = widget.record?.date ?? widget.initialDate;
    title = TextEditingController(text: widget.record?.title);
    detail = TextEditingController(text: widget.record?.detail);
    problem = TextEditingController(text: widget.record?.problem);
    next = TextEditingController(text: widget.record?.next);
    hasLegacyNext = widget.kind == RecordKind.mentor && next.text.isNotEmpty;
    duration = TextEditingController(
      text: widget.record?.durationMinutes?.toString() ?? '',
    );
    mentorName = TextEditingController(text: widget.record?.mentorName ?? '');
    previousFollowUp = TextEditingController(
      text: widget.record?.previousFollowUp ?? '',
    );
    nextMeetingDate = widget.record?.nextMeetingDate;
    previousDiscussionId = widget.record?.previousDiscussionId;
    mentorActions = (widget.record?.mentorActions ?? [])
        .map((a) => MentorActionDraft(id: a.id, text: a.text, status: a.status))
        .toList();
    priority = widget.record?.priority ?? '中';
    progressType = widget.record?.progressType ?? '其他活动';
    plannedTime = widget.record?.plannedTime;
    showProgressDetails =
        widget.kind == RecordKind.progress &&
        (problem.text.isNotEmpty ||
            next.text.isNotEmpty ||
            duration.text.isNotEmpty);
        drafts = widget.prefs == null ? null : EditorDrafts(widget.prefs!);
        draftKey = EditorDrafts.key(widget.kind, widget.record?.id);
        for (final c in draftControllers) { c.addListener(scheduleDraft); }
        if (drafts == null) { draftReady = true; }
        else { WidgetsBinding.instance.addPostFrameCallback((_) => restoreDraft()); }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(flushDraft());
    if (state == AppLifecycleState.paused && voiceTarget != null) {
      cancelVoice();
    }
  }

  Future<void> cancelVoice() async {
    if (voiceTarget == null) return;
    voiceSession++;
    restoreVoiceText?.call();
    restoreVoiceText = null;
    if (mounted) {
      setState(() {
        voiceTarget = null;
        finishingVoice = false;
      });
    }
    try {
      await voiceChannel.invokeMethod<void>('cancel');
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  VoidCallback? restoreVoiceText;

  Future<void> startVoice(TextEditingController controller) async {
    if (voiceTarget != null) return;
    final session = ++voiceSession;
    final selection = controller.selection;
    final insertionPoint = selection.isValid
        ? selection.extentOffset
        : controller.text.length;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      voiceTarget = controller;
      finishingVoice = false;
    });
    final original = controller.value;
    restoreVoiceText = () => controller.value = original;
    void updateRecognized(String recognized) {
      if (!mounted || session != voiceSession) return;
      final text = original.text;
      final offset = insertionPoint.clamp(0, text.length);
      final inserted = controller == title
          ? recognized.characters.take((100 - text.characters.length).clamp(0, 100)).toString()
          : recognized;
      controller.value = TextEditingValue(
        text: text.substring(0, offset) + inserted + text.substring(offset),
        selection: TextSelection.collapsed(offset: offset + inserted.length),
      );
    }
    try {
      final recognized = await voiceChannel.start(onPartial: updateRecognized);
      if (!mounted ||
          session != voiceSession ||
          recognized == null ||
          recognized.isEmpty) {
        return;
      }
      final text = original.text;
      final inserted = controller == title
          ? recognized.characters
                .take((100 - text.characters.length).clamp(0, 100))
                .toString()
          : recognized;
      if (inserted.characters.length < recognized.characters.length) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('标题已达到字数上限，超出的语音文字未插入')));
      }
      updateRecognized(recognized);
    } on PlatformException catch (error) {
      if (mounted && session == voiceSession && error.code != 'cancelled') {
        controller.value = original;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${error.message ?? '语音识别不可用'}，请使用键盘输入')),
        );
      }
    } on MissingPluginException catch (_) {
      if (mounted && session == voiceSession) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('当前设备不支持离线语音输入，请使用键盘输入')));
      }
    } finally {
      if (mounted && session == voiceSession) {
        restoreVoiceText = null;
        setState(() {
          voiceTarget = null;
          finishingVoice = false;
        });
      }
    }
  }

  Future<void> stopVoice() async {
    if (voiceTarget == null || finishingVoice) return;
    setState(() => finishingVoice = true);
    try {
      await voiceChannel.invokeMethod<void>('stop');
    } on PlatformException catch (_) {
      await cancelVoice();
    } on MissingPluginException catch (_) {
      await cancelVoice();
    }
  }

  Widget voiceControls(TextEditingController controller) {
    if (voiceTarget != controller) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(finishingVoice ? '正在识别…' : kIsWeb ? '正在听写，停顿后自动结束' : '正在聆听，请说话'),
        TextButton(
          onPressed: finishingVoice ? null : stopVoice,
          child: const Text('完成语音'),
        ),
        TextButton(onPressed: cancelVoice, child: const Text('取消语音')),
      ],
    );
  }

  Widget voiceButton(TextEditingController controller) => IconButton(
    tooltip: '语音输入',
    onPressed: voiceTarget == null ? () => startVoice(controller) : null,
    icon: const Icon(Icons.mic_none),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    draftTimer?.cancel();
    // Capture values synchronously before controllers are disposed.
    if (draftReady && !draftFinished && drafts != null && hasChanges) {
      unawaited(drafts!.write(draftKey, draftData()).catchError((Object _) {}));
    }
    if (voiceTarget != null) {
      voiceSession++;
      voiceChannel.invokeMethod<void>('cancel').catchError((_) {});
    }
    title.dispose();
    detail.dispose();
    problem.dispose();
    next.dispose();
    duration.dispose();
    mentorName.dispose();
    previousFollowUp.dispose();
    for (final action in mentorActions) {
      action.controller.dispose();
    }
    for (final controller in retiredActionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get hasChanges {
    final original = widget.record;
    if (title.text != (original?.title ?? '') ||
        detail.text != (original?.detail ?? '') ||
        problem.text != (original?.problem ?? '') ||
        next.text != (original?.next ?? '') ||
        duration.text != (original?.durationMinutes?.toString() ?? '') ||
        mentorName.text != (original?.mentorName ?? '') ||
        previousFollowUp.text != (original?.previousFollowUp ?? '') ||
        dayOnly(date) != dayOnly(original?.date ?? widget.initialDate) ||
        priority != (original?.priority ?? '中') ||
        progressType != (original?.progressType ?? '其他活动') ||
        plannedTime != original?.plannedTime ||
        nextMeetingDate != original?.nextMeetingDate ||
        previousDiscussionId != original?.previousDiscussionId) {
      return true;
    }
    final originalActions = original?.mentorActions ?? const <MentorAction>[];
    if (mentorActions.length != originalActions.length) return true;
    for (var i = 0; i < mentorActions.length; i++) {
      final action = mentorActions[i];
      final before = originalActions[i];
      if (action.id != before.id ||
          action.controller.text != before.text ||
          action.status != before.status) {
        return true;
      }
    }
    return false;
  }

  Future<void> closeEditor() async {
    if (savingEditor) return;
    if (hasChanges || voiceTarget != null) {
      final discard = await showDialog<Object>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          content: Text(drafts == null ? '离开后，本次编辑的内容不会保存。' : '可以保留本地草稿稍后继续；草稿不会自动成为正式记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('继续编辑'),
            ),
            if (drafts != null) TextButton(onPressed: () async {
              if (await flushDraft() && dialogContext.mounted) Navigator.pop(dialogContext, 'keep');
            }, child: const Text('保留草稿并关闭')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      );
      if (!mounted || discard == false || discard == null) return;
      if (discard == true && !await clearDraft()) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.kind == RecordKind.task;
    final mentor = widget.kind == RecordKind.mentor;
    final label = task
        ? '计划'
        : mentor
        ? '导师交流'
        : '科研进展';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) closeEditor();
      },
      child: AbsorbPointer(
        absorbing: savingEditor || !draftReady,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (draftError != null) Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(draftError!, style: const TextStyle(color: calendarRed)),
                      TextButton(onPressed: flushDraft, child: const Text('重试草稿保存')),
                      TextButton(onPressed: () async {
                        if (await clearDraft() && context.mounted) Navigator.pop(context);
                      }, child: const Text('放弃草稿')),
                    ]),
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xffc7c7cc),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.record == null ? '新建' : '编辑'}$label',
                            style: const TextStyle(
                              fontSize: 23,
                              color: ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭编辑',
                          onPressed: closeEditor,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: title,
                      readOnly: savingEditor || voiceTarget == title,
                      maxLength: 100,
                      decoration: InputDecoration(
                        labelText: mentor
                            ? '交流主题 *'
                            : task
                            ? '计划内容 *'
                            : '进展标题 *',
                        suffixIcon: voiceButton(title),
                        hintText: mentor
                            ? '例如：课题方向讨论'
                            : task
                            ? '例如：阅读两篇相关文献'
                            : '例如：完成实验方案初稿',
                      ),
                    ),
                    voiceControls(title),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detail,
                      readOnly: savingEditor || voiceTarget == detail,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: task
                            ? '备注'
                            : mentor
                            ? '导师反馈 / 交流内容'
                            : '完成的工作 / 收获',
                        hintText: task || mentor ? '选填' : '例如：梳理实验结果',
                        suffixIcon: voiceButton(detail),
                      ),
                    ),
                    voiceControls(detail),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => showMetadata = !showMetadata),
                      icon: Icon(
                        showMetadata ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(
                        showMetadata
                            ? '收起日期和分类'
                            : '补充日期和分类 · ${dateLabel(date)}',
                      ),
                    ),
                    if (showMetadata) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => date = picked);
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 17,
                        ),
                        label: Text(dateLabel(date)),
                      ),
                      const SizedBox(height: 12),
                      if (task) ...[
                        FrostedDropdown<String>(
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: '优先级'),
                          items: recordPriorities
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => priority = value ?? '中'),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (picked != null && mounted) {
                                  setState(
                                    () => plannedTime =
                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                                  );
                                }
                              },
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                plannedTime == null
                                    ? '设置时间（选填）'
                                    : '时间 $plannedTime',
                              ),
                            ),
                            if (plannedTime != null)
                              TextButton(
                                onPressed: () =>
                                    setState(() => plannedTime = null),
                                child: const Text('清除时间'),
                              ),
                          ],
                        ),
                      ] else if (!mentor) ...[
                        FrostedDropdown<String>(
                          initialValue: progressType,
                          decoration: const InputDecoration(labelText: '科研类型'),
                          items: researchTypes
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => progressType = value ?? '其他活动'),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (!task && !mentor) ...[
                      const Text(
                        '成果、问题或下一步至少填写一项。',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (mentor) ...[
                      const Text(
                        '交流对象和主题必填；建议、结论或后续事项至少填写一项。',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!task && !mentor)
                      TextButton.icon(
                        onPressed:
                            showProgressDetails &&
                                (voiceTarget == problem || voiceTarget == next)
                            ? null
                            : () => setState(
                                () =>
                                    showProgressDetails = !showProgressDetails,
                              ),
                        icon: Icon(
                          showProgressDetails
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          showProgressDetails ? '收起补充信息' : '填写问题、下一步和投入时间',
                        ),
                      ),
                    if (mentor || (!task && showProgressDetails)) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: problem,
                        readOnly: savingEditor || voiceTarget == problem,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: mentor ? '交流结论' : '遇到的问题',
                          hintText: '选填',
                          suffixIcon: voiceButton(problem),
                        ),
                      ),
                      voiceControls(problem),
                      const SizedBox(height: 14),
                      if (!mentor || hasLegacyNext) ...[
                        TextField(
                          controller: next,
                          readOnly: savingEditor || voiceTarget == next,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: mentor ? '旧版后续记录（状态未记录）' : '下一步计划',
                            hintText: '选填',
                            suffixIcon: voiceButton(next),
                          ),
                        ),
                        voiceControls(next),
                      ],
                    ],
                    if (mentor) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: mentorName,
                        readOnly: savingEditor || voiceTarget == mentorName,
                        decoration: InputDecoration(
                          labelText: '交流对象 *',
                          hintText: '例如：张老师',
                          suffixIcon: voiceButton(mentorName),
                        ),
                      ),
                      voiceControls(mentorName),
                      if (widget.previousDiscussions.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        FrostedDropdown<String>(
                          initialValue: previousDiscussionId ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '关联上次交流（选填）',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('不关联'),
                            ),
                            ...widget.previousDiscussions.map(
                              (previous) => DropdownMenuItem(
                                value: previous.id,
                                child: Text(
                                  '${dateLabel(previous.date)} · ${previous.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => previousDiscussionId = value == ''
                                ? null
                                : value,
                          ),
                        ),
                        if (previousDiscussionId != null)
                          ...widget.previousDiscussions
                              .where(
                                (previous) =>
                                    previous.id == previousDiscussionId,
                              )
                              .map(
                                (previous) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (previous.detail.isNotEmpty)
                                        Text('上次建议：${previous.detail}'),
                                      if (previous.problem.isNotEmpty)
                                        Text('上次结论：${previous.problem}'),
                                      for (final action
                                          in previous.mentorActions)
                                        Text(
                                          '上次事项：${action.text} · ${action.status.label}',
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: previousFollowUp,
                        readOnly:
                            savingEditor || voiceTarget == previousFollowUp,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: '上次要求落实情况',
                          hintText: '按实际情况填写',
                          suffixIcon: voiceButton(previousFollowUp),
                        ),
                      ),
                      voiceControls(previousFollowUp),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: nextMeetingDate ?? date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null && mounted) {
                                setState(() => nextMeetingDate = picked);
                              }
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              nextMeetingDate == null
                                  ? '设置下次交流日期（选填）'
                                  : '下次交流：${dateLabel(nextMeetingDate!)}',
                            ),
                          ),
                          if (nextMeetingDate != null)
                            TextButton(
                              onPressed: () =>
                                  setState(() => nextMeetingDate = null),
                              child: const Text('清除日期'),
                            ),
                        ],
                      ),
                      const Text(
                        '跟进事项',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final action in mentorActions)
                        Column(
                          children: [
                            Row(
                              children: [
                                MentorStatusPicker(
                                  value: action.status,
                                  onChanged: (value) =>
                                      setState(() => action.status = value),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey('mentorActionInput'),
                                    controller: action.controller,
                                    readOnly:
                                        savingEditor ||
                                        voiceTarget == action.controller,
                                    decoration: InputDecoration(
                                      labelText: '跟进内容',
                                      suffixIcon: voiceButton(
                                        action.controller,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '移除跟进事项',
                                  onPressed: () {
                                    if (voiceTarget == action.controller) {
                                      cancelVoice();
                                    }
                                    setState(
                                      () => mentorActions.remove(action),
                                    );
                                    retiredActionControllers.add(
                                      action.controller,
                                    );
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            voiceControls(action.controller),
                          ],
                        ),
                      TextButton.icon(
                        onPressed: () => setState(
                          () {
                            final action = MentorActionDraft(
                              id: '${DateTime.now().microsecondsSinceEpoch}-${actionCounter++}',
                              text: '',
                            );
                            action.controller.addListener(scheduleDraft);
                            mentorActions.add(action);
                          },
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('添加跟进事项'),
                      ),
                    ],
                    if (!task && !mentor && showProgressDetails) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: duration,
                        readOnly: savingEditor,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: '投入时间（分钟，选填）',
                        ),
                      ),
                    ],
                    if (lastFailedDraft != null)
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: [
                                '研历草稿（仅供参考，不是完整备份）',
                                '标题：${lastFailedDraft!.title}',
                                '日期：${dateLabel(lastFailedDraft!.date)}',
                                '内容：${lastFailedDraft!.detail}',
                                '问题或结论：${lastFailedDraft!.problem}',
                                '下一步或旧版跟进：${lastFailedDraft!.next}',
                                '交流对象：${lastFailedDraft!.mentorName}',
                                '上次落实：${lastFailedDraft!.previousFollowUp}',
                                ...lastFailedDraft!.mentorActions.map(
                                  (a) =>
                                      '跟进事项（${a.done ? '已完成' : '未完成'}）：${a.text}',
                                ),
                              ].join('\n'),
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('上次保存草稿已复制')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制上次保存草稿'),
                      ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: savingEditor
                            ? null
                            : () async {
                                if (voiceTarget != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请先完成或取消语音输入，再保存'),
                                    ),
                                  );
                                  return;
                                }
                                if (title.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请先填写标题或计划内容'),
                                    ),
                                  );
                                  return;
                                }
                                if (mentor && mentorName.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请填写交流对象')),
                                  );
                                  return;
                                }
                                if (mentor &&
                                    detail.text.trim().isEmpty &&
                                    problem.text.trim().isEmpty &&
                                    !(hasLegacyNext &&
                                        next.text.trim().isNotEmpty) &&
                                    mentorActions.every(
                                      (action) =>
                                          action.controller.text.trim().isEmpty,
                                    )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请至少填写建议、结论或一项后续事项'),
                                    ),
                                  );
                                  return;
                                }
                                if (!task &&
                                    !mentor &&
                                    detail.text.trim().isEmpty &&
                                    problem.text.trim().isEmpty &&
                                    next.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请至少填写成果、问题或下一步中的一项'),
                                    ),
                                  );
                                  return;
                                }
                                if (mentor && previousDiscussionId != null) {
                                  final previous = widget.previousDiscussions
                                      .where(
                                        (item) =>
                                            item.id == previousDiscussionId,
                                      );
                                  if (previous.isEmpty ||
                                      dayOnly(
                                        previous.first.date,
                                      ).isAfter(dayOnly(date))) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('关联的上次交流不能晚于本次交流'),
                                      ),
                                    );
                                    return;
                                  }
                                }
                                if (mentorActions.any(
                                  (action) =>
                                      action.controller.text.trim().isEmpty,
                                )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请填写跟进事项内容，或移除空事项'),
                                    ),
                                  );
                                  return;
                                }
                                final minutes = duration.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(duration.text.trim());
                                if (duration.text.trim().isNotEmpty &&
                                    minutes == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('请输入有效的非负分钟数'),
                                    ),
                                  );
                                  return;
                                }
                                final result = ResearchRecord(
                                  id: draftId,
                                  kind: widget.kind,
                                  date: dayOnly(date),
                                  title: title.text.trim(),
                                  createdAt: widget.record == null
                                      ? draftCreatedAt
                                      : widget.record!.createdAt,
                                  sourceDiscussionId:
                                      widget.record?.sourceDiscussionId,
                                  sourceMentorActionId:
                                      widget.record?.sourceMentorActionId,
                                  updatedAt: DateTime.now().toUtc(),
                                  detail: detail.text.trim(),
                                  problem: problem.text.trim(),
                                  next: next.text.trim(),
                                  done: widget.record?.done ?? false,
                                  completedAt: widget.record?.completedAt,
                                  priority: priority,
                                  plannedTime: plannedTime,
                                  progressType: progressType,
                                  durationMinutes: minutes,
                                  mentorName: mentorName.text.trim(),
                                  previousFollowUp: previousFollowUp.text
                                      .trim(),
                                  previousDiscussionId: previousDiscussionId,
                                  nextMeetingDate: nextMeetingDate,
                                  mentorActions: mentorActions
                                      .map(
                                        (action) => MentorAction(
                                          id: action.id,
                                          text: action.controller.text.trim(),
                                          status: action.status,
                                        ),
                                      )
                                      .toList(),
                                );
                                if (widget.onSave != null) {
                                  FocusScope.of(context).unfocus();
                                  setState(() => savingEditor = true);
                                  bool saved = false;
                                  try {
                                    saved = await widget.onSave!(result);
                                  } catch (_) {
                                    saved = false;
                                  } finally {
                                    if (mounted) {
                                      setState(() => savingEditor = false);
                                    }
                                  }
                                  if (!mounted || !context.mounted) return;
                                  if (!saved) {
                                    await flushDraft();
                                    setState(() => lastFailedDraft = result);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '保存未确认成功，内容仍在此页面，可重试或复制草稿',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }
                                if (!await clearDraft() || !context.mounted) return;
                                if (context.mounted) {
                                  Navigator.pop(context, result);
                                }
                              },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text('保存$label'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
