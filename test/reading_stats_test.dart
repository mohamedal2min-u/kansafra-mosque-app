import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/quran/reading_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _key(DateTime d) => ReadingStats.keyOf(d);

void main() {
  test('تنسيق المدة', () {
    expect(ReadingStats.format(0), '٠ دقيقة');
    expect(ReadingStats.format(30), 'أقل من دقيقة');
    expect(ReadingStats.format(5 * 60), '5 دقيقة');
    expect(ReadingStats.format(3600), '1 ساعة');
    expect(ReadingStats.format(3600 + 25 * 60), '1 ساعة و25 دقيقة');
    expect(ReadingStats.formatShort(3600 + 25 * 60), '1 س 25 د');
  });

  test('الأيام المتتالية والمجاميع الشهرية والسنوية', () async {
    final now = DateTime.now();
    DateTime ago(int n) => now.subtract(Duration(days: n));
    SharedPreferences.setMockInitialValues({
      'read_days_v1': jsonEncode({
        _key(now): 120,
        _key(ago(1)): 300,
        _key(ago(2)): 90,
        _key(ago(4)): 600
      }),
    });
    final st = ReadingStats.instance;
    await st.load();
    expect(st.today, 120);
    expect(st.streak, 3); // اليوم وأمس وقبل أمس (قبل 3 أيام فجوة)
    expect(st.week, 120 + 300 + 90 + 600);
    expect(st.lastWeek.length, 7);
    expect(st.thisYear, greaterThanOrEqualTo(st.thisMonth));
    await st.add(60);
    expect(st.today, 180);
    expect(st.total, greaterThanOrEqualTo(st.today));
  });
}
