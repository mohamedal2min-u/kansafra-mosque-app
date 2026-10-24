import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;

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
      if (moshafs.any((m) => !m.name.contains('مجود') && !m.name.contains('معلم')))
        ReciterTag.murattal,
    };
  }
}

/// يجلب القرّاء من واجهة mp3quran.net (يحتاج إنترنت؛ القراءة النصية لا تحتاجه).
Map<String, dynamic> _decode(List<int> bytes) => jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

class ReciterApi {
  static String base = 'https://mp3quran.net/api/v3';
  static List<Reciter>? _cache;

  static Future<List<Reciter>> load() async {
    if (_cache != null) return _cache!;
    final res = await http.get(Uri.parse('$base/reciters?language=ar'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final data = await compute(_decode, res.bodyBytes);
    _cache = [
      for (final r in data['reciters'] as List)
        Reciter(
          r['id'] as int,
          r['name'] as String,
          [
            for (final m in r['moshaf'] as List)
              Moshaf(
                m['name'] as String,
                m['server'] as String,
                (m['surah_list'] as String)
                    .split(',')
                    .where((e) => e.trim().isNotEmpty)
                    .map(int.parse)
                    .toList(),
              ),
          ],
        ),
    ];
    return _cache!;
  }
}
