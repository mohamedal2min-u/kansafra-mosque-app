import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../flavor.dart';
import 'prayer_calc.dart';

/// مكان سكن المستخدم خارج كنصفرة: الأذان يكون على توقيته، وتبقى مواقيت كنصفرة ظاهرة بجانبه.
/// يُحفظ على الهاتف فقط ولا يُرسَل لأي جهة.
class HomePlace {
  HomePlace._();

  static const _channel = MethodChannel('kansafra/launcher');
  static const _k = 'home_place_v2';
  static const _kV1 = 'home_place_v1'; // نسخة 77: lat|lng|name
  static const _kLast = 'last_home_v1';
  static const _kApprox = 'home_place_approx';

  /// null = الأذان على توقيت كنصفرة (وفي «رفيق المسلم»: مكة حتى يُعرف الموقع).
  static final site = ValueNotifier<PrayerSite?>(null);

  /// المكان تقريبي (من عنوان الإنترنت)، لم يحدّده المستخدم بموقع هاتفه بعد.
  static final approximate = ValueNotifier<bool>(false);

  /// الموقع المعتمد للأذان: مكان السكن إن حُدّد، وإلا المسجد (أو مكة في «رفيق المسلم»).
  static PrayerSite get active =>
      site.value ?? (AppFlavor.general ? PrayerSite.makkah : PrayerSite.mosque);

  static PrayerSite? _decode(String? v) {
    if (v == null) return null;
    try {
      return PrayerSite.fromJson((jsonDecode(v) as Map).cast());
    } catch (_) {
      return null;
    }
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    site.value = _decode(prefs.getString(_k));
    approximate.value = prefs.getBool(_kApprox) ?? false;
    final v1 = prefs.getString(_kV1)?.split('|');
    if (site.value == null && v1 != null && v1.length == 3) {
      final lat = double.tryParse(v1[0]), lng = double.tryParse(v1[1]);
      if (lat != null && lng != null) {
        await set(PrayerSite.home(v1[2], lat, lng));
      }
    }
    await prefs.remove(_kV1);
  }

  static Future<void> set(PrayerSite? s, {bool approx = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (s == null) {
      await prefs.remove(_k);
    } else {
      await prefs.setString(_k, jsonEncode(s.toJson()));
    }
    await prefs.setBool(_kApprox, approx);
    approximate.value = approx;
    site.value = s;
  }

  static Future<void> clear() => set(null);

  /// آخر مكان سكن قبل العودة إلى كنصفرة: يُستعاد فورًا عند الرجوع إليه (مغترب زار البلد).
  static Future<PrayerSite?> lastHome() async =>
      _decode((await SharedPreferences.getInstance()).getString(_kLast));

  static Future<void> rememberLast(PrayerSite s) async =>
      (await SharedPreferences.getInstance())
          .setString(_kLast, jsonEncode(s.toJson()));

  /// موقع الهاتف. [maxAge]: يُقبل آخر موقع يعرفه الهاتف إن كان أحدث منها، وإلا قراءة واحدة
  /// جديدة: من الواي فاي والشبكة أولًا في «رفيق المسلم»، ومن GPS أولًا في تطبيق كنصفرة
  /// (إنترنت إدلب يمرّ عبر تركيا). null إن تعذّر.
  static Future<({double lat, double lng})?> position(
      {Duration maxAge = const Duration(hours: 6)}) async {
    if (kIsWeb) return null;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('getLocation', {
        'maxAgeMs': maxAge.inMilliseconds,
        'geocode': false,
        'network': AppFlavor.general,
      });
      final lat = (r?['lat'] as num?)?.toDouble();
      final lng = (r?['lng'] as num?)?.toDouble();
      return lat == null || lng == null ? null : (lat: lat, lng: lng);
    } on PlatformException catch (e) {
      if (e.code == 'location_off') rethrow;
      return null;
    }
  }

  /// اسم المدينة بالعربية ورمز البلد (يحتاج إنترنت). قيم فارغة إن تعذّر.
  static Future<({String? name, String? country})> geocode(
      double lat, double lng) async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>(
          'geocode', {'lat': lat, 'lng': lng});
      final name = (r?['name'] as String?)?.trim();
      return (
        name: name == null || name.isEmpty ? null : name,
        country: r?['cc'] as String?
      );
    } catch (_) {
      return (name: null, country: null);
    }
  }

  /// مكان تقريبي من عنوان الإنترنت (المدينة)، بلا أي إذن: مواقيت أولية حتى يحدّد المستخدم موقعه.
  static Future<PrayerSite?> ipPlace() async {
    try {
      final r = await http
          .get(Uri.parse('https://ipinfo.io/json'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map;
      final loc = '${j['loc'] ?? ''}'.split(',');
      final lat = double.tryParse(loc.first), lng = double.tryParse(loc.last);
      if (loc.length != 2 || lat == null || lng == null) return null;
      final g = await geocode(lat, lng);
      return PrayerSite.home(g.name ?? '${j['city'] ?? 'موقعك'}', lat, lng,
          country: g.country ?? j['country'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// يطلب إذن الموقع التقريبي ثم يحدّد مكان السكن. يعيد رسالة خطأ للمستخدم، أو null عند النجاح.
  static Future<String?> locate() async {
    if (kIsWeb) return 'تحديد الموقع متاح على الهاتف فقط.';
    final st = await Permission.locationWhenInUse.request();
    if (!st.isGranted) {
      if (st.isPermanentlyDenied) await openAppSettings();
      return 'لم يُسمح بالوصول إلى الموقع.';
    }
    try {
      final p = await position(maxAge: const Duration(minutes: 30));
      if (p == null) return 'تعذّر تحديد موقعك. حاول مجددًا.';
      final g = await geocode(p.lat, p.lng);
      final old = site.value;
      // تحديث في المدينة نفسها: نُبقي الطريقة وتعديلات الدقائق التي اختارها المستخدم.
      final keep = old != null && old.kmTo(p.lat, p.lng) < 30;
      await set(PrayerSite.home(
          g.name ?? old?.name ?? 'مكان سكني', p.lat, p.lng,
          country: g.country ?? old?.country,
          method: keep ? old.method : null,
          adjustments: keep ? old.adjustments : const {}));
      return null;
    } on PlatformException {
      return 'شغّل خدمة الموقع في الهاتف ثم أعد المحاولة.';
    }
  }
}
