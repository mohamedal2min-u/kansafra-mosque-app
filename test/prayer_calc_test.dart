import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/services/prayer_calc.dart';

void main() {
  test('الصلوات مرتّبة زمنيًا وبفواصل معقولة', () {
    for (final d in [
      DateTime(2026, 1, 15),
      DateTime(2026, 6, 21),
      DateTime(2026, 10, 26)
    ]) {
      final t = PrayerCalc.day(d);
      final order = [for (final k in PrayerCalc.keys) t[k]!];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue,
            reason: 'الترتيب مختل في $d عند $i');
      }
      expect(
          t['dhuhr']!.difference(t['fajr']!).inHours, inInclusiveRange(4, 10));
    }
  });

  // انحدار: كانت المواقيت تُعامَل كـ UTC وهي «UTC مُزاح»، فيتأخر الأذان 3 ساعات.
  test('اللحظة الحقيقية للظهر بتوقيت سوريا (UTC+3)', () {
    final t = PrayerCalc.day(DateTime(2026, 10, 26));
    final dhuhr = t['dhuhr']!;
    // الظهر في كنصفرة نهاية أكتوبر نحو 12:1x بتوقيت دمشق = 09:1x بتوقيت غرينتش.
    expect(dhuhr.toUtc().hour, 9);
    expect(PrayerCalc.wall(dhuhr).hour, 12);
    final fajr = t['fajr']!;
    expect(PrayerCalc.wall(fajr).hour, inInclusiveRange(4, 5));
  });

  test('الصلاة القادمة بعد لحظة معيّنة', () {
    final t = PrayerCalc.day(PrayerCalc.mosqueNow());
    final (k, at) =
        PrayerCalc.next(t['dhuhr']!.subtract(const Duration(minutes: 1)));
    expect(k, 'dhuhr');
    expect(at, t['dhuhr']);
  });
}
