import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'models.dart';
import 'widgets.dart';

class TodoPillItem {
	final String id;
	final String title;
	const TodoPillItem({required this.id, required this.title});
}

class SingleAllDayRow extends StatelessWidget {
	final List<DateTime> days;
	final List<CalendarEvent> events;
	final double gutterWidth; // 与小时刻度对齐的左侧留白/标签宽度
	final double minHeight; // 最小高度：无/少量活动时的行高下限
	final double maxHeight; // 最大高度：超出后内部滚动
	final bool isExpanded;
	final VoidCallback? onToggleExpanded;
	final Future<void> Function(CalendarEvent event, Offset globalPosition)? onSecondaryTapEvent;
	const SingleAllDayRow({
		super.key,
		required this.days,
		required this.events,
		required this.gutterWidth,
		this.minHeight = 145.0,
		this.maxHeight = 150.0,
		this.isExpanded = true,
		this.onToggleExpanded,
		this.onSecondaryTapEvent,
	});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		final List<List<CalendarEvent>> perDay = [
			for (final d in days) events.where((e) => e.intersects(d)).toList(),
		];
		if (!isExpanded) {
			return SizedBox(
				height: 32,
				child: Row(
					children: [
						SizedBox(
							width: gutterWidth,
							child: Align(
								alignment: Alignment.centerRight,
								child: Padding(
									padding: const EdgeInsets.only(right: 8),
									child: InkWell(
										onTap: onToggleExpanded,
										child: Padding(
											padding: const EdgeInsets.symmetric(vertical: 6),
											child: Text(
												'今日任务 ▼',
												style: theme.textTheme.bodySmall,
											),
										),
									),
								),
							),
						),
						Expanded(
							child: Row(
								children: [
									for (int i = 0; i < days.length; i++)
										Expanded(
											child: Container(
												decoration: BoxDecoration(
													border: Border(
														left: BorderSide(color: Colors.grey.withOpacity(0.5)),
														right: i == days.length - 1
															? BorderSide(color: Colors.grey.withOpacity(0.5))
															: BorderSide.none,
													),
												),
												alignment: Alignment.center,
												child: Text(
													perDay[i].isEmpty ? '' : '${perDay[i].length}个任务',
													style: theme.textTheme.bodySmall,
												),
											),
										),
								],
							),
						),
					],
				),
			);
		}
		final double fontSize = theme.textTheme.bodySmall?.fontSize ?? 12.0;
		final double pillHeight = fontSize + 16.0; // 单条高度
		const double vGap = 0;
		const int maxVisibleItems = 5; // 超过5个活动条时固定高度开始滚动
		// perDay 已在上方计算
		final int maxCount = perDay.fold<int>(0, (m, l) => math.max(m, l.length));
		
		// 根据活动数量计算高度：最多显示5个活动条，超过则固定高度开始滚动
		final double listHeight = maxCount == 0 ? 0 : maxCount * pillHeight + (maxCount - 1) * vGap + 14;
		final double maxAllowedHeight = maxVisibleItems * pillHeight + (maxVisibleItems - 1) * vGap + 14;
		final double targetHeight = maxCount <= maxVisibleItems 
			? listHeight.clamp(minHeight, maxHeight)
			: maxAllowedHeight.clamp(minHeight, maxHeight);
		final bool canScroll = maxCount > maxVisibleItems;

		return ConstrainedBox(
			constraints: BoxConstraints.tightFor(height: targetHeight),
			child: Row(
				children: [
					SizedBox(
						width: gutterWidth,
						child: Align(
							alignment: Alignment.centerRight,
							child: Padding(
								padding: const EdgeInsets.only(right: 8),
								child: InkWell(
									onTap: onToggleExpanded,
									child: Padding(
										padding: const EdgeInsets.symmetric(vertical: 6),
										child: Text(
											isExpanded ? '今日任务 ▲' : '今日任务 ▼',
											style: theme.textTheme.bodySmall,
										),
									),
								),
							),
						),
					),
					Expanded(
						child: ScrollConfiguration(
							behavior: const ScrollBehavior(),
							child: SingleChildScrollView(
								primary: false,
								physics: canScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
								scrollDirection: Axis.vertical,
								child: SizedBox(
									height: canScroll ? listHeight : targetHeight,
									child: Row(
										children: [
											for (int i = 0; i < days.length; i++)
												Expanded(
													child: Container(
														decoration: BoxDecoration(
															border: Border(
																left: BorderSide(color: Colors.grey.withOpacity(0.5)),
																right: i == days.length - 1 ? BorderSide(color: Colors.grey.withOpacity(0.5)) : BorderSide.none,
															),
														),
														padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																for (int j = 0; j < perDay[i].length; j++) ...[
																	SizedBox(
																		height: pillHeight,
																		child: GestureDetector(
																			behavior: HitTestBehavior.opaque,
																			onSecondaryTapDown: onSecondaryTapEvent == null
																				? null
																				: (d) => onSecondaryTapEvent!(perDay[i][j], d.globalPosition),
																			child: EventPill(title: perDay[i][j].title, color: perDay[i][j].color),
																		),
																	),
																	if (j != perDay[i].length - 1) SizedBox(height: vGap),
																],
															],
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
	}
}

class SingleTodoRow extends StatelessWidget {
	final List<DateTime> days;
	final List<List<TodoPillItem>> todos;
	final double gutterWidth;
	final double minHeight;
	final double maxHeight;
	final bool isExpanded;
	final VoidCallback? onToggleExpanded;
	final Future<void> Function(DateTime date, TodoPillItem item, Offset globalPosition)? onSecondaryTapTodo;
	const SingleTodoRow({
		super.key,
		required this.days,
		required this.todos,
		required this.gutterWidth,
		this.minHeight = 64.0,
		this.maxHeight = 150.0,
		this.isExpanded = true,
		this.onToggleExpanded,
		this.onSecondaryTapTodo,
	});

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);
		if (!isExpanded) {
			final List<int> perDayCounts = [
				for (int i = 0; i < days.length; i++) todos[i].length,
			];
			return SizedBox(
				height: 32,
				child: Row(
					children: [
						SizedBox(
							width: gutterWidth,
							child: Align(
								alignment: Alignment.centerRight,
								child: Padding(
									padding: const EdgeInsets.only(right: 8),
									child: InkWell(
										onTap: onToggleExpanded,
										child: Padding(
											padding: const EdgeInsets.symmetric(vertical: 6),
											child: Text(
												'今日待办 ▼',
												style: theme.textTheme.bodySmall,
											),
										),
									),
								),
							),
						),
						Expanded(
							child: Row(
								children: [
									for (int i = 0; i < days.length; i++)
										Expanded(
											child: Container(
												decoration: BoxDecoration(
													border: Border(
														left: BorderSide(color: Colors.grey.withOpacity(0.5)),
														right: i == days.length - 1
															? BorderSide(color: Colors.grey.withOpacity(0.5))
															: BorderSide.none,
													),
												),
												alignment: Alignment.center,
												child: Text(
													perDayCounts[i] == 0 ? '' : '${perDayCounts[i]}个待办',
													style: theme.textTheme.bodySmall,
												),
											),
										),
								],
							),
						),
					],
				),
			);
		}
		final double fontSize = theme.textTheme.bodySmall?.fontSize ?? 12.0;
		final double pillHeight = fontSize + 16.0;
		const double vGap = 0;
		const int maxVisibleItems = 5;
		final int maxCount = todos.fold<int>(0, (m, l) => math.max(m, l.length));
		final double listHeight = maxCount == 0 ? 0 : maxCount * pillHeight + (maxCount - 1) * vGap + 14;
		final double maxAllowedHeight = maxVisibleItems * pillHeight + (maxVisibleItems - 1) * vGap + 14;
		final double targetHeight = maxCount <= maxVisibleItems
			? listHeight.clamp(minHeight, maxHeight)
			: maxAllowedHeight.clamp(minHeight, maxHeight);
		final bool canScroll = maxCount > maxVisibleItems;

		return ConstrainedBox(
			constraints: BoxConstraints.tightFor(height: targetHeight),
			child: Row(
				children: [
					SizedBox(
						width: gutterWidth,
						child: Align(
							alignment: Alignment.centerRight,
							child: Padding(
								padding: const EdgeInsets.only(right: 8),
								child: InkWell(
									onTap: onToggleExpanded,
									child: Padding(
										padding: const EdgeInsets.symmetric(vertical: 6),
										child: Text(
											isExpanded ? '今日待办 ▲' : '今日待办 ▼',
											style: theme.textTheme.bodySmall,
										),
									),
								),
							),
						),
					),
					Expanded(
						child: ScrollConfiguration(
							behavior: const ScrollBehavior(),
							child: SingleChildScrollView(
								primary: false,
								physics: canScroll ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
								scrollDirection: Axis.vertical,
								child: SizedBox(
									height: canScroll ? listHeight : targetHeight,
									child: Row(
										children: [
											for (int i = 0; i < days.length; i++)
												Expanded(
													child: Container(
														decoration: BoxDecoration(
															border: Border(
																left: BorderSide(color: Colors.grey.withOpacity(0.5)),
																right: i == days.length - 1 ? BorderSide(color: Colors.grey.withOpacity(0.5)) : BorderSide.none,
															),
														),
														padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																for (int j = 0; j < todos[i].length; j++) ...[
																	SizedBox(
																		height: pillHeight,
																		child: GestureDetector(
																			behavior: HitTestBehavior.opaque,
																			onSecondaryTapDown: onSecondaryTapTodo == null
																				? null
																				: (d) => onSecondaryTapTodo!(days[i], todos[i][j], d.globalPosition),
																			child: EventPill(title: todos[i][j].title, color: Colors.blueGrey),
																		),
																	),
																	if (j != todos[i].length - 1) SizedBox(height: vGap),
																],
															],
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
	}
}
