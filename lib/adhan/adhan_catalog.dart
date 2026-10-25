import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../launcher.dart';
import '../settings.dart';

class OnlineAdhan {
  final String id;
  final String name;
  final String file;
  final bool fajr;
  final int bytes;
  const OnlineAdhan(this.id, this.name, this.file, this.fajr, this.bytes);

  String get url => '${MosqueConfig.adhanCatalogBase}/$file';
}

/// قائمة المؤذنين الأونلاين: تُجلب من الإنترنت ويُحمَّل منها ما يختاره المستخدم فقط.
class AdhanCatalog {
  static const _cacheKey = 'adhan_catalog_v1';
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Android) KansafraMosque'
  };
  static String? lastError;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static List<OnlineAdhan> _parse(String body) {
    final j = jsonDecode(body) as Map<String, dynamic>;
    return [
      for (final v in (j['voices'] as List))
        OnlineAdhan(v['id'] as String, v['name'] as String, v['file'] as String,
            v['fajr'] == true, (v['bytes'] as num?)?.toInt() ?? 0),
    ];
  }

  /// يجلب الكتالوج، وإن فشل الاتصال يعود إلى آخر نسخة محفوظة.
  static Future<List<OnlineAdhan>> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await http
          .get(Uri.parse('${MosqueConfig.adhanCatalogBase}/catalog.json'),
              headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = utf8.decode(res.bodyBytes);
      final list = _parse(body);
      await prefs.setString(_cacheKey, body);
      lastError = null;
      return list;
    } catch (e) {
      lastError = '$e';
      final cached = prefs.getString(_cacheKey);
      if (cached != null) return _parse(cached);
      rethrow;
    }
  }

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/adhan_dl');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<File> file(OnlineAdhan v) async =>
      File('${(await _dir()).path}/adhan_dl_${v.id}.mp3');

  static Future<Set<String>> downloaded() async {
    if (!supported) return {};
    final out = <String>{};
    await for (final e in (await _dir()).list()) {
      final n = e.uri.pathSegments.last;
      if (e is File && n.startsWith('adhan_dl_') && n.endsWith('.mp3'))
        out.add(n.substring(9, n.length - 4));
    }
    return out;
  }

  /// يحمّل المقطع (نحو 240 ك.ب) ثم يسجّله ليستعمله النظام كصوت إشعار. يعيد الاختيار الجاهز.
  static Future<CustomAdhan> downloadAndRegister(OnlineAdhan v) async {
    final f = await file(v);
    if (!await f.exists() || await f.length() < 20000) {
      final res = await http
          .get(Uri.parse(v.url), headers: _headers)
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200)
        throw Exception('تعذّر التحميل (HTTP ${res.statusCode})');
      final tmp = File('${f.path}.dl');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(f.path);
    }
    final uri = await Launcher.registerSound(f.path, 'أذان - ${v.name}');
    if (uri == null) throw Exception('تعذّر تسجيل الصوت');
    return CustomAdhan(v.id, v.name, uri);
  }

  static Future<void> delete(OnlineAdhan v) async {
    final f = await file(v);
    if (await f.exists()) await f.delete();
  }
}
