import 'package:adhan/adhan.dart' show CalculationMethod;
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
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

  group('مكان السكن (أم القرى)', () {
    final stockholm = PrayerSite.home('ستوكهولم', 59.3293, 18.0686,
        method: CalculationMethod.umm_al_qura);

    test('الظهر في ستوكهولم قرب منتصف النهار، والعشاء بعد المغرب بساعة ونصف',
        () {
      final t = stockholm.day(DateTime(2026, 10, 26))!;
      // 26 أكتوبر: ستوكهولم على UTC+1، والظهر نحو 11:5x محليًا = 10:5x غرينتش.
      expect(t['dhuhr']!.toUtc().hour, 10);
      expect(t['isha']!.difference(t['maghrib']!).inMinutes, 90);
      final order = [for (final k in PrayerCalc.keys) t[k]!];
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue);
      }
    });

    test('صيف الشمال: للفجر وقت قبل الشروق رغم أن الشفق لا يغيب', () {
      final t = stockholm.day(DateTime(2026, 6, 21))!;
      expect(t['fajr']!.isBefore(t['sunrise']!), isTrue);
      expect(t['sunrise']!.difference(t['fajr']!).inMinutes, greaterThan(20));
    });

    test('رمضان: العشاء بعد المغرب بساعتين', () {
      final d = DateTime(2027, 2, 20);
      expect(HijriCalendar.fromDate(d).hMonth, 9);
      final t = stockholm.day(d)!;
      expect(t['isha']!.difference(t['maghrib']!).inMinutes, 120);
    });

    test('أقصى الشمال صيفًا (الشمس لا تغيب) لا يُعطّل التطبيق', () {
      const kiruna = PrayerSite('كيرونا', 67.85, 20.22,
          method: CalculationMethod.umm_al_qura);
      expect(() => kiruna.day(DateTime(2026, 6, 21)), returnsNormally);
      expect(() => kiruna.next(), returnsNormally);
    });

    test('اليوم التالي بالتقويم لا يقفز يومًا عند تغيير الساعة', () {
      final d = PrayerSite.nextDay(DateTime(2026, 3, 28, 23, 30));
      expect([d.year, d.month, d.day], [2026, 3, 29]);
    });

    test('مفتاح الجدولة يختلف بين المسجد ومكان السكن', () {
      expect(stockholm.key, isNot(PrayerSite.mosque.key));
    });

    test(
        'الطريقة الافتراضية: رابطة العالم الإسلامي في أوروبا وأم القرى في السعودية',
        () {
      expect(PrayerSite.defaultMethod('SE'),
          CalculationMethod.muslim_world_league);
      expect(PrayerSite.defaultMethod(null),
          CalculationMethod.muslim_world_league);
      expect(PrayerSite.defaultMethod('SA'), CalculationMethod.umm_al_qura);
      expect(PrayerSite.defaultMethod('TR'), CalculationMethod.turkey);
    });

    test('تعديل الدقائق يُطبَّق ويُحفظ ويُستعاد', () {
      final base = PrayerSite.home('ستوكهولم', 59.3293, 18.0686, country: 'SE');
      final adj = base.copyWith(adjustments: {'isha': -10, 'fajr': 5});
      final a = base.day(DateTime(2026, 10, 26))!;
      final b = adj.day(DateTime(2026, 10, 26))!;
      expect(b['isha']!.difference(a['isha']!).inMinutes, -10);
      expect(b['fajr']!.difference(a['fajr']!).inMinutes, 5);
      final back = PrayerSite.fromJson(adj.toJson())!;
      expect(back.key, adj.key);
      expect(back.country, 'SE');
    });

    test('المسافة: حلب أبعد من 20 كم عن كنصفرة', () {
      expect(PrayerSite.mosque.kmTo(36.2021, 37.1343), greaterThan(70));
      expect(PrayerSite.mosque.kmTo(35.66, 36.49), lessThan(2));
    });
  });
}
