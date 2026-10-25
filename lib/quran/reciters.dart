import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// تصنيفات التلاوات.
enum ReciterTag {
  all('الكل'),
  makkah('الحرم المكي'),
  madinah('الحرم المدني'),
  tajweed('مجوّد'),
  murattal('مرتّل'),
  teaching('تعليمي');

  final String label;
  const ReciterTag(this.label);
}

class Moshaf {
  final String name;
  final String server;
  final List<int> surahs;
  Moshaf(this.name, this.server, this.surahs);

  /// رابط ملف السورة: الخادم + رقم السورة من ثلاث خانات.
  String urlFor(int surah) => '$server${surah.toString().padLeft(3, '0')}.mp3';
}

class Reciter {
  final int id;
  final String name;
  final List<Moshaf> moshafs;
  Reciter(this.id, this.name, this.moshafs);

  static const _makkah = ['السديس', 'الشريم', 'المعيقلي', 'بليلة', 'الجهني'];
  static const _madinah = ['الحذيفي', 'البدير', 'القاسم', 'الخياط', 'آل الشيخ'];

  late final Set<ReciterTag> tags = _computeTags();

  Set<ReciterTag> _computeTags() {
    final all = moshafs.map((m) => m.name).join(' ');
    return {
      if (_makkah.any(name.contains)) ReciterTag.makkah,
      if (_madinah.any(name.contains)) ReciterTag.madinah,
      if (all.contains('مجود')) ReciterTag.tajweed,
      if (all.contains('معلم')) ReciterTag.teaching,
      if (moshafs
          .any((m) => !m.name.contains('مجود') && !m.name.contains('معلم')))
        ReciterTag.murattal,
    };
  }
}

/// يجلب القرّاء من واجهة mp3quran.net. يحفظ نسخة للاستخدام لاحقًا إن انقطع الإنترنت.
Map<String, dynamic> _decode(List<int> bytes) =>
    jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

class ReciterApi {
  static const _hosts = [
    'https://www.mp3quran.net/api/v3',
    'https://mp3quran.net/api/v3'
  ];
  static const _cacheKey = 'reciters_cache_v1';
  static List<Reciter>? _cache;
  static String? lastError; // سبب آخر فشل، للتشخيص

  /// يقرأ الردّ بتسامح: يتخطّى أي عنصر ناقص بدل إفشال القائمة كلها.
  static List<Reciter> _parse(Map<String, dynamic> data) {
    final out = <Reciter>[];
    for (final r in (data['reciters'] as List? ?? const [])) {
      if (r is! Map) continue;
      final moshafs = <Moshaf>[];
      for (final m in (r['moshaf'] as List? ?? const [])) {
        if (m is! Map) continue;
        final server = m['server']?.toString() ?? '';
        final list = (m['surah_list']?.toString() ?? '')
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();
        if (server.isEmpty || list.isEmpty) continue;
        moshafs.add(Moshaf(m['name']?.toString() ?? '',
            server.endsWith('/') ? server : '$server/', list));
      }
      final id = (r['id'] as num?)?.toInt();
      if (id == null || moshafs.isEmpty) continue;
      out.add(Reciter(id, r['name']?.toString() ?? '', moshafs));
    }
    return out;
  }

  static List<Reciter> _fromCache(String json) => [
        for (final r in jsonDecode(json) as List)
          Reciter(r['i'] as int, r['n'] as String, [
            for (final m in r['m'] as List)
              Moshaf(m[0] as String, m[1] as String,
                  (m[2] as String).split(',').map(int.parse).toList()),
          ]),
      ];

  static String _toCache(List<Reciter> list) => jsonEncode([
        for (final r in list)
          {
            'i': r.id,
            'n': r.name,
            'm': [
              for (final m in r.moshafs) [m.name, m.server, m.surahs.join(',')]
            ],
          },
      ]);

  static Future<List<Reciter>> load() async {
    if (_cache != null) return _cache!;
    Object? err;
    for (final host in _hosts) {
      try {
        final res = await http
            .get(Uri.parse('$host/reciters?language=ar'), headers: const {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) KansafraMosque/1.0',
        }).timeout(const Duration(seconds: 60));
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        final list = _parse(await compute(_decode, res.bodyBytes));
        if (list.isEmpty) throw Exception('قائمة القرّاء فارغة');
        _cache = list;
        try {
          (await SharedPreferences.getInstance())
              .setString(_cacheKey, _toCache(list));
        } catch (_) {}
        lastError = null;
        return list;
      } catch (e) {
        err = e;
      }
    }
    // لا إنترنت أو فشل الخادم: استخدم آخر نسخة محفوظة إن وُجدت.
    try {
      final cached =
          (await SharedPreferences.getInstance()).getString(_cacheKey);
      if (cached != null) return _cache = _fromCache(cached);
    } catch (_) {}
    lastError = '$err';
    throw err!;
  }
}
