import 'dart:ui' show CheckedState, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yanli_app/domain.dart';
import 'package:yanli_app/main.dart';

void main() {
  testWidgets('状态菜单使用圆角磨砂玻璃并标记当前状态', (tester) async {
    var status = MentorActionStatus.inProgress;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => MentorStatusPicker(
                value: status,
                onChanged: (value) => setState(() => status = value),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('mentor-status-menu'));
    final clip = tester.widget<ClipRRect>(menu);
    expect(clip.borderRadius, BorderRadius.circular(22));
    final filter = tester.widget<BackdropFilter>(
      find.descendant(of: menu, matching: find.byType(BackdropFilter)),
    );
    expect(filter.filter, ImageFilter.blur(sigmaX: 12, sigmaY: 12));
    expect(find.byType(PopupMenuItem<MentorActionStatus>), findsNWidgets(3));
    final selected = find.byKey(const ValueKey('mentor-status-inProgress'));
    expect(
      find.descendant(of: selected, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: selected, matching: find.bySemanticsLabel('处理中')),
      findsWidgets,
    );
    final semantics = tester.ensureSemantics();
    final selectedData = tester.getSemantics(selected).getSemanticsData();
    expect(selectedData.flagsCollection.isChecked, CheckedState.isTrue);
    final pendingData = tester
        .getSemantics(find.byKey(const ValueKey('mentor-status-pending')))
        .getSemanticsData();
    expect(pendingData.flagsCollection.isChecked, CheckedState.isFalse);
    semantics.dispose();

    await tester.tap(find.byKey(const ValueKey('mentor-status-completed')));
    await tester.pumpAndSettle();
    expect(status, MentorActionStatus.completed);
    expect(find.text('已完成'), findsOneWidget);
    expect(menu, findsNothing);
  });

  testWidgets('点击菜单外或按返回不会改变状态，禁用时不能打开', (tester) async {
    var status = MentorActionStatus.pending;
    var enabled = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: MentorStatusPicker(
                  value: status,
                  onChanged: enabled
                      ? (value) => setState(() => status = value)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );

    final picker = find.byType(MentorStatusPicker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(status, MentorActionStatus.pending);
    expect(find.byKey(const ValueKey('mentor-status-menu')), findsNothing);

    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(status, MentorActionStatus.pending);
    expect(find.byKey(const ValueKey('mentor-status-menu')), findsNothing);

    update(() => enabled = false);
    await tester.pump();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mentor-status-menu')), findsNothing);
    expect(status, MentorActionStatus.pending);
  });

  testWidgets('可用键盘切换菜单选项', (tester) async {
    var status = MentorActionStatus.pending;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => MentorStatusPicker(
                value: status,
                onChanged: (value) => setState(() => status = value),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'mentor-status-pending',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'mentor-status-inProgress',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(status, MentorActionStatus.inProgress);
    expect(find.byKey(const ValueKey('mentor-status-menu')), findsNothing);

    await tester.tap(find.byType(MentorStatusPicker));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'mentor-status-inProgress',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'mentor-status-pending',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(status, MentorActionStatus.pending);
    expect(find.byKey(const ValueKey('mentor-status-menu')), findsNothing);
  });

  testWidgets('窄屏大字体下可在编辑器中更改并保存跟进状态', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ResearchRecord? saved;
    final original = ResearchRecord(
      id: 'mentor',
      kind: RecordKind.mentor,
      date: DateTime(2026),
      title: '课题讨论',
      mentorName: '张老师',
      mentorActions: [MentorAction(id: 'a', text: '整理文献')],
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: RecordEditor(
            kind: RecordKind.mentor,
            initialDate: original.date,
            record: original,
            onSave: (record) async {
              saved = record;
              return true;
            },
          ),
        ),
      ),
    );

    final picker = find.byType(MentorStatusPicker);
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('mentorActionInput'))).width,
      greaterThan(50),
    );
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('mentor-status-inProgress')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('保存导师交流'));
    await tester.tap(find.text('保存导师交流'));
    await tester.pumpAndSettle();
    expect(saved?.mentorActions.single.status, MentorActionStatus.inProgress);
  });
}
