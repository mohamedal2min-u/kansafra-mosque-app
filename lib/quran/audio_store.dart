import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reciters.dart';

/// مدة الاستماع التي يصير بعدها القارئ «معتادًا» فيُحفظ ما تسمعه له على الهاتف.
const kRegularListenSeconds = 3600;

/// حفظ التلاوات على الهاتف للاستماع بدون إنترنت، وقياس مدة الاستماع لكل قارئ.
class AudioStore {
  static bool get supported => !kIsWeb;
  static const _statsKey = 'listen_secs_v1';
  static Map<String, int>? _stats;

  static Future<Directory> _root() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/quran_audio');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  // تجزئة بسيطة ثابتة لمسار الخادم (لتمييز رواية قارئ عن أخرى).
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }

  static String _prefix(Reciter r, Moshaf m) => '${r.id}_${_hash(m.server)}_';

  static Future<File> file(Reciter r, Moshaf m, int surah) async =>
      File('${(await _root()).path}/${_prefix(r, m)}$surah.mp3');

  /// السور المحفوظة كاملة لهذه الرواية.
  static Future<Set<int>> savedSurahs(Reciter r, Moshaf m) async {
    if (!supported) return {};
    final prefix = _prefix(r, m);
    final out = <int>{};
    await for (final e in (await _root()).list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && name.startsWith(prefix) && name.endsWith('.mp3')) {
        final n = int.tryParse(name.substring(prefix.length, name.length - 4));
        if (n != null) out.add(n);
      }
    }
    return out;
  }

  /// مسارات السور المحفوظة (سورة ← مسار الملف) بقراءة المجلد مرة واحدة.
  static Future<Map<int, String>> savedPaths(Reciter r, Moshaf m) async {
    if (!supported) return {};
    final prefix = _prefix(r, m);
    final out = <int, String>{};
    await for (final e in (await _root()).list()) {
      final name = e.uri.pathSegments.last;
      if (e is File && name.startsWith(prefix) && name.endsWith('.mp3')) {
        final n = int.tryParse(name.substring(prefix.length, name.length - 4));
        if (n != null) out[n] = e.path;
      }
    }
    return out;
  }

  /// قارئ واحد فقط: يحذف كل ما حُفظ لغير هذا القارئ/الرواية.
  static Future<void> keepOnly(Reciter r, Moshaf m) async {
    if (!supported) return;
    final prefix = _prefix(r, m);
    await for (final e in (await _root()).list()) {
      if (e is File && !e.uri.pathSegments.last.startsWith(prefix)) {
        await e.delete();
      }
    }
  }

  static const _pinKey = 'pinned_reciter_v1';

  static Future<void> setPinned(Reciter r, Moshaf m) async =>
      (await SharedPreferences.getInstance()).setString(
          _pinKey, jsonEncode({'id': r.id, 'name': r.name, 'm': m.name}));

  static Future<Map<String, dynamic>?> pinned() async {
    final raw = (await SharedPreferences.getInstance()).getString(_pinKey);
    return raw == null
        ? null
        : (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  static Future<void> clearPinned() async =>
      (await SharedPreferences.getInstance()).remove(_pinKey);

  static Future<int> totalBytes() async {
    if (!supported) return 0;
    var sum = 0;
    await for (final e in (await _root()).list()) {
      if (e is File && e.path.endsWith('.mp3')) sum += await e.length();
    }
    return sum;
  }

  static Future<void> clearAll() async {
    if (!supported) return;
    final root = await _root();
    await for (final e in root.list()) {
      if (e is File) await e.delete();
    }
    await clearPinned();
  }

  // ---------------- مدة الاستماع ----------------
  static Future<Map<String, int>> _load() async {
    if (_stats != null) return _stats!;
    final raw = (await SharedPreferences.getInstance()).getString(_statsKey);
    _stats = raw == null
        ? {}
        : (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry('$k', (v as num).toInt()));
    return _stats!;
  }

  static Future<int> listenSeconds(int reciterId) async =>
      (await _load())['$reciterId'] ?? 0;

  static Future<bool> isRegular(int reciterId) async =>
      await listenSeconds(reciterId) >= kRegularListenSeconds;

  static Future<void> addListen(int reciterId, int seconds) async {
    final m = await _load();
    m['$reciterId'] = (m['$reciterId'] ?? 0) + seconds;
    await (await SharedPreferences.getInstance())
        .setString(_statsKey, jsonEncode(m));
  }
}
