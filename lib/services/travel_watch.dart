import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../flavor.dart';
import 'adhan_service.dart';
import 'home_place.dart';
import 'prayer_calc.dart';

/// اقتراح ظاهر للمستخدم: «أنت في [name]، اجعل الأذان على توقيتها».
/// [byNetwork]: كُشف من شبكة إنترنت غير محفوظة (لا من الموقع)، فقد يكون في كنصفرة على شبكة جديدة.
class TravelHint {
  final String name;
  final bool byNetwork;
  const TravelHint(this.name, {this.byNetwork = false});
}

/// يكتشف ابتعاد المستخدم عن كنصفرة: يومًا داخل سوريا (حلب مثلًا) أو يومين خارجها،
/// فيقترح عليه الأذان على توقيت مكانه. لا يعمل في الخلفية: يُفحص عند فتح التطبيق فقط.
///
/// المصدر: موقع الهاتف (GPS ثم الشبكة) إن سمح به المستخدم، وهو الأدق.
/// وإلا شبكة الإنترنت: يضغط المستخدم «أنا في كنصفرة» فنحفظ مزوّد الإنترنت الذي يستعمله هناك
/// (ولو واي فاي تركيًا)، لا رقم IP لأنه يتغيّر يوميًا عند كثير من المزوّدين. شبكة غير محفوظة
/// لمدة كافية = خارج كنصفرة.
class TravelWatch {
  TravelWatch._();

  static const _channel = MethodChannel('kansafra/launcher');
  static const _kSince = 'away_since';
  static const _kName = 'away_name';
  static const _kCc = 'away_cc';
  static const _kDismissed = 'away_dismissed';
  static const _kSeen = 'seen_kansafra';
  static const _kLast = 'travel_last_check';
  static const _kEnabled = 'travel_enabled';
  static const _kAsked = 'travel_asked';
  static const _kNets = 'kansafra_networks'; // «AS9121|Turk Telekom»
  static const _kByNet = 'away_by_network';
  static const _notifAway = 9100;
  static const _notifInfo = 9101;

  /// داخل هذه المسافة من المسجد = كنصفرة. وانتقال أكبر من [_moveKm] = مدينة أخرى.
  static const _nearKm = 20.0;
  static const _moveKm = 30.0;

  static final hint = ValueNotifier<TravelHint?>(null);

  /// بطاقة «هل أنت الآن في كنصفرة؟» (أول مرة فقط).
  static final askHere = ValueNotifier<bool>(false);

  static Future<bool> enabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? true;

  static Future<void> setEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEnabled, v);
    if (v) {
      await check(force: true);
    } else {
      askHere.value = false;
      await _clearAway(p);
    }
  }

  /// شبكات كنصفرة المحفوظة (أسماء المزوّدين) للعرض في الإعدادات.
  static Future<List<String>> networks() async => [
        for (final n
            in (await SharedPreferences.getInstance()).getStringList(_kNets) ??
                const <String>[])
          n.split('|').last,
      ];

  static Future<void> clearNetworks() async =>
      (await SharedPreferences.getInstance()).remove(_kNets);

  /// «نعم، أنا في كنصفرة»: نحفظ مزوّد الإنترنت الحالي كشبكة من شبكات كنصفرة.
  /// يعيد رسالة خطأ، أو null عند النجاح.
  static Future<String?> confirmHere() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kAsked, true);
    askHere.value = false;
    if (kIsWeb) return null;
    final n = await _network();
    if (n == null) {
      return 'تعذّر التعرّف على الشبكة. تحقّق من الإنترنت وأعد المحاولة.';
    }
    final nets = p.getStringList(_kNets) ?? <String>[];
    if (!nets.any((e) => e.startsWith('${n.asn}|'))) {
      await p.setStringList(_kNets, [...nets, '${n.asn}|${n.org}']);
    }
    await _clearAway(p, seen: true);
    return null;
  }

  /// «لا، أنا خارجها» أو «ليس الآن» في بطاقة أول مرة.
  static Future<void> answeredAway() async {
    await (await SharedPreferences.getInstance()).setBool(_kAsked, true);
    askHere.value = false;
  }

  /// «لا، شكرًا»: لا نقترح مجددًا حتى يعود إلى كنصفرة ثم يسافر من جديد.
  static Future<void> dismiss() async {
    final p = await SharedPreferences.getInstance();
    final since = p.getInt(_kSince);
    if (since != null) await p.setInt(_kDismissed, since);
    hint.value = null;
    await _cancel(_notifAway);
  }

  static bool _listening = false;

  /// بمجرد تحديد مكان السكن (من أي بطاقة أو من الإعدادات) تختفي بطاقات المكان فورًا،
  /// ولو ظهرت أثناء انتظار الـGPS.
  static void _listen() {
    if (_listening) return;
    _listening = true;
    HomePlace.site.addListener(() async {
      if (HomePlace.site.value == null) return;
      hint.value = null;
      askHere.value = false;
      await (await SharedPreferences.getInstance()).setBool(_kAsked, true);
      await _cancel(_notifAway);
    });
  }

  /// يُستدعى عند فتح التطبيق وعند الرجوع إليه، ويفحص فعليًا مرة كل 3 ساعات على الأكثر.
  static Future<void> check({bool force = false}) async {
    _listen();
    if (kIsWeb) return;
    final p = await SharedPreferences.getInstance();
    if (AppFlavor.general) return _followUser(p, force);
    if (!(p.getBool(_kEnabled) ?? true)) return;
    final granted = await Permission.locationWhenInUse.isGranted;
    askHere.value =
        HomePlace.site.value == null && !(p.getBool(_kAsked) ?? false);
    final now = DateTime.now();
    final last = p.getInt(_kLast) ?? 0;
    if (force || now.millisecondsSinceEpoch - last > 3 * 3600 * 1000) {
      try {
        if (await _probe(p, granted)) {
          await p.setInt(_kLast, now.millisecondsSinceEpoch);
        }
      } catch (_) {
        // لا شيء يتغيّر إن فشل الفحص؛ نعيد المحاولة في الفتح التالي.
      }
    }
    await _evaluate(p, now);
  }

  /// «رفيق المسلم»: المواقيت لمكان المستخدم دائمًا. أول مرة نطلب الموقع (الواي فاي) مباشرة،
  /// وبلا إذن نقدّر المدينة من عنوان الإنترنت. وعند السفر (أكثر من 30 كم) يتحدّث المكان.
  static Future<void> _followUser(SharedPreferences p, bool force) async {
    if (!(p.getBool(_kAsked) ?? false)) {
      await p.setBool(_kAsked, true);
      if (await HomePlace.locate() == null) {
        await p.setInt(_kLast, DateTime.now().millisecondsSinceEpoch);
        await _reschedule();
        return;
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - (p.getInt(_kLast) ?? 0) < 3 * 3600 * 1000) return;
    final home = HomePlace.site.value;
    final approx = HomePlace.approximate.value;
    try {
      if (await Permission.locationWhenInUse.isGranted) {
        final pos = await HomePlace.position(maxAge: const Duration(hours: 3));
        if (pos == null) return;
        final near = home != null && home.kmTo(pos.lat, pos.lng) < _moveKm;
        if (home != null && near && !approx) {
          await p.setInt(_kLast, now);
          return;
        }
        final g = await HomePlace.geocode(pos.lat, pos.lng);
        final country = g.country ?? home?.country;
        // نفس المدينة: نُبقي الطريقة والتعديلات. مدينة أخرى في البلد نفسه: الطريقة فقط.
        await HomePlace.set(PrayerSite.home(
            g.name ?? (near ? home.name : 'موقعي'), pos.lat, pos.lng,
            country: country,
            method: near || (home != null && home.country == country)
                ? home.method
                : null,
            adjustments: near ? home.adjustments : const {}));
      } else if (home == null || approx) {
        final ip = await HomePlace.ipPlace();
        if (ip == null) return;
        if (home != null && home.kmTo(ip.latitude, ip.longitude) < _moveKm) {
          await p.setInt(_kLast, now);
          return;
        }
        await HomePlace.set(ip, approx: true);
      } else {
        await p.setInt(_kLast, now);
        return;
      }
      await p.setInt(_kLast, now);
      await _reschedule();
    } catch (_) {
      // نعيد المحاولة في الفتح التالي.
    }
  }

  /// يحدّد مكان المستخدم ويحدّث الحالة. يعيد false إن لم يُعرف المكان.
  static Future<bool> _probe(SharedPreferences p, bool granted) async {
    double? lat, lng;
    String? cc;
    if (granted) {
      try {
        final pos = await HomePlace.position(maxAge: const Duration(hours: 3));
        lat = pos?.lat;
        lng = pos?.lng;
      } catch (_) {}
    }
    final hasCoords = lat != null && lng != null;
    bool near;
    if (hasCoords) {
      near = PrayerSite.mosque.kmTo(lat, lng) < _nearKm;
    } else {
      // بلا إذن الموقع: شبكة الإنترنت.
      final n = await _network();
      if (n == null) return false;
      cc = n.cc;
      final nets = p.getStringList(_kNets) ?? const <String>[];
      if (nets.isNotEmpty) {
        near = nets.any((e) => e.startsWith('${n.asn}|'));
      } else {
        // لم يحفظ شبكة بعد: نكشف السفر خارج سوريا وتركيا فقط (إنترنت إدلب يمرّ عبر تركيا).
        String? tzId;
        try {
          tzId = await _channel.invokeMethod<String>('timeZoneId');
        } catch (_) {}
        near = cc == 'SY' || cc == 'TR' || tzId == 'Asia/Damascus';
      }
    }

    final home = HomePlace.site.value;

    if (home != null) {
      if (!hasCoords) return true; // بلا موقع لا نغيّر اختيارًا صريحًا للمستخدم
      if (near) {
        // عاد إلى كنصفرة: الأذان على توقيت المسجد، ونتذكّر مكان سكنه لنعيده إن رجع إليه.
        await HomePlace.rememberLast(home);
        await HomePlace.clear();
        await _clearAway(p, seen: true);
        await _reschedule();
        await _info('عدت إلى كنصفرة', 'صار الأذان على توقيت مسجد كنصفرة.');
      } else if (home.kmTo(lat, lng) > _moveKm) {
        // سافر إلى مدينة أخرى: الأذان على توقيتها (طريقة بلدها، بلا تعديلات المدينة السابقة).
        final g = await HomePlace.geocode(lat, lng);
        final country = g.country ?? _countryGuess(lat, lng);
        await HomePlace.set(PrayerSite.home(g.name ?? 'مكاني الحالي', lat, lng,
            country: country,
            method: country == home.country ? home.method : null));
        await _reschedule();
      }
      return true;
    }

    if (near) {
      await _clearAway(p, seen: true);
      return true;
    }

    if (hasCoords) {
      // مغترب رجع إلى مكان سكنه بعد زيارة كنصفرة: نعيده فورًا بلا انتظار.
      final back = await HomePlace.lastHome();
      if (back != null && back.kmTo(lat, lng) < _moveKm) {
        await HomePlace.set(back);
        await _clearAway(p);
        await _reschedule();
        await _info('رجعت إلى ${back.name}',
            'صار الأذان على توقيت ${back.name}، ومواقيت كنصفرة بجانبه.');
        return true;
      }
    }

    if (p.getInt(_kSince) == null) {
      await p.setInt(_kSince, DateTime.now().millisecondsSinceEpoch);
      String? name;
      if (hasCoords) {
        final g = await HomePlace.geocode(lat, lng);
        name = g.name;
        cc = g.country ?? _countryGuess(lat, lng);
      }
      await p.setString(_kName, name ?? '');
      await p.setString(_kCc, cc ?? '');
      await p.setBool(_kByNet, !hasCoords);
    }
    return true;
  }

  /// يُظهر الاقتراح إن مضت المدة (يوم داخل سوريا، يومان خارجها)، أو يجدول إشعارًا لموعدها.
  /// من لم يُرَ في كنصفرة قط (مغترب ثبّت التطبيق حيث يسكن) يُقترح عليه فورًا.
  static Future<void> _evaluate(SharedPreferences p, DateTime now) async {
    final since = p.getInt(_kSince);
    if (since == null ||
        askHere.value || // بطاقة «هل أنت في كنصفرة؟» أولًا
        HomePlace.site.value != null ||
        p.getInt(_kDismissed) == since) {
      hint.value = null;
      return;
    }
    final cc = p.getString(_kCc);
    final name = p.getString(_kName) ?? '';
    // يوم داخل سوريا (وتركيا: قد تكون شبكة إدلب)، ويومان خارجهما.
    final near = cc == 'SY' || cc == 'TR';
    final wait = Duration(hours: near ? 24 : 48);
    final due = DateTime.fromMillisecondsSinceEpoch(since).add(wait);
    final seen = p.getBool(_kSeen) ?? false;
    if (!seen || !now.isBefore(due)) {
      hint.value = TravelHint(name, byNetwork: p.getBool(_kByNet) ?? false);
      return;
    }
    hint.value = null;
    await _scheduleAway(_daytime(due), name, near);
  }

  static Future<void> _clearAway(SharedPreferences p,
      {bool seen = false}) async {
    if (seen) await p.setBool(_kSeen, true);
    for (final k in [_kSince, _kName, _kCc, _kDismissed, _kByNet]) {
      await p.remove(k);
    }
    hint.value = null;
    await _cancel(_notifAway);
  }

  /// بلد تقريبي من الإحداثيات إن فشل اسم المكان (يكفي لاختيار مدة الانتظار).
  static String? _countryGuess(double lat, double lng) =>
      lat > 32.3 && lat < 37.3 && lng > 35.7 && lng < 42.4 ? 'SY' : null;

  /// مزوّد الإنترنت الحالي (رقم الشبكة AS واسمه) وبلده، من خدمة عامة. لا نحفظ رقم IP.
  static Future<({String asn, String org, String? cc})?> _network() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map;
        final org = '${j['org'] ?? ''}'; // «AS9121 Turk Telekom»
        final i = org.indexOf(' ');
        if (org.startsWith('AS') && i > 2) {
          return (
            asn: org.substring(0, i),
            org: org.substring(i + 1),
            cc: j['country'] as String?
          );
        }
      }
    } catch (_) {}
    try {
      final r = await http
          .get(Uri.parse('https://api.ip.sb/geoip'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map;
        final asn = j['asn'];
        if (asn != null) {
          return (
            asn: 'AS$asn',
            org: '${j['asn_organization'] ?? j['organization'] ?? 'AS$asn'}',
            cc: j['country_code'] as String?
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// لا إشعار ليلًا: بين 9 صباحًا و9 مساءً.
  static DateTime _daytime(DateTime t) {
    if (t.hour < 9) return DateTime(t.year, t.month, t.day, 9);
    if (t.hour >= 21) return DateTime(t.year, t.month, t.day + 1, 9);
    return t;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('travel', 'اقتراح توقيت المكان',
        channelDescription: 'عند السفر: اقتراح الأذان على توقيت مكانك'),
  );

  static Future<void> _scheduleAway(
      DateTime at, String name, bool syria) async {
    final where = name.isEmpty ? 'خارج كنصفرة' : 'في $name';
    try {
      await AdhanService.instance.plugin.zonedSchedule(
        _notifAway,
        'هل تريد الأذان على توقيت مكانك؟',
        'أنت $where منذ ${syria ? 'أكثر من يوم' : 'أكثر من يومين'}. افتح التطبيق ليصير الأذان على توقيت ${name.isEmpty ? 'مكانك' : name}.',
        tz.TZDateTime.from(at, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  static Future<void> _info(String title, String body) async {
    try {
      await AdhanService.instance.plugin
          .show(_notifInfo, title, body, _details);
    } catch (_) {}
  }

  static Future<void> _cancel(int id) async {
    try {
      await AdhanService.instance.plugin.cancel(id);
    } catch (_) {}
  }

  static Future<void> _reschedule() async {
    try {
      await AdhanService.instance.scheduleAll(force: true);
    } catch (_) {}
  }
}
