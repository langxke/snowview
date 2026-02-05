import 'package:flutter_test/flutter_test.dart';

import 'package:snowview/core/utils/date_utils.dart';

void main() {
  group('DateUtilsEx minute rounding', () {
    test('floorToMinute strips seconds and subseconds', () {
      final d = DateTime(2026, 1, 26, 22, 22, 34, 123, 456);
      expect(DateUtilsEx.floorToMinute(d), DateTime(2026, 1, 26, 22, 22));
    });

    test('ceilToMinute keeps exact minute', () {
      final d = DateTime(2026, 1, 26, 22, 22);
      expect(DateUtilsEx.ceilToMinute(d), d);
    });

    test('ceilToMinute rounds up when seconds exist', () {
      final d = DateTime(2026, 1, 26, 22, 22, 1);
      expect(DateUtilsEx.ceilToMinute(d), DateTime(2026, 1, 26, 22, 23));
    });
  });
}

