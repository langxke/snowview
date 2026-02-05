import 'package:flutter_test/flutter_test.dart';
import 'package:snowview/presentation/screens/schedule/day_week_ai_scheduler.dart';
import 'package:snowview/presentation/screens/schedule/models.dart';

void main() {
  test('validateAiBlocksForTest allows repeated task blocks across days', () {
    final blocksRaw = [
      {'taskId': 't1', 'title': 'A', 'start': '2026-02-06 20:30', 'end': '2026-02-06 21:30'},
      {'taskId': 't1', 'title': 'A', 'start': '2026-02-07 10:30', 'end': '2026-02-07 11:30'},
    ];

    final freeWindows = <String, List<({DateTime start, DateTime end})>>{
      '2026-02-06': [(start: DateTime(2026, 2, 6, 0, 0), end: DateTime(2026, 2, 6, 23, 59))],
      '2026-02-07': [(start: DateTime(2026, 2, 7, 0, 0), end: DateTime(2026, 2, 7, 23, 59))],
    };

    final availabilityRanges = <String, List<Map<String, int>>>{
      '2026-02-06': [
        {'startMinutes': 0, 'endMinutes': 24 * 60}
      ],
      '2026-02-07': [
        {'startMinutes': 0, 'endMinutes': 24 * 60}
      ],
    };

    final res = DayWeekAiScheduler.validateAiBlocksForTest(
      raw: blocksRaw,
      allowedIds: const {'t1'},
      effectiveStart: DateTime(2026, 2, 6, 0, 0),
      effectiveEnd: DateTime(2026, 2, 7, 23, 59),
      freeWindows: freeWindows,
      availabilityRanges: availabilityRanges,
      busy: const <CalendarEvent>[],
    );

    expect(res.violations, isEmpty);
    expect(res.normalizedBlocks.length, 2);
  });

  test('validateAiBlocksForTest detects overlapping blocks', () {
    final blocksRaw = [
      {'taskId': 't1', 'title': 'A', 'start': '2026-02-07 10:00', 'end': '2026-02-07 11:00'},
      {'taskId': 't2', 'title': 'B', 'start': '2026-02-07 10:30', 'end': '2026-02-07 11:30'},
    ];

    final freeWindows = <String, List<({DateTime start, DateTime end})>>{
      '2026-02-07': [(start: DateTime(2026, 2, 7, 0, 0), end: DateTime(2026, 2, 7, 23, 59))],
    };

    final availabilityRanges = <String, List<Map<String, int>>>{
      '2026-02-07': [
        {'startMinutes': 0, 'endMinutes': 24 * 60}
      ],
    };

    final res = DayWeekAiScheduler.validateAiBlocksForTest(
      raw: blocksRaw,
      allowedIds: const {'t1', 't2'},
      effectiveStart: DateTime(2026, 2, 7, 0, 0),
      effectiveEnd: DateTime(2026, 2, 7, 23, 59),
      freeWindows: freeWindows,
      availabilityRanges: availabilityRanges,
      busy: const <CalendarEvent>[],
    );

    expect(res.violations.isNotEmpty, true);
    expect(res.violations.first['reason'], 'overlaps_another_block');
  });
}

