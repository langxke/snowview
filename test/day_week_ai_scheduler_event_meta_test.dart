import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snowview/presentation/screens/schedule/day_week_ai_scheduler.dart';

void main() {
  group('DayWeekAiScheduler event meta', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('writes and reads originDateKey', () async {
      final prefs = await SharedPreferences.getInstance();
      await DayWeekAiScheduler.writeEventMetaAiForTest(
        prefs: prefs,
        eventId: 'e1',
        originDateKey: '2026-02-03',
      );

      final meta = DayWeekAiScheduler.readEventMetaForTest(prefs: prefs, eventId: 'e1');
      expect(meta.ai, isTrue);
      expect(meta.originDateKey, '2026-02-03');
    });

    test('supports legacy meta without originDateKey', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('event_meta_v1_e2', '{"ai":true}');

      final meta = DayWeekAiScheduler.readEventMetaForTest(prefs: prefs, eventId: 'e2');
      expect(meta.ai, isTrue);
      expect(meta.originDateKey, isNull);
    });

    test('parses dateOnlyKey', () {
      final d = DayWeekAiScheduler.tryParseDateOnlyKeyForTest('2026-02-03');
      expect(d, DateTime(2026, 2, 3));

      expect(DayWeekAiScheduler.tryParseDateOnlyKeyForTest('bad'), isNull);
      expect(DayWeekAiScheduler.tryParseDateOnlyKeyForTest('2026-02'), isNull);
      expect(DayWeekAiScheduler.tryParseDateOnlyKeyForTest('2026-xx-03'), isNull);
    });
  });
}

