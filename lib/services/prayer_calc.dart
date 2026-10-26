import 'package:adhan/adhan.dart';

import '../config.dart';

/// حساب مواقيت الصلاة بتوقيت المسجد مع تعديلات المسجد.
///
/// قاعدة مهمة: الدوال هنا تُرجع **لحظات حقيقية** (instants) تصلح للمقارنة مع DateTime.now()
/// وللجدولة. للعرض استعمل [wall] فيظهر الوقت بتوقيت المسجد مهما كانت منطقة الهاتف
/// (مثلًا مغترب في أوروبا يرى مواقيت مسجد بلدته).
class PrayerCalc {
  /// سوريا على UTC+3 طوال العام منذ 2022.
  static const offset = Duration(hours: 3);

  static const names = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  /// الصلوات الخمس والشروق بالترتيب.
  static const keys = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

  static final _params = CalculationMethod.muslim_world_league.getParameters()
    ..madhab = Madhab.shafi;
  static final _coords =
      Coordinates(MosqueConfig.latitude, MosqueConfig.longitude);

  /// الوقت الآن كما تُظهره ساعة المسجد (حقوله بتوقيت المسجد). للعرض وتحديد «اليوم» فقط.
  static DateTime mosqueNow() => wall(DateTime.now());

  /// يحوّل لحظة حقيقية إلى ساعة حائط بتوقيت المسجد (للعرض فقط، لا للمقارنة).
  static DateTime wall(DateTime instant) => instant.toUtc().add(offset);

  /// مواقيت يوم من أيام المسجد ([mosqueDay]: تُقرأ منه السنة والشهر واليوم فقط)
  /// كلحظات حقيقية بعد تعديلات المسجد.
  static Map<String, DateTime> day(DateTime mosqueDay) {
    // بدون utcOffset تُرجع المكتبة لحظات حقيقية. (مع utcOffset تُرجع «UTC مُزاحًا» لا يصلح للجدولة.)
    final t = PrayerTimes(
        _coords,
        DateComponents(mosqueDay.year, mosqueDay.month, mosqueDay.day),
        _params);
    final raw = {
      'fajr': t.fajr,
      'sunrise': t.sunrise,
      'dhuhr': t.dhuhr,
      'asr': t.asr,
      'maghrib': t.maghrib,
      'isha': t.isha,
    };
    return {
      for (final e in raw.entries)
        e.key: e.value
            .add(Duration(minutes: MosqueConfig.minuteAdjustments[e.key] ?? 0)),
    };
  }

  /// الصلاة القادمة (من الخمس، بلا الشروق) ووقتها الحقيقي.
  static (String, DateTime) next([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = mosqueNow();
    final times = day(today);
    for (final k in names.keys) {
      if (times[k]!.isAfter(n)) return (k, times[k]!);
    }
    return ('fajr', day(today.add(const Duration(days: 1)))['fajr']!);
  }
}
