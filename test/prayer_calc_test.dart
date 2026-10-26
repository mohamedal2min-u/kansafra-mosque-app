import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/services/prayer_calc.dart';

void main() {
  test('الصلوات الخمس مرتّبة زمنيًا وبفواصل معقولة', () {
    for (final d in [
      DateTime(2026, 1, 15),
      DateTime(2026, 6, 21),
      DateTime(2026, 10, 26)
    ]) {
      final t = PrayerCalc.forDate(d);
      final order = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue,
            reason: 'الترتيب مختل في $d عند $i');
      }
      final fajrToDhuhr = t.dhuhr.difference(t.fajr).inHours;
      expect(fajrToDhuhr, inInclusiveRange(4, 10));
    }
  });

  test('تعديل الدقائق يُضاف على الوقت', () {
    final t = DateTime(2026, 1, 1, 12);
    final adj = PrayerCalc.adjusted('dhuhr', t);
    expect(adj.difference(t).inMinutes, greaterThanOrEqualTo(0));
  });
}
