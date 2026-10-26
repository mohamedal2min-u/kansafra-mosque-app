import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../launcher.dart';
import 'audio_store.dart';
import 'quran_data.dart';
import 'radios.dart';
import 'reciters.dart';

/// مشغّل واحد للتطبيق. السور تُشغَّل كقائمة واحدة داخل المشغّل الأصلي، فينتقل للتالية دون
/// الاعتماد على كود Dart (يعمل والهاتف في وضع السكون).
class QuranPlayer extends ChangeNotifier {
  QuranPlayer._();
  static final instance = QuranPlayer._();

  /// المشغّل الأصلي لا يُنشأ إلا عند أول تشغيل فعلي (لا ذاكرة ولا خدمة خلفية لمن لا يستمع).
  AudioPlayer? _a;
  static Future<void>? _bgInit;
  Timer? _listenTimer;

  AudioPlayer get _audio => _a!;

  /// تهيئة خدمة التشغيل في الخلفية (إشعار التحكم). تبدأ من main دون انتظار، وتُنتظر قبل أول مشغّل.
  static Future<void> initBackground() => _bgInit ??= () async {
        if (kIsWeb ||
            (defaultTargetPlatform != TargetPlatform.android &&
                defaultTargetPlatform != TargetPlatform.iOS)) {
          return;
        }
        await JustAudioBackground.init(
          androidNotificationChannelId: 'org.kansafra.kansafra_mosque.audio',
          androidNotificationChannelName: 'تشغيل القرآن',
          androidNotificationOngoing: true,
        );
      }();

  Future<AudioPlayer>? _creating;

  /// يُنشئ المشغّل مرة واحدة حتى لو طُلب مرتين في اللحظة نفسها.
  Future<AudioPlayer> _ensure() => _creating ??= _create();

  Future<AudioPlayer> _create() async {
    await initBackground();
    final a = _a = AudioPlayer(
      // مخزن مؤقت أكبر: يستمر التشغيل حتى لو تقطّع الاتصال لدقائق (والشاشة مطفأة).
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
    a.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && previewId != null) {
        previewId = null; // انتهت معاينة الأذان
      }
      _syncWake();
      _syncListenTimer();
      notifyListeners();
    });
    // انتقال المشغّل الأصلي للسورة التالية: نحدّث السورة الحالية.
    a.currentIndexStream.listen((i) {
      final m = moshaf;
      if (!_ready ||
          i == null ||
          m == null ||
          previewId != null ||
          i >= m.surahs.length) {
        return;
      }
      if (m.surahs[i] != surah) {
        surah = m.surahs[i];
        error = null;
      }
      _syncWake();
      notifyListeners();
    });
    a.playbackEventStream.listen((_) {
      if (error != null && a.playing) {
        error = null; // عاد التشغيل بعد انقطاع
        notifyListeners();
      }
    }, onError: (Object e, StackTrace st) {
      if (previewId == null && (surah != null || radio != null)) {
        error = 'تعذّر التشغيل. تحقّق من الإنترنت.';
        notifyListeners();
      }
    });
    return a;
  }

  /// نقيس مدة الاستماع لكل قارئ بمؤقّت يعمل أثناء التشغيل فقط.
  void _syncListenTimer() {
    final on = (_a?.playing ?? false) && previewId == null && reciter != null;
    if (on && _listenTimer == null) {
      _listenTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final r = reciter;
        if (r != null && (_a?.playing ?? false)) AudioStore.addListen(r.id, 10);
      });
    } else if (!on) {
      _listenTimer?.cancel();
      _listenTimer = null;
    }
  }

  Reciter? reciter;
  Moshaf? moshaf;
  int? surah;
  String? error;
  String? previewId; // معاينة أذان جارية (تستعمل المشغّل نفسه)
  RadioStation? radio; // إذاعة مباشرة جارية
  List<bool> _local = const []; // هل كل سورة في القائمة محفوظة على الهاتف
  bool _ready =
      false; // القائمة الجديدة حُمّلت (نتجاهل أحداث القائمة القديمة قبل ذلك)
  bool _wake = false;
  bool _wifi = false;

  bool get playing => _a?.playing ?? false;
  Stream<Duration> get position => _a?.positionStream ?? const Stream.empty();
  Duration? get duration => _a?.duration;
  Future<void> seek(Duration d) async => _a?.seek(d);

  /// أثناء تشغيل القرآن: قفل المعالج، وقفل الواي فاي إن كانت السورة تُبثّ من الإنترنت.
  /// يُفلَت فور الإيقاف المؤقت أو الإيقاف، فلا استهلاك للبطارية دون تشغيل.
  void _syncWake() {
    if (kIsWeb || _a == null) return;
    final i = _audio.currentIndex;
    final streaming =
        radio != null || (i != null && i < _local.length && !_local[i]);
    // playing تبقى true بعد انتهاء القائمة، فنشترط أن المشغّل لم ينتهِ ولم يتوقف.
    final ps = _audio.processingState;
    final active =
        ps != ProcessingState.completed && ps != ProcessingState.idle;
    final on = _audio.playing &&
        active &&
        previewId == null &&
        (surah != null || radio != null);
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
    await _ensure();
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
    radio = null;
    _ready = false;
    reciter = r;
    moshaf = m;
    surah = s;
    error = null;
    notifyListeners();
    try {
      await _ensure();
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
  /// تشغيل إذاعة مباشرة (بث مستمر، بلا سور ولا تقديم أو تأخير).
  Future<void> playRadio(RadioStation r) async {
    await stop();
    await _ensure();
    radio = r;
    notifyListeners();
    try {
      await _audio.setAudioSource(AudioSource.uri(Uri.parse(r.url),
          tag: MediaItem(
              id: 'radio_${r.id}', title: r.name, album: 'بث مباشر')));
      unawaited(_audio.play());
    } catch (_) {
      error = 'تعذّر تشغيل البث. تحقّق من الإنترنت.';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _a?.stop();
    previewId = null;
    radio = null;
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
    if (_a == null) return;
    if (_audio.playing) {
      await _audio.pause();
    } else {
      unawaited(_audio.play());
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (_a?.hasNext ?? false) await _audio.seekToNext();
  }

  Future<void> previous() async {
    if (_a?.hasPrevious ?? false) await _audio.seekToPrevious();
  }
}
