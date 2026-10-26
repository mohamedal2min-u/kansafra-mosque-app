import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../account/identity.dart';
import '../config.dart';
import 'reading_stats.dart';

class BoardEntry {
  final String name;
  final int seconds;
  final bool me;
  const BoardEntry(this.name, this.seconds, this.me);
}

class Board {
  final List<BoardEntry> top;
  final int rank; // 0 = لست في الترتيب بعد
  final int count;
  const Board(this.top, this.rank, this.count);

  static Board parse(Map j) => Board([
        for (final e in (j['top'] as List? ?? const []))
          BoardEntry('${e['n']}', (e['s'] as num).toInt(), e['me'] == true),
      ], (j['rank'] as num?)?.toInt() ?? 0, (j['count'] as num?)?.toInt() ?? 0);
}

class Boards {
  final Board month;
  final Board all;
  const Boards(this.month, this.all);
}

/// نسخة سكربت قديمة لا تعرف ترتيب القرّاء (تحتاج نشرًا جديدًا).
class LeaderboardUnavailable implements Exception {}

/// ترتيب القرّاء بوقت القراءة: يُرسل وقت القراءة (الشهر والإجمالي) مع الاسم الذي يختاره القارئ،
/// أو «قارئ ####» حتى يختار اسمًا.
class Leaderboard {
  Leaderboard._();

  static const _kName = 'reader_name';
  static const _kLast = 'reader_report_last';
  static const _kCache = 'reader_board_v1';
  static const _kOff = 'reader_board_off';

  static bool get supported => !kIsWeb && MosqueConfig.donorsUrl.isNotEmpty;

  static String _month(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static Future<Uri> _uri(Map<String, String> q) async =>
      Uri.parse(MosqueConfig.donorsUrl).replace(
          queryParameters: {...await Identity.instance.params(), ...q});

  /// الاسم الذي اختاره القارئ (null = لم يختر، فيظهر «قارئ ####»).
  static Future<String?> name() async {
    final n = (await SharedPreferences.getInstance()).getString(_kName);
    return n == null || n.isEmpty ? null : n;
  }

  static Future<bool> participating() async =>
      !((await SharedPreferences.getInstance()).getBool(_kOff) ?? false);

  static Future<void> setName(String n) async {
    await (await SharedPreferences.getInstance())
        .setString(_kName, n.trim().replaceAll(RegExp(r'\s+'), ' '));
    await report(force: true);
  }

  /// الخروج من الترتيب أو العودة إليه.
  static Future<void> setParticipating(bool on) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kOff, !on);
    if (on) {
      await report(force: true);
    } else {
      try {
        await http
            .get(await _uri({'action': 'leave'}))
            .timeout(const Duration(seconds: 20));
      } catch (_) {}
    }
  }

  /// يرسل وقت القراءة، مرة كل 10 دقائق على الأكثر (عند الخروج من المصحف وعند فتح التطبيق).
  static Future<void> report({bool force = false}) async {
    if (!supported) return;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kOff) ?? false) return;
    final now = DateTime.now();
    if (!force &&
        now.millisecondsSinceEpoch - (p.getInt(_kLast) ?? 0) < 10 * 60000) {
      return;
    }
    final st = ReadingStats.instance;
    await st.load();
    if (st.total < 60 && !p.containsKey(_kName)) return; // لا شيء يُرسل بعد
    try {
      final res = await http
          .get(await _uri({
            'action': 'read',
            'month': _month(now),
            'ms': '${st.thisMonth}',
            'ts': '${st.total}',
            // الاسم يُرسل فقط إن اختاره القارئ على هذا الهاتف، فلا يمحو اسمًا اختاره من هاتف آخر.
            if (p.containsKey(_kName)) 'name': p.getString(_kName)!,
          }))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && res.body.contains('"ok"')) {
        await p.setInt(_kLast, now.millisecondsSinceEpoch);
      }
    } catch (_) {
      // نعيد المحاولة في المرة القادمة.
    }
  }

  /// آخر ترتيب محفوظ (يُعرض فورًا وبلا إنترنت).
  static Future<Boards?> cached() async {
    final v = (await SharedPreferences.getInstance()).getString(_kCache);
    if (v == null) return null;
    try {
      return _parse(jsonDecode(v));
    } catch (_) {
      return null;
    }
  }

  static Boards _parse(Object? j) {
    if (j is! Map || j['month'] is! Map) throw LeaderboardUnavailable();
    return Boards(Board.parse(j['month']), Board.parse(j['all']));
  }

  static Future<Boards> fetch() async {
    await report(); // ليظهر أحدث وقت للقارئ نفسه
    final res = await http
        .get(await _uri({'action': 'board', 'month': _month(DateTime.now())}))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final body = utf8.decode(res.bodyBytes);
    final Object? j;
    try {
      j = jsonDecode(body);
    } catch (_) {
      throw LeaderboardUnavailable();
    }
    final b = _parse(j);
    await (await SharedPreferences.getInstance()).setString(_kCache, body);
    return b;
  }
}
