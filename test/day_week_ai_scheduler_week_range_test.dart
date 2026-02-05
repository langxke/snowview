import 'package:flutter_test/flutter_test.dart';

import 'package:snowview/presentation/screens/schedule/day_week_ai_scheduler.dart';

void main() {
  group('DayWeekAiScheduler.computeWeekRange', () {
    test('uses today as start within same week', () {
      final now = DateTime(2026, 1, 26, 22, 22, 34);
      final center = DateTime(2026, 1, 31, 12, 0);

      final r = DayWeekAiScheduler.computeWeekRange(
        now: now,
        centerDate: center,
        startFromNowIfToday: true,
      );

      expect(r.rangeStart, now);
      expect(r.rangeEnd, DateTime(2026, 2, 1, 23, 59, 59));
    });

    test('uses week Monday as start for future week', () {
      final now = DateTime(2026, 1, 26, 22, 22, 34);
      final center = DateTime(2026, 2, 10, 12, 0);

      final r = DayWeekAiScheduler.computeWeekRange(
        now: now,
        centerDate: center,
        startFromNowIfToday: true,
      );

      expect(r.rangeStart, DateTime(2026, 2, 9));
      expect(r.rangeEnd, DateTime(2026, 2, 15, 23, 59, 59));
    });
  });
}

