import 'package:flutter/material.dart';

import 'domain.dart';
import 'frosted_dropdown.dart';

const _monthNames = [
  '一月',
  '二月',
  '三月',
  '四月',
  '五月',
  '六月',
  '七月',
  '八月',
  '九月',
  '十月',
  '十一月',
  '十二月',
];
const _red = Color(0xffd93025);
const _muted = Color(0xff6c6c70);
const _calendarMarkers = [
  (RecordKind.task, Icons.check_circle_outline, _red, '计划记录', '有计划'),
  (
    RecordKind.progress,
    Icons.auto_stories_outlined,
    Color(0xff007aff),
    '科研进展',
    '有进展',
  ),
  (RecordKind.mentor, Icons.forum_outlined, Color(0xffaf52de), '导师交流', '有导师交流'),
];

String calendarRecordKindSemantics(Set<RecordKind> kinds) => [
  for (final entry in _calendarMarkers)
    if (kinds.contains(entry.$1)) '，${entry.$5}',
].join();

class CalendarMarkerLegend extends StatefulWidget {
  const CalendarMarkerLegend({
    super.key,
    this.keyPrefix = 'calendar',
    this.compact = false,
    this.onLayout,
  });

  final String keyPrefix;
  final bool compact;

  /// Called after the first layout and after viewport or text-scale changes.
  final ValueChanged<BuildContext>? onLayout;

  @override
  State<CalendarMarkerLegend> createState() => _CalendarMarkerLegendState();
}

class _CalendarMarkerLegendState extends State<CalendarMarkerLegend> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onLayout == null) return;
    MediaQuery.sizeOf(context);
    MediaQuery.textScalerOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLayout?.call(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? Row(
          key: ValueKey('${widget.keyPrefix}-marker-legend'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in _calendarMarkers)
              Expanded(
                child: Column(
                  key: ValueKey('${widget.keyPrefix}-legend-${entry.$1.name}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entry.$2, color: entry.$3, size: 16),
                    Text(
                      entry.$4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        )
      : LayoutBuilder(
          builder: (context, constraints) => Wrap(
            key: ValueKey('${widget.keyPrefix}-marker-legend'),
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final entry in _calendarMarkers)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: Row(
                    key: ValueKey(
                      '${widget.keyPrefix}-legend-${entry.$1.name}',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        entry.$2,
                        color: entry.$3,
                        size: MediaQuery.textScalerOf(
                          context,
                        ).scale(14).clamp(0.0, constraints.maxWidth / 2),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          entry.$4,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
}

class CalendarRecordMarkers extends StatelessWidget {
  const CalendarRecordMarkers({
    super.key,
    required this.date,
    required this.kinds,
    this.keyPrefix = 'calendar-dot',
  });

  final DateTime date;
  final Set<RecordKind> kinds;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 12,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _calendarMarkers)
            if (kinds.contains(entry.$1))
              Icon(
                entry.$2,
                key: ValueKey(
                  '$keyPrefix-${date.year}-${date.month}-${date.day}-${entry.$1.name}',
                ),
                color: entry.$3,
                size: 12,
              ),
        ],
      ),
    ),
  );
}

/// A bounded viewport over lazily built months, with a stationary toolbar.
class ScrollingCalendar extends StatefulWidget {
  const ScrollingCalendar({
    super.key,
    required this.selectedDate,
    required this.records,
    required this.onDateSelected,
    required this.buttonStyle,
    this.navigationRevision = 0,
    this.expand = false,
    this.headerActions,
    this.recordCounts = const {},
  });

  final DateTime selectedDate;
  final Map<DateTime, Set<RecordKind>> records;
  final Map<DateTime, int> recordCounts;
  final ValueChanged<DateTime> onDateSelected;
  final ButtonStyle buttonStyle;
  final int navigationRevision;
  final bool expand;
  final Widget? headerActions;

  @override
  State<ScrollingCalendar> createState() => _ScrollingCalendarState();
}

class _ScrollingCalendarState extends State<ScrollingCalendar> {
  late final int _firstYear = widget.selectedDate.year < 1900
      ? widget.selectedDate.year
      : 1900;
  late final int _lastYear = widget.selectedDate.year > 2200
      ? widget.selectedDate.year
      : 2200;
  late DateTime _visibleMonth = DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
  );
  ScrollController? _controller;
  List<double> _offsets = [];
  double _rowHeight = 0;
  double _titleHeight = 0;
  int _metricsRevision = 0;
  DateTime? _localSelection;

  int get _monthCount => (_lastYear - _firstYear + 1) * 12;
  int _index(DateTime date) => ((date.year - _firstYear) * 12 + date.month - 1)
      .clamp(0, _monthCount - 1);
  DateTime _monthAt(int index) => DateTime(_firstYear, index + 1);
  int _rows(DateTime month) =>
      ((month.weekday -
          1 +
          DateUtils.getDaysInMonth(month.year, month.month) +
          6) ~/
      7);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMetrics();
  }

  bool _updateMetrics({
    bool preservePosition = false,
    bool scheduleJump = true,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final rowHeight =
        26 +
        scaler.scale(22) +
        (widget.recordCounts.isEmpty ? 0 : scaler.scale(12));
    final titleHeight = 18 + scaler.scale(18);
    if (_rowHeight == rowHeight && _titleHeight == titleHeight) return false;
    final controller = _controller;
    final month = _visibleMonth;
    final previousOffset = controller != null && controller.hasClients
        ? controller.offset
        : null;
    var withinMonth = preservePosition && previousOffset != null
        ? previousOffset - _offsets[_index(month)]
        : 0.0;
    // Keep the same visible week when record counts change the row height.
    if (withinMonth > _titleHeight && _rowHeight > 0) {
      final rowsOffset = (withinMonth - _titleHeight).clamp(
        0.0,
        _rows(month) * _rowHeight,
      );
      withinMonth =
          titleHeight +
          rowsOffset * rowHeight / _rowHeight +
          (withinMonth - _titleHeight - rowsOffset);
    }
    final revision = ++_metricsRevision;
    _rowHeight = rowHeight;
    _titleHeight = titleHeight;
    _offsets = [0];
    for (var i = 0; i < _monthCount; i++) {
      _offsets.add(
        _offsets.last + _titleHeight + _rows(_monthAt(i)) * _rowHeight + 12,
      );
    }
    if (controller == null) {
      _controller = ScrollController(
        initialScrollOffset: _offsets[_index(_visibleMonth)],
      )..addListener(_onScroll);
    } else if (scheduleJump) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _metricsRevision) return;
        if (preservePosition && previousOffset != null) {
          if (!controller.hasClients ||
              _visibleMonth != month ||
              controller.offset != previousOffset) {
            return;
          }
          controller.jumpTo(
            (_offsets[_index(month)] + withinMonth).clamp(
              0.0,
              controller.position.maxScrollExtent,
            ),
          );
        } else {
          _jumpToMonth(_visibleMonth);
        }
      });
    }
    return true;
  }

  @override
  void didUpdateWidget(covariant ScrollingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = !DateUtils.isSameDay(
      oldWidget.selectedDate,
      widget.selectedDate,
    );
    final local = DateUtils.isSameDay(_localSelection, widget.selectedDate);
    _localSelection = null;
    final navigate =
        (changed ||
            oldWidget.navigationRevision != widget.navigationRevision) &&
        !local;
    final metricsChanged = _updateMetrics(
      preservePosition: true,
      scheduleJump: !navigate,
    );
    if (navigate) {
      final target = widget.selectedDate;
      _jumpToMonth(target);
      if (metricsChanged) {
        // The new scroll extent is available only after layout.
        final revision = _metricsRevision;
        final navigationRevision = widget.navigationRevision;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              revision == _metricsRevision &&
              navigationRevision == widget.navigationRevision &&
              DateUtils.isSameDay(target, widget.selectedDate)) {
            _jumpToMonth(target);
          }
        });
      }
    }
  }

  void _onScroll() {
    final offset = _controller!.offset;
    // Binary search the known month extents; no offscreen widgets are measured.
    var low = 0;
    var high = _monthCount;
    while (low + 1 < high) {
      final mid = (low + high) ~/ 2;
      if (_offsets[mid] <= offset + .5) {
        low = mid;
      } else {
        high = mid;
      }
    }
    final month = _monthAt(low);
    if (month != _visibleMonth) setState(() => _visibleMonth = month);
  }

  void _jumpToMonth(DateTime date) {
    final index = _index(date);
    setState(() => _visibleMonth = _monthAt(index));
    if (_controller!.hasClients) {
      _controller!.jumpTo(
        _offsets[index].clamp(0.0, _controller!.position.maxScrollExtent),
      );
    }
  }

  void _selectDay(DateTime date) {
    _localSelection = date;
    widget.onDateSelected(date);
  }

  Future<void> _chooseMonth() async {
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FrostedMenuSurface(
        child: _MonthPicker(
          initialMonth: _visibleMonth,
          firstYear: _firstYear,
          lastYear: _lastYear,
          buttonStyle: widget.buttonStyle,
        ),
      ),
    );
    if (result != null && mounted) {
      _jumpToMonth(result);
      _selectDay(result);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SizedBox(
      height: widget.expand ? double.infinity : 430,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              height: 76,
              child: Row(
                children: [
                  TextButton(
                    key: const ValueKey('calendar-year'),
                    style: widget.buttonStyle,
                    onPressed: _chooseMonth,
                    child: Text('${_visibleMonth.year}年'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _monthNames[_visibleMonth.month - 1],
                        key: const ValueKey('calendar-month'),
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  widget.headerActions ??
                      TextButton(
                        style: widget.buttonStyle,
                        onPressed: () {
                          final today = dayOnly(DateTime.now());
                          _jumpToMonth(today);
                          _selectDay(today);
                        },
                        child: const Text('今天'),
                      ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: CalendarMarkerLegend(),
            ),
            SizedBox(
              height: 30,
              child: Row(
                children: [
                  for (final day in ['一', '二', '三', '四', '五', '六', '日'])
                    Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('calendar-month-list'),
                controller: _controller,
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: _monthCount,
                itemExtentBuilder: (index, _) =>
                    _offsets[index + 1] - _offsets[index],
                itemBuilder: (context, index) => _buildMonth(_monthAt(index)),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildMonth(DateTime month) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = month.weekday - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _titleHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              month == _visibleMonth ? '' : '${month.month}月',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        for (var row = 0; row < _rows(month); row++)
          Container(
            height: _rowHeight,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xffe5e5ea), width: .5),
              ),
            ),
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child:
                        row * 7 + column < leading ||
                            row * 7 + column >= leading + days
                        ? const SizedBox()
                        : _buildDay(
                            DateTime(
                              month.year,
                              month.month,
                              row * 7 + column - leading + 1,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDay(DateTime date) {
    final active = DateUtils.isSameDay(date, widget.selectedDate);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final kinds = widget.records[date] ?? <RecordKind>{};
    final count = widget.recordCounts[date];
    return Semantics(
      button: true,
      selected: active,
      onTap: () => _selectDay(date),
      label:
          '${date.year}年${date.month}月${date.day}日'
          '${today ? '，今天' : ''}'
          '${count == null ? '' : '，共$count条记录'}'
          '${calendarRecordKindSemantics(kinds)}',
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
          borderRadius: BorderRadius.circular(24),
          onTap: () => _selectDay(date),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active ? _red : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 20,
                        color: active
                            ? Colors.white
                            : today
                            ? _red
                            : date.weekday >= 6
                            ? _muted
                            : const Color(0xff1c1c1e),
                        fontWeight: active || today
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              CalendarRecordMarkers(date: date, kinds: kinds),
              if (count != null && count > 0)
                Text(
                  '$count条',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthPicker extends StatefulWidget {
  const _MonthPicker({
    required this.initialMonth,
    required this.firstYear,
    required this.lastYear,
    required this.buttonStyle,
  });
  final DateTime initialMonth;
  final int firstYear;
  final int lastYear;
  final ButtonStyle buttonStyle;

  @override
  State<_MonthPicker> createState() => _MonthPickerState();
}

class _MonthPickerState extends State<_MonthPicker> {
  late int _year = widget.initialMonth.year;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          const Text(
            '选择年月',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: YearPicker(
              firstDate: DateTime(widget.firstYear),
              lastDate: DateTime(widget.lastYear, 12, 31),
              selectedDate: DateTime(_year, widget.initialMonth.month),
              onChanged: (date) => setState(() => _year = date.year),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio:
                    (constraints.maxWidth - 24) /
                    4 /
                    (20 + MediaQuery.textScalerOf(context).scale(18)),
                children: [
                  for (var month = 1; month <= 12; month++)
                    TextButton(
                      key: ValueKey('calendar-pick-month-$month'),
                      style: widget.buttonStyle,
                      onPressed: () =>
                          Navigator.pop(context, DateTime(_year, month)),
                      child: Text(_monthNames[month - 1]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
