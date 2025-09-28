import 'package:flutter/material.dart';
import 'models.dart';
import 'widgets.dart';

class MonthView extends StatefulWidget {
	final int year;
	final int month;
	final List<CalendarEvent> events;
	final Function(DateTime start, DateTime end) onAddEvent;
	
	const MonthView({
		super.key,
		required this.year,
		required this.month,
		required this.events,
		required this.onAddEvent,
	});

	@override
	State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
	Set<DateTime> _selectedDates = {};
	Offset? _lastTapLocal;

	@override
	Widget build(BuildContext context) {
		return Column(
			children: [
				_buildWeekdayHeader(context),
				Expanded(child: _buildCalendarGrid(context)),
			],
		);
	}

	// 月视图顶部周标题
	Widget _buildWeekdayHeader(BuildContext context) {
		// 周一到周日
		const labels = ['一', '二', '三', '四', '五', '六', '日'];
		return Padding(
			padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
			child: Row(
				children: [
					for (final l in labels)
						Expanded(
							child: Center(
								child: Text('周$l', style: const TextStyle(fontWeight: FontWeight.w600)),
							),
						),
				],
			),
		);
	}

	// 月视图网格
	Widget _buildCalendarGrid(BuildContext context) {
		final firstOfMonth = DateTime(widget.year, widget.month, 1);
		final firstWeekdayMonFirst = ((firstOfMonth.weekday + 6) % 7); // 以周一为 0
		final startDate = firstOfMonth.subtract(Duration(days: firstWeekdayMonFirst));
		const columns = 7;
		final daysInMonth = DateTime(widget.year, widget.month + 1, 0).day; // 本月天数
		// 需要的周数：覆盖到"本月最后一天所在的整周"为止（最多只多出下一月一行）
		final weeksNeeded = ((firstWeekdayMonFirst + daysInMonth + columns - 1) ~/ columns);
		final totalCells = weeksNeeded * columns;

		DateTime indexToDate(int idx) => startDate.add(Duration(days: idx));
		int posToIndex(Offset pos, double gridWidth) {
			final double cellWidth = gridWidth / columns;
			final int col = (pos.dx.clamp(0, gridWidth - 1) / cellWidth).floor();
			final double cellHeight = cellWidth; // childAspectRatio = 1.0
			final int row = (pos.dy.clamp(0, cellHeight * weeksNeeded - 1) / cellHeight).floor();
			int idx = row * columns + col;
			if (idx < 0) idx = 0;
			if (idx >= totalCells) idx = totalCells - 1;
			return idx;
		}

		return LayoutBuilder(
			builder: (context, constraints) {
				final double gridWidth = constraints.maxWidth;
				return Stack(
					children: [
						GridView.builder(
							padding: EdgeInsets.zero,
							gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
								crossAxisCount: 7,
								childAspectRatio: 1.0,
								mainAxisSpacing: 0,
								crossAxisSpacing: 0,
							),
							itemCount: totalCells,
							itemBuilder: (context, index) {
								final date = indexToDate(index);
								final inCurrentMonth = date.month == widget.month;
								final bool isSelected = _selectedDates.any((d) => _isSameDate(d, date));
								final dayEvents = widget.events.where((e) => e.intersects(date)).toList(growable: false);
								return DayCell(
									index: index,
									totalCells: totalCells,
									columns: columns,
									date: date,
									inCurrentMonth: inCurrentMonth,
									isSelected: isSelected,
									events: dayEvents,
								);
							},
						),
						// 手势层：双击/拖动选择
						Positioned.fill(
							child: GestureDetector(
								behavior: HitTestBehavior.translucent,
								onTapDown: (d) => _lastTapLocal = d.localPosition,
								onDoubleTap: () async {
									if (_lastTapLocal == null) return;
									final idx = posToIndex(_lastTapLocal!, gridWidth);
									final date = indexToDate(idx);
									setState(() {
										_selectedDates = { _dateOnly(date) };
									});
									await widget.onAddEvent(_dateOnly(date), _dateOnly(date));
									setState(() { _selectedDates = {}; });
								},
								onPanStart: (d) {
									final idx = posToIndex(d.localPosition, gridWidth);
									final date = indexToDate(idx);
									setState(() {
										_selectedDates = { _dateOnly(date) };
									});
								},
								onPanUpdate: (d) {
									final idx = posToIndex(d.localPosition, gridWidth);
									final date = indexToDate(idx);
									if (_selectedDates.isEmpty) return;
									final start = _selectedDates.first;
									final range = _buildDateRange(_dateOnly(start), _dateOnly(date));
									setState(() { _selectedDates = range.toSet(); });
								},
								onPanEnd: (_) async {
									if (_selectedDates.length <= 1) return;
									final dates = _selectedDates.toList()..sort();
									await widget.onAddEvent(dates.first, dates.last);
									setState(() { _selectedDates = {}; });
								},
							),
						),
					],
				);
			},
		);
	}

	bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
	DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
	List<DateTime> _buildDateRange(DateTime a, DateTime b) {
		final start = a.isBefore(b) ? a : b;
		final end = a.isBefore(b) ? b : a;
		final days = end.difference(start).inDays;
		return List.generate(days + 1, (i) => DateTime(start.year, start.month, start.day + i));
	}
}
