import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// إذاعة قرآن تُبث مباشرة (رابط صوت مستمر).
class RadioStation {
  final int id;
  final String name;
  final String url;
  final bool featured;
  const RadioStation(this.id, this.name, this.url, {this.featured = false});
}

/// إذاعات القرآن المباشرة من واجهة mp3quran (177 إذاعة: كبار القرّاء والتفسير)،
/// مع الإذاعات المعروفة في الأعلى.
class RadioApi {
  static const _hosts = [
    'https://www.mp3quran.net/api/v3',
    'https://mp3quran.net/api/v3'
  ];
  static const _cacheKey = 'radios_cache_v1';
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Android) KansafraMosque'
  };

  /// إذاعات معروفة تظهر أولًا (تحققنا من عمل روابطها).
  static const featured = [
    RadioStation(-1, 'إذاعة القرآن الكريم من القاهرة',
        'https://n0e.radiojar.com/8s5u5tpdtwzuv',
        featured: true),
    RadioStation(-2, 'إذاعة القرآن الكريم من السعودية',
        'https://stream.radiojar.com/0tpy1h0kxtzuv',
        featured: true),
  ];

  static List<RadioStation> _parse(String body) {
    final j = jsonDecode(body);
    final list = (j is Map ? j['radios'] : j) as List? ?? const [];
    final out = <RadioStation>[];
    for (final r in list) {
      if (r is! Map) continue;
      final name = '${r['name'] ?? ''}'.replaceAll(RegExp(r'-+$'), '').trim();
      final url = '${r['url'] ?? ''}';
      if (name.isEmpty || url.isEmpty) continue;
      // ترجمات المعاني بلغات أخرى لا تخص أهل البلدة، والإذاعات المعروفة مضافة في الأعلى.
      if (name.startsWith('ترجمة') || featured.any((f) => f.url == url))
        continue;
      out.add(RadioStation((r['id'] as num?)?.toInt() ?? 0, name, url));
    }
    return out;
  }

  static Future<List<RadioStation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final h in _hosts) {
      try {
        final res = await http
            .get(Uri.parse('$h/radios?language=ar'), headers: _headers)
            .timeout(const Duration(seconds: 25));
        if (res.statusCode != 200) continue;
        final body = utf8.decode(res.bodyBytes);
        final list = _parse(body);
        if (list.isEmpty) continue;
        await prefs.setString(_cacheKey, body);
        return [...featured, ...list];
      } catch (_) {}
    }
    final cached = prefs.getString(_cacheKey);
    return [...featured, if (cached != null) ..._parse(cached)];
  }
}
