import 'package:flutter/material.dart';

/// Simple, compact, IONYK-styled calendar popups. These are UI-only filters.
/// `null` means the dialog was dismissed without applying a change.
class IonykDateFilter {
  static const _ink = Color(0xFF151A1A);
  static const _muted = Color(0xFF687272);
  static const _line = Color(0xFFE4E8E4);
  static const _lime = Color(0xFFD9FF57);

  static String label(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static Future<({bool clear, DateTime? date})?> single(
    BuildContext context, {
    DateTime? selected,
    DateTime? initial,
    DateTime? first,
    DateTime? last,
  }) {
    var draft = selected ?? initial ?? DateTime.now();
    final earliest = first ?? DateTime(2020);
    final latest = last ?? DateTime(2035);
    if (draft.isBefore(earliest)) draft = earliest;
    if (draft.isAfter(latest)) draft = latest;
    return showDialog<({bool clear, DateTime? date})>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => _dialog(
        title: 'Filter by date',
        subtitle: 'Choose a day to display.',
        content: CalendarDatePicker(
          initialDate: draft,
          firstDate: earliest,
          lastDate: latest,
          onDateChanged: (v) => update(() => draft = v),
        ),
        onClear: () => Navigator.of(ctx).pop((clear: true, date: null)),
        onCancel: () => Navigator.of(ctx).pop(),
        onApply: () => Navigator.of(ctx).pop((clear: false, date: draft)),
      )),
    );
  }

  static Future<({bool clear, DateTimeRange? range})?> range(
    BuildContext context, {
    DateTimeRange? selected,
    DateTime? first,
    DateTime? last,
  }) {
    final earliest = DateUtils.dateOnly(first ?? DateTime(2020));
    final latest = DateUtils.dateOnly(last ?? DateTime(2035));
    DateTime? start = selected == null ? null : DateUtils.dateOnly(selected.start);
    DateTime? end = selected == null ? null : DateUtils.dateOnly(selected.end);
    var visibleMonth = DateTime((start ?? DateTime.now()).year, (start ?? DateTime.now()).month);

    return showDialog<({bool clear, DateTimeRange? range})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => _dialog(
          title: 'Filter past reports',
          subtitle: 'Select the first and last day of your range.',
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(8, 10, 8, 7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.date_range_outlined, size: 16, color: _muted),
                const SizedBox(width: 9),
                Expanded(child: Text(
                  start == null
                      ? 'Select a start date'
                      : end == null
                          ? '${label(start!)}  →  Select an end date'
                          : '${label(start!)}  –  ${label(end!)}',
                  style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600),
                )),
              ]),
            ),
            _IonykRangeCalendar(
              visibleMonth: visibleMonth,
              start: start,
              end: end,
              earliest: earliest,
              latest: latest,
              onMonthChanged: (month) => update(() => visibleMonth = month),
              onDatePicked: (day) => update(() {
                // Once a complete range exists, a new tap starts a new range.
                if (start == null || end != null) {
                  start = day;
                  end = null;
                } else if (day.isBefore(start!)) {
                  end = start;
                  start = day;
                } else {
                  end = day;
                }
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 7),
              child: TextButton(
                onPressed: () => update(() { start = null; end = null; }),
                child: const Text('Choose dates again',
                    style: TextStyle(color: _muted, fontSize: 11)),
              ),
            ),
          ]),
          onClear: () => Navigator.of(ctx).pop((clear: true, range: null)),
          onCancel: () => Navigator.of(ctx).pop(),
          onApply: start == null || end == null
              ? null
              : () => Navigator.of(ctx).pop((
                  clear: false,
                  range: DateTimeRange(start: start!, end: end!),
                )),
        ),
      ),
    );
  }

  static Widget _dialog({
    required String title,
    required String subtitle,
    required Widget content,
    required VoidCallback onClear,
    required VoidCallback onCancel,
    required VoidCallback? onApply,
  }) => Dialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 19, 16, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 5),
          Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: _ink, onPrimary: _lime, surface: Colors.white),
              datePickerTheme: DatePickerThemeData(
                todayBorder: const BorderSide(color: _ink),
                dayShape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            child: content,
          ),
          const Divider(color: _line),
          Row(children: [
            TextButton(onPressed: onClear, child: const Text('All dates', style: TextStyle(color: _muted))),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('Cancel', style: TextStyle(color: _ink))),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: onApply,
              style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: _lime),
              child: const Text('Apply'),
            ),
          ]),
        ]),
      ),
    ),
  );
}

/// Inclusive date-range calendar with a continuous, muted lime selection.
/// Only used by Past Z-Readings; the Transactions single-day filter is unchanged.
class _IonykRangeCalendar extends StatelessWidget {
  const _IonykRangeCalendar({
    required this.visibleMonth,
    required this.start,
    required this.end,
    required this.earliest,
    required this.latest,
    required this.onMonthChanged,
    required this.onDatePicked,
  });

  final DateTime visibleMonth;
  final DateTime? start;
  final DateTime? end;
  final DateTime earliest;
  final DateTime latest;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDatePicked;

  static const _ink = Color(0xFF151A1A);
  static const _muted = Color(0xFF687272);
  static const _lime = Color(0xFFD9FF57);
  static const _rangeFill = Color(0xFFEDF7D5);
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  bool _sameDay(DateTime a, DateTime b) => DateUtils.isSameDay(a, b);

  @override
  Widget build(BuildContext context) {
    final month = DateTime(visibleMonth.year, visibleMonth.month);
    final firstWeekOffset = month.weekday - 1; // Monday is first column.
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = ((firstWeekOffset + count + 6) ~/ 7) * 7;
    final prevMonth = DateTime(month.year, month.month - 1);
    final nextMonth = DateTime(month.year, month.month + 1);
    final canPrev = !DateTime(prevMonth.year, prevMonth.month + 1, 0).isBefore(earliest);
    final canNext = !nextMonth.isAfter(latest);
    final now = DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const SizedBox(width: 8),
          Expanded(child: Text(
            '${_months[month.month - 1]} ${month.year}',
            style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w700),
          )),
          IconButton(
            tooltip: 'Previous month',
            onPressed: canPrev ? () => onMonthChanged(prevMonth) : null,
            icon: const Icon(Icons.chevron_left, size: 19),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: canNext ? () => onMonthChanged(nextMonth) : null,
            icon: const Icon(Icons.chevron_right, size: 19),
          ),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
            Expanded(child: Center(child: Text(day,
              style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
            ))),
        ]),
        const SizedBox(height: 7),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            childAspectRatio: 1.12,
          ),
          itemBuilder: (context, index) {
            final dayNumber = index - firstWeekOffset + 1;
            if (dayNumber < 1 || dayNumber > count) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNumber);
            final allowed = !day.isBefore(earliest) && !day.isAfter(latest);
            final isStart = start != null && _sameDay(day, start!);
            final isEnd = end != null && _sameDay(day, end!);
            final endpoint = isStart || isEnd;
            final inside = start != null && end != null &&
                day.isAfter(start!) && day.isBefore(end!);
            final isToday = _sameDay(day, now);

            return Semantics(
              label: '${IonykDateFilter.label(day)}${isStart ? ', start date' : ''}${isEnd ? ', end date' : ''}${inside ? ', in selected range' : ''}',
              selected: endpoint || inside,
              child: Material(
                color: inside ? _rangeFill : Colors.transparent,
                borderRadius: inside ? BorderRadius.circular(0) : BorderRadius.circular(9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: allowed ? () => onDatePicked(day) : null,
                  child: Center(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    width: 35,
                    height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: endpoint ? _ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: isToday && !endpoint
                          ? Border.all(color: const Color(0xFF8C9B85)) : null,
                    ),
                    child: Text('$dayNumber', style: TextStyle(
                      fontSize: 12,
                      fontWeight: endpoint ? FontWeight.w700 : FontWeight.w500,
                      color: !allowed ? const Color(0xFFB7BFBA)
                          : endpoint ? _lime : _ink,
                    )),
                  )),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          const Text('Start / End', style: TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(width: 14),
          Container(width: 12, height: 9, decoration: BoxDecoration(color: _rangeFill, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          const Text('Included dates', style: TextStyle(fontSize: 10, color: _muted)),
        ]),
      ]),
    );
  }
}
