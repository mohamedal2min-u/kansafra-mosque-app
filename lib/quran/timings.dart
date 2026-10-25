import 'dart:convert';

import 'package:http/http.dart' as http;

import 'quran_data.dart';
import 'reciters.dart';

/// توقيت بداية كل آية (بالمللي ثانية) من خدمة mp3quran إن توفّر لهذا القارئ والسورة.
/// أي فشل أو عدم تطابق مع مدة الملف يعيد null فيُستعمل التقدير بنسبة طول النص.
class VerseTimings {
  static const _hosts = [
    'https://www.mp3quran.net/api/v3',
    'https://mp3quran.net/api/v3'
  ];
  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Android) KansafraMosque'
  };
  static List<Map<String, dynamic>>? _reads;
  static final _cache = <String, List<int>?>{};

  static String _norm(String s) => s
      .replaceAll(RegExp(r'[ً-ٰٟـ\s]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');

  static Future<dynamic> _get(String path) async {
    for (final h in _hosts) {
      try {
        final res = await http
            .get(Uri.parse('$h$path'), headers: _headers)
            .timeout(const Duration(seconds: 15));
        if (res.statusCode == 200)
          return jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {}
    }
    return null;
  }

  static Future<int?> _readId(Reciter r) async {
    if (_reads == null) {
      final d = await _get('/ayat_timing/reads');
      final list = d is Map ? (d['reads'] ?? d['data']) : d;
      if (list is! List) return null;
      _reads =
          list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    final n = _norm(r.name);
    for (final e in _reads!) {
      final en = _norm('${e['name'] ?? ''}');
      if (en.isNotEmpty && (en == n || n.contains(en) || en.contains(n)))
        return (e['id'] as num?)?.toInt();
    }
    return null;
  }

  /// بدايات الآيات (فهرس 0 = الآية 1)، أو null إن لم تتوفر أو لم تطابق الملف.
  static Future<List<int>?> load(
      Reciter r, int surah, Duration audioDuration) async {
    final key = '${r.id}:$surah';
    if (_cache.containsKey(key)) return _cache[key];
    List<int>? out;
    try {
      final id = await _readId(r);
      if (id != null) {
        final d = await _get('/ayat_timing?surah=$surah&read=$id');
        final list =
            d is Map ? (d['ayat_timing'] ?? d['data'] ?? d['timings']) : d;
        if (list is List)
          out = _parse(list, QuranData.verseCount(surah), audioDuration);
      }
    } catch (_) {
      out = null;
    }
    return _cache[key] = out;
  }

  static List<int>? _parse(List list, int verses, Duration audio) {
    final starts = <int, int>{};
    var lastEnd = 0;
    for (final e in list.whereType<Map>()) {
      final a = (e['ayah'] as num?)?.toInt();
      final s = (e['start_time'] as num?)?.toDouble();
      final en = (e['end_time'] as num?)?.toDouble();
      if (a == null || s == null || a < 1) continue;
      starts[a] = s.round();
      if (en != null && en > lastEnd) lastEnd = en.round();
    }
    if (starts.length != verses) return null;
    var scale = 1;
    final ms = audio.inMilliseconds;
    // بعض الخدمات تعطي الثواني بدل المللي ثانية.
    if (lastEnd > 0 && (lastEnd * 1000 - ms).abs() < (lastEnd - ms).abs())
      scale = 1000;
    final out = [for (var i = 1; i <= verses; i++) (starts[i] ?? -1) * scale];
    for (var i = 0; i < out.length; i++) {
      if (out[i] < 0 || (i > 0 && out[i] < out[i - 1])) return null;
    }
    // تحقق أن التوقيت يخص هذا الملف الصوتي: آخر آية تبدأ قبل نهاية الملف وبعد منتصفه.
    if (out.last >= ms || out.last < ms * 0.5) return null;
    return out;
  }
}
