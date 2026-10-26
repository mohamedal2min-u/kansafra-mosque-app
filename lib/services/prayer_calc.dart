import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';

import '../config.dart';

/// مكان تُحسب له المواقيت: المسجد في كنصفرة، أو مكان سكن المستخدم (مغترب في السويد مثلًا).
///
/// قاعدة مهمة: الدوال هنا تُرجع **لحظات حقيقية** (instants) تصلح للمقارنة مع DateTime.now()
/// وللجدولة. للعرض استعمل [wall] فيظهر الوقت بتوقيت المكان نفسه.
class PrayerSite {
  final String name;
  final double latitude;
  final double longitude;

  /// فرق توقيت المكان عن UTC للعرض. null = توقيت الهاتف (مكان السكن).
  final Duration? offset;

  /// أم القرى لمكان السكن، ورابطة العالم الإسلامي مع تعديلات المسجد لكنصفرة.
  final bool ummAlQura;
  final Map<String, int> adjustments;

  const PrayerSite(this.name, this.latitude, this.longitude,
      {this.offset, this.ummAlQura = false, this.adjustments = const {}});

  /// المسجد: سوريا على UTC+3 طوال العام منذ 2022.
  static const mosque = PrayerSite(
      'كنصفرة', MosqueConfig.latitude, MosqueConfig.longitude,
      offset: Duration(hours: 3), adjustments: MosqueConfig.minuteAdjustments);

  /// مكان السكن: أم القرى، وتوقيت الهاتف للعرض.
  factory PrayerSite.home(String name, double lat, double lng) =>
      PrayerSite(name, lat, lng, ummAlQura: true);

  /// مفتاح يتغيّر بتغيّر المكان أو الطريقة (لبصمة جدولة الأذان).
  String get key =>
      '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}|'
      '${ummAlQura ? 'uq' : 'mwl'}|$adjustments';

  /// يحوّل لحظة حقيقية إلى ساعة حائط بتوقيت المكان (للعرض فقط، لا للمقارنة).
  DateTime wall(DateTime instant) =>
      offset == null ? instant.toLocal() : instant.toUtc().add(offset!);

  /// الوقت الآن بتوقيت المكان. للعرض وتحديد «اليوم» فقط.
  DateTime now() => wall(DateTime.now());

  CalculationParameters get _params {
    final p = (ummAlQura
        ? CalculationMethod.umm_al_qura.getParameters()
        : CalculationMethod.muslim_world_league.getParameters())
      ..madhab = Madhab.shafi;
    // في الشمال (السويد): لا يغيب الشفق صيفًا، فالفجر لا يُبكَّر عن آخر سُبع من الليل.
    if (latitude.abs() > 48) {
      p.highLatitudeRule = HighLatitudeRule.seventh_of_the_night;
    }
    return p;
  }

  /// مواقيت يوم من أيام المكان ([day]: تُقرأ منه السنة والشهر واليوم فقط) كلحظات حقيقية.
  /// null إن تعذّر الحساب (أقصى الشمال صيفًا: الشمس لا تغيب).
  Map<String, DateTime>? day(DateTime day) {
    try {
      final date = DateComponents(day.year, day.month, day.day);
      // بدون utcOffset تُرجع المكتبة لحظات حقيقية. (مع utcOffset تُرجع «UTC مُزاحًا» لا يصلح للجدولة.)
      final t = PrayerTimes(Coordinates(latitude, longitude), date, _params);
      final raw = {
        'fajr': t.fajr,
        'sunrise': t.sunrise,
        'dhuhr': t.dhuhr,
        'asr': t.asr,
        'maghrib': t.maghrib,
        'isha': t.isha,
      };
      final extra = Map.of(adjustments);
      // أم القرى: العشاء بعد المغرب بساعتين في رمضان بدل ساعة ونصف.
      if (ummAlQura &&
          HijriCalendar.fromDate(DateTime(day.year, day.month, day.day))
                  .hMonth ==
              9) {
        extra['isha'] = (extra['isha'] ?? 0) + 30;
      }
      return {
        for (final e in raw.entries)
          e.key: e.value.add(Duration(minutes: extra[e.key] ?? 0)),
      };
    } catch (_) {
      return null;
    }
  }

  /// اليوم التالي بالتقويم (لا بإضافة 24 ساعة، فتغيير الساعة الصيفية لا يقفز يومًا).
  static DateTime nextDay(DateTime d, [int n = 1]) =>
      DateTime.utc(d.year, d.month, d.day + n);

  /// الصلاة القادمة (من الخمس، بلا الشروق) ووقتها الحقيقي. null إن تعذّر الحساب.
  (String, DateTime)? next([DateTime? now]) {
    final n = now ?? DateTime.now();
    final today = wall(n);
    for (var d = 0; d < 3; d++) {
      final times = day(nextDay(today, d));
      if (times == null) continue;
      for (final k in PrayerCalc.names.keys) {
        if (times[k]!.isAfter(n)) return (k, times[k]!);
      }
    }
    return null;
  }
}

/// مواقيت المسجد (كنصفرة). واجهة مختصرة فوق [PrayerSite.mosque].
class PrayerCalc {
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

  static DateTime mosqueNow() => PrayerSite.mosque.now();
  static DateTime wall(DateTime instant) => PrayerSite.mosque.wall(instant);
  static Map<String, DateTime> day(DateTime mosqueDay) =>
      PrayerSite.mosque.day(mosqueDay)!;
  static (String, DateTime) next([DateTime? now]) =>
      PrayerSite.mosque.next(now)!;
}
