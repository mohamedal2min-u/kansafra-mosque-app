import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../settings.dart';

/// أذان إضافي يُحمَّل عند الطلب من [MosqueConfig.adhanCatalogUrl]، فلا يزيد حجم التطبيق.
/// الصوت المحمَّل يُحفظ في مخزن أصوات الهاتف ليستطيع النظام تشغيله عند التنبيه (أندرويد 10 فأعلى).
class AdhanCatalog {
  static const _channel = MethodChannel('org.kansafra.kansafra_mosque/adhan');
  static const _kCache = 'adhan_catalog';

  static bool get enabled => MosqueConfig.adhanCatalogUrl.isNotEmpty;

  static String _uriKey(AdhanVoice v, bool long) => 'adhan_uri_${v.id}_${long ? 'long' : 'short'}';

  /// يملأ [remoteVoices] من النسخة المحفوظة (بدون إنترنت).
  static Future<void> restore() async {
    if (!enabled || remoteVoices.isNotEmpty) return;
    final body = (await SharedPreferences.getInstance()).getString(_kCache);
    if (body != null) _parse(body);
  }

  /// يجلب القائمة من الإنترنت ويحفظها، وعند الفشل يبقى ما هو محفوظ.
  static Future<void> refresh() async {
    if (!enabled) return;
    try {
      final res = await http.get(Uri.parse(MosqueConfig.adhanCatalogUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final body = utf8.decode(res.bodyBytes);
      if (_parse(body)) {
        await (await SharedPreferences.getInstance()).setString(_kCache, body);
      }
    } catch (_) {
      await restore();
    }
  }

  static bool _parse(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = <AdhanVoice>[];
      for (final e in data['voices'] as List) {
        final m = e as Map<String, dynamic>;
        final long = m['long'] as String?;
        final short = m['short'] as String?;
        if (long == null || short == null) continue;
        list.add(AdhanVoice('r_${m['id']}', '', m['name'] as String, (m['credit'] as String?) ?? '',
            longUrl: long, shortUrl: short));
      }
      remoteVoices
        ..clear()
        ..addAll(list);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// عنوان الصوت في مخزن الهاتف إن كان محمَّلًا، وإلا null.
  static Future<String?> uriFor(AdhanChoice c) async {
    final v = c.voice;
    if (v == null || !v.isRemote) return null;
    return (await SharedPreferences.getInstance()).getString(_uriKey(v, c.long));
  }

  static Future<bool> isDownloaded(AdhanVoice v, bool long) async =>
      (await SharedPreferences.getInstance()).getString(_uriKey(v, long)) != null;

  /// يحمّل الصوت ويحفظه في مخزن الهاتف. يعيد false عند أي فشل (بدون إنترنت أو أندرويد أقدم من 10).
  static Future<bool> download(AdhanVoice v, bool long) async {
    final url = v.url(long);
    if (url == null) return false;
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;
      final uri = await _channel.invokeMethod<String>('saveSound', {
        'name': 'kansafra_${v.id}_${long ? 'long' : 'short'}',
        'bytes': res.bodyBytes,
      });
      if (uri == null) return false;
      await (await SharedPreferences.getInstance()).setString(_uriKey(v, long), uri);
      return true;
    } catch (_) {
      return false;
    }
  }
}
