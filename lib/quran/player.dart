import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../launcher.dart';
import 'audio_store.dart';
import 'quran_data.dart';
import 'reciters.dart';

/// مشغّل واحد للتطبيق. السور تُشغَّل كقائمة واحدة داخل المشغّل الأصلي، فينتقل للتالية دون
/// الاعتماد على كود Dart (يعمل والهاتف في وضع السكون).
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._() {
    _audio.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && previewId != null) {
        previewId = null; // انتهت معاينة الأذان
      }
      _syncWake();
      notifyListeners();
    });
    // انتقال المشغّل الأصلي للسورة التالية: نحدّث السورة الحالية.
    _audio.currentIndexStream.listen((i) {
      final m = moshaf;
      if (!_ready ||
          i == null ||
          m == null ||
          previewId != null ||
          i >= m.surahs.length) return;
      if (m.surahs[i] != surah) {
        surah = m.surahs[i];
        error = null;
      }
      _syncWake();
      notifyListeners();
    });
    _audio.playbackEventStream.listen((_) {},
        onError: (Object e, StackTrace st) {
      if (previewId == null && surah != null) {
        error = 'تعذّر التشغيل. تحقّق من الإنترنت.';
        notifyListeners();
      }
    });
    // نقيس مدة الاستماع لكل قارئ (كل 10 ثوانٍ أثناء التشغيل).
    Timer.periodic(const Duration(seconds: 10), (_) {
      final r = reciter;
      if (r != null && _audio.playing) AudioStore.addListen(r.id, 10);
    });
  }
  static final instance = QuranPlayer._();

  // مخزن مؤقت أكبر: يستمر التشغيل حتى لو تقطّع الاتصال لدقائق (والشاشة مطفأة).
  final _audio = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(minutes: 2),
        maxBufferDuration: Duration(minutes: 4),
        bufferForPlaybackDuration: Duration(seconds: 2),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 5),
        prioritizeTimeOverSizeThresholds: true,
      ),
    ),
  );
  Reciter? reciter;
  Moshaf? moshaf;
  int? surah;
  String? error;
  String? previewId; // معاينة أذان جارية (تستعمل المشغّل نفسه)
  List<bool> _local = const []; // هل كل سورة في القائمة محفوظة على الهاتف
  bool _ready =
      false; // القائمة الجديدة حُمّلت (نتجاهل أحداث القائمة القديمة قبل ذلك)
  bool _wake = false;
  bool _wifi = false;

  bool get playing => _audio.playing;
  Stream<Duration> get position => _audio.positionStream;
  Duration? get duration => _audio.duration;
  Future<void> seek(Duration d) => _audio.seek(d);

  /// أثناء تشغيل القرآن: قفل المعالج، وقفل الواي فاي إن كانت السورة تُبثّ من الإنترنت.
  /// يُفلَت فور الإيقاف المؤقت أو الإيقاف، فلا استهلاك للبطارية دون تشغيل.
  void _syncWake() {
    if (kIsWeb) return;
    final i = _audio.currentIndex;
    final streaming = i != null && i < _local.length && !_local[i];
    // playing تبقى true بعد انتهاء القائمة، فنشترط أن المشغّل لم ينتهِ ولم يتوقف.
    final ps = _audio.processingState;
    final active =
        ps != ProcessingState.completed && ps != ProcessingState.idle;
    final on = _audio.playing && active && previewId == null && surah != null;
    final wifi = on && streaming;
    if (on == _wake && wifi == _wifi) return;
    Launcher.keepAwake(on, wifi).then((ok) {
      if (ok) {
        _wake = on;
        _wifi = wifi;
      }
    });
  }

  /// معاينة مقطع أذان على المشغّل نفسه: just_audio_background يدعم مشغّلًا واحدًا فقط في التطبيق.
  Future<void> preview(String id, String title,
      AudioSource Function(MediaItem tag) build) async {
    await stop();
    previewId = id;
    notifyListeners();
    try {
      await _audio.setAudioSource(
          build(MediaItem(id: 'preview_$id', title: title, album: 'الأذان')));
      unawaited(_audio.play()); // play() لا يعود إلا عند الإيقاف أو الانتهاء
    } catch (_) {
      previewId = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> play(Reciter r, Moshaf m, int s) async {
    previewId = null;
    _ready = false;
    reciter = r;
    moshaf = m;
    surah = s;
    error = null;
    notifyListeners();
    try {
      final saved = await AudioStore.savedPaths(r, m);
      final children = <AudioSource>[];
      final local = <bool>[];
      for (final n in m.surahs) {
        final tag = MediaItem(
            id: m.urlFor(n),
            title: 'سورة ${QuranData.name(n)}',
            artist: r.name,
            album: 'القرآن الكريم');
        final path = saved[n];
        if (path != null) {
          // محفوظة على الهاتف: تعمل بدون إنترنت.
          children.add(AudioSource.file(path, tag: tag));
          local.add(true);
        } else {
          children.add(AudioSource.uri(Uri.parse(m.urlFor(n)), tag: tag));
          local.add(false);
        }
      }
      _local = local;
      final start = m.surahs.indexOf(s);
      await _audio.setAudioSources(
        children,
        initialIndex: start < 0 ? 0 : start,
        initialPosition: Duration.zero,
      );
      _ready = true;
      unawaited(_audio.play()); // play() لا يعود إلا عند الإيقاف أو الانتهاء
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
    _local = const [];
    _ready = false;
    _syncWake();
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_audio.playing) {
      await _audio.pause();
    } else {
      unawaited(_audio.play());
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (_audio.hasNext) await _audio.seekToNext();
  }

  Future<void> previous() async {
    if (_audio.hasPrevious) await _audio.seekToPrevious();
  }
}
