import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'audio_store.dart';
import 'quran_data.dart';
import 'reciters.dart';

/// مشغّل واحد للتطبيق: يشغّل سورة ثم ينتقل للتالية تلقائيًا.
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._() {
    _audio.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        if (previewId != null) {
          previewId = null; // انتهت معاينة الأذان
        } else {
          next();
        }
      }
      notifyListeners();
    });
    // نقيس مدة الاستماع لكل قارئ (كل 10 ثوانٍ أثناء التشغيل).
    Timer.periodic(const Duration(seconds: 10), (_) {
      final r = reciter;
      if (r != null && _audio.playing) AudioStore.addListen(r.id, 10);
    });
  }
  static final instance = QuranPlayer._();

  final _audio = AudioPlayer();
  Reciter? reciter;
  Moshaf? moshaf;
  int? surah;
  String? error;
  String? previewId; // معاينة أذان جارية (تستعمل المشغّل نفسه)

  bool get playing => _audio.playing;
  Stream<Duration> get position => _audio.positionStream;
  Duration? get duration => _audio.duration;
  Future<void> seek(Duration d) => _audio.seek(d);

  /// معاينة مقطع أذان على المشغّل نفسه: just_audio_background يدعم مشغّلًا واحدًا فقط في التطبيق.
  Future<void> preview(String id, String title, AudioSource Function(MediaItem tag) build) async {
    await stop();
    previewId = id;
    notifyListeners();
    try {
      await _audio.setAudioSource(build(MediaItem(id: 'preview_$id', title: title, album: 'الأذان')));
      await _audio.play();
    } catch (_) {
      previewId = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> play(Reciter r, Moshaf m, int s) async {
    previewId = null;
    reciter = r;
    moshaf = m;
    surah = s;
    error = null;
    notifyListeners();
    try {
      final tag = MediaItem(id: m.urlFor(s), title: 'سورة ${QuranData.name(s)}', artist: r.name, album: 'القرآن الكريم');
      AudioSource source;
      final f = AudioStore.supported ? await AudioStore.file(r, m, s) : null;
      if (f != null && await f.exists()) {
        // محفوظة على الهاتف: تعمل بدون إنترنت.
        source = AudioSource.file(f.path, tag: tag);
      } else {
        source = AudioSource.uri(Uri.parse(m.urlFor(s)), tag: tag);
      }
      await _audio.setAudioSource(source);
      await _audio.play();
    } catch (e) {
      error = 'تعذّر التشغيل. تحقّق من الإنترنت.';
    }
    notifyListeners();
  }

  /// إيقاف نهائي وإخفاء شريط التشغيل.
  Future<void> stop() async {
    await _audio.stop();
    previewId = null;
    surah = null;
    moshaf = null;
    reciter = null;
    error = null;
    notifyListeners();
  }

  Future<void> toggle() async {
    _audio.playing ? await _audio.pause() : await _audio.play();
    notifyListeners();
  }

  Future<void> next() => _step(1);
  Future<void> previous() => _step(-1);

  Future<void> _step(int d) async {
    final m = moshaf, s = surah, r = reciter;
    if (m == null || s == null || r == null) return;
    final i = m.surahs.indexOf(s) + d;
    if (i < 0 || i >= m.surahs.length) return;
    await play(r, m, m.surahs[i]);
  }
}
