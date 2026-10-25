import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'audio_store.dart';
import 'player.dart';
import 'reciters.dart';

/// تنزيل مصحف قارئ واحد كاملًا، على Wi-Fi فقط، مع إمكانية الإيقاف والاستئناف.
class QuranDownloader extends ChangeNotifier {
  QuranDownloader._();
  static final instance = QuranDownloader._();

  Reciter? reciter;
  Moshaf? moshaf;
  int total = 0;
  int done = 0;
  bool running = false;
  String? error;
  bool _cancel = false;

  static Future<bool> onWifi() async {
    final c = await Connectivity().checkConnectivity();
    return c.contains(ConnectivityResult.wifi) ||
        c.contains(ConnectivityResult.ethernet);
  }

  /// يقدّر حجم المصحف بسؤال الخادم عن حجم عيّنة من السور (HEAD) ثم التعميم. null إن تعذّر.
  static Future<int?> estimateBytes(Moshaf m) async {
    final sample = m.surahs.length <= 12
        ? m.surahs
        : [
            for (var i = 0;
                i < m.surahs.length;
                i += (m.surahs.length / 12).ceil())
              m.surahs[i]
          ];
    final client = http.Client();
    try {
      final sizes = await Future.wait(sample.map((s) async {
        try {
          final r = await client
              .head(Uri.parse(m.urlFor(s)))
              .timeout(const Duration(seconds: 10));
          return int.tryParse(r.headers['content-length'] ?? '');
        } catch (_) {
          return null;
        }
      }));
      final ok = sizes.whereType<int>().toList();
      if (ok.length < (sample.length / 2).ceil() || ok.isEmpty) return null;
      final avg = ok.reduce((a, b) => a + b) / ok.length;
      return (avg * m.surahs.length).round();
    } finally {
      client.close();
    }
  }

  Future<void> start(Reciter r, Moshaf m) async {
    if (running) return;
    reciter = r;
    moshaf = m;
    error = null;
    _cancel = false;
    running = true;
    notifyListeners();
    final client = http.Client();
    try {
      // قد يكون المشغّل يقرأ ملفات قارئ آخر سنحذفها: نوقفه أولًا.
      final qp = QuranPlayer.instance;
      if (qp.surah != null &&
          (qp.reciter?.id != r.id || qp.moshaf?.name != m.name))
        await qp.stop();
      await AudioStore.keepOnly(r, m); // قارئ واحد فقط
      await AudioStore.setPinned(r, m);
      total = m.surahs.length;
      done = (await AudioStore.savedSurahs(r, m)).length;
      notifyListeners();
      for (final s in m.surahs) {
        if (_cancel) break;
        final f = await AudioStore.file(r, m, s);
        if (await f.exists()) continue;
        if (!await onWifi()) {
          error = 'انقطع اتصال Wi-Fi. اضغط «متابعة» عند عودته.';
          break;
        }
        await _one(client, m.urlFor(s), f);
        done++;
        notifyListeners();
      }
    } catch (e) {
      error = 'تعذّر التنزيل: $e';
    } finally {
      client.close();
      running = false;
      notifyListeners();
    }
  }

  Future<void> _one(http.Client client, String url, File dest) async {
    final tmp = File('${dest.path}.dl');
    final resp = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final sink = tmp.openWrite();
    try {
      await for (final chunk in resp.stream) {
        if (_cancel) break;
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
    if (_cancel) {
      if (await tmp.exists()) await tmp.delete();
      return;
    }
    await tmp.rename(dest.path);
  }

  /// إيقاف مؤقت: يُكمل لاحقًا من حيث توقف (السور المنزّلة تبقى).
  void pause() {
    _cancel = true;
  }

  Future<void> deleteAll() async {
    _cancel = true;
    if (QuranPlayer.instance.surah != null)
      await QuranPlayer.instance.stop(); // قد يقرأ ملفات سنحذفها
    await AudioStore.clearAll();
    done = 0;
    total = 0;
    reciter = null;
    moshaf = null;
    error = null;
    notifyListeners();
  }
}
