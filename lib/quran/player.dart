import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'reciters.dart';

/// مشغّل واحد للتطبيق: يشغّل سورة ثم ينتقل للتالية تلقائيًا.
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._() {
    _audio.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) next();
      notifyListeners();
    });
  }
  static final instance = QuranPlayer._();

  final _audio = AudioPlayer();
  Reciter? reciter;
  Moshaf? moshaf;
  int? surah;
  String? error;

  bool get playing => _audio.playing;
  Stream<Duration> get position => _audio.positionStream;
  Duration? get duration => _audio.duration;
  Future<void> seek(Duration d) => _audio.seek(d);

  Future<void> play(Reciter r, Moshaf m, int s) async {
    reciter = r;
    moshaf = m;
    surah = s;
    error = null;
    notifyListeners();
    try {
      await _audio.setUrl(m.urlFor(s));
      await _audio.play();
    } catch (e) {
      error = 'تعذّر التشغيل. تحقّق من الإنترنت.';
    }
    notifyListeners();
  }

  /// إيقاف نهائي وإخفاء شريط التشغيل.
  Future<void> stop() async {
    await _audio.stop();
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
