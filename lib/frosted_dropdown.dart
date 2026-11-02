import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clip before filtering so only the menu's rounded surface blurs its backdrop.
class FrostedMenuSurface extends StatelessWidget {
  const FrostedMenuSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: .38),
              const Color(0xfff2f2f7).withValues(alpha: .28),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
        ),
        child: child,
      ),
    ),
  );
}

/// Keeps Flutter's popup route (barrier, Escape, positioning and scrolling).
class FrostedPopupMenu<T> extends StatelessWidget {
  const FrostedPopupMenu({
    super.key,
    required this.items,
    this.value,
    this.onSelected,
    this.child,
    this.icon,
    this.tooltip,
  });

  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T>? onSelected;
  final Widget? child;
  final Widget? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PopupMenuButton<T>(
      enabled: onSelected != null,
      tooltip: tooltip,
      icon: icon,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      constraints: BoxConstraints(
        minWidth: constraints.hasBoundedWidth
            ? constraints.maxWidth.clamp(184.0, 360.0)
            : 184,
        maxWidth: 360,
      ),
      menuPadding: EdgeInsets.zero,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      onSelected: onSelected,
      itemBuilder: (_) => [_FrostedMenuEntry(items: items, value: value)],
      child: child,
    ),
  );
}

class FrostedDropdown<T> extends StatelessWidget {
  const FrostedDropdown({
    super.key,
    required this.initialValue,
    required this.items,
    required this.decoration,
    required this.onChanged,
    this.isExpanded = true,
  });

  final T initialValue;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final selected = items.where((item) => item.value == initialValue);
    return FrostedPopupMenu<T>(
      value: initialValue,
      items: items,
      onSelected: onChanged,
      tooltip: decoration.labelText,
      child: InputDecorator(
        decoration: decoration.copyWith(enabled: onChanged != null),
        child: Row(
          children: [
            Expanded(
              child: selected.isEmpty ? const SizedBox() : selected.first.child,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: onChanged == null ? Theme.of(context).disabledColor : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _FrostedMenuEntry<T> extends PopupMenuEntry<T> {
  const _FrostedMenuEntry({required this.items, this.value});
  final List<DropdownMenuItem<T>> items;
  final T? value;

  @override
  double get height => items.length * 48 + 16;
  @override
  bool represents(T? value) => false;
  @override
  State<_FrostedMenuEntry<T>> createState() => _FrostedMenuEntryState<T>();
}

class _FrostedMenuEntryState<T> extends State<_FrostedMenuEntry<T>> {
  late final nodes = [for (final _ in widget.items) FocusNode()];

  void focusOption(int index) {
    nodes[index].requestFocus();
    final target = nodes[index].context;
    if (target != null) Scrollable.ensureVisible(target, alignment: .5);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      var index = widget.items.indexWhere(
        (item) => item.value == widget.value && item.enabled,
      );
      if (index < 0) index = widget.items.indexWhere((item) => item.enabled);
      if (index >= 0) focusOption(index);
    });
  }

  @override
  void dispose() {
    for (final node in nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostedMenuSurface(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < widget.items.length; i++)
            Focus(
              focusNode: nodes[i],
              canRequestFocus: widget.items[i].enabled,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                final key = event.logicalKey;
                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.space ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  Navigator.pop(context, widget.items[i].value);
                  return KeyEventResult.handled;
                }
                final direction = key == LogicalKeyboardKey.arrowDown
                    ? 1
                    : key == LogicalKeyboardKey.arrowUp
                    ? -1
                    : 0;
                if (direction == 0) return KeyEventResult.ignored;
                for (var step = 1; step <= nodes.length; step++) {
                  final next = (i + step * direction) % nodes.length;
                  if (widget.items[next].enabled) {
                    focusOption(next);
                    break;
                  }
                }
                return KeyEventResult.handled;
              },
              child: PopupMenuItem<T>(
                value: widget.items[i].value,
                enabled: widget.items[i].enabled,
                padding: EdgeInsets.zero,
                child: Semantics(
                  selected: widget.items[i].value == widget.value,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: widget.items[i].value == widget.value
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: widget.items[i].child),
                        if (widget.items[i].value == widget.value) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
