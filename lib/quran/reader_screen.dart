import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'listen_screen.dart' show PlayerBar;
import 'player.dart';
import 'timings.dart';
import 'quran_data.dart';

/// قائمة السور (القراءة تعمل بدون إنترنت: النص مضمّن في التطبيق).
class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: QuranData.surahCount,
      itemBuilder: (context, i) {
        final n = i + 1;
        return ListTile(
          leading: CircleAvatar(child: Text('$n')),
          title: Text(QuranData.name(n)),
          subtitle: Text(
              '${QuranData.isMakki(n) ? 'مكية' : 'مدنية'} • ${QuranData.verseCount(n)} آية'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: n)),
          ),
        );
      },
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final int surah;
  /// وضع المتابعة: يعلّم الآية الجاري تلاوتها بالأحمر ويتتبّعها بالتمرير مع مشغّل التلاوة.
  final bool follow;
  const SurahReaderScreen({super.key, required this.surah, this.follow = false});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  static const _kFont = 'quran_font_size';
  double _size = 26;
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  int _current = -1; // فهرس الآية الحالية (من 0)
  List<int>? _cum; // الأطوال التراكمية للنص لتقدير موضع التلاوة
  List<int>? _starts; // بدايات الآيات الحقيقية (ms) إن توفّرت
  bool _timingsAsked = false;
  int _introWeight = 0; // وزن الاستعاذة/البسملة قبل الآية الأولى في التقدير

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble(_kFont);
      if (v != null && mounted) setState(() => _size = v);
    });
    if (widget.follow) {
      final n = QuranData.verseCount(widget.surah);
      // البسملة تُتلى قبل أول آية في كل سورة عدا الفاتحة (هي آيتها الأولى) والتوبة.
      _introWeight = (widget.surah == 1 || widget.surah == 9) ? 0 : 45;
      var acc = _introWeight;
      _cum = [
        // وزن كل آية = حروفها + وقفة قصيرة بين الآيات.
        for (var i = 1; i <= n; i++) acc += QuranData.verse(widget.surah, i).length + 6,
      ];
      QuranPlayer.instance.addListener(_onPlayer);
      QuranPlayer.instance.position.listen(_onPosition);
    }
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  /// الآية الحالية: بالتوقيت الحقيقي إن توفّر، وإلا بتقدير نسبة الوقت إلى طول النص.
  void _onPosition(Duration pos) {
    final p = QuranPlayer.instance;
    final dur = p.duration;
    if (!mounted || p.surah != widget.surah || dur == null || dur.inMilliseconds == 0 || _cum == null) return;
    if (!_timingsAsked && p.reciter != null) {
      _timingsAsked = true;
      VerseTimings.load(p.reciter!, widget.surah, dur).then((t) {
        if (mounted) _starts = t;
      });
    }
    final frac = (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    int idx;
    if (_starts != null) {
      idx = _starts!.lastIndexWhere((st) => st <= pos.inMilliseconds);
      if (idx < 0) idx = 0;
    } else {
      final target = frac * _cum!.last;
      if (target < _introWeight) {
        idx = 0;
      } else {
        idx = _cum!.indexWhere((c) => c >= target);
        if (idx < 0) idx = _cum!.length - 1;
      }
    }
    if (idx != _current) {
      setState(() => _current = idx);
      _reveal(idx, frac);
    }
  }

  void _reveal(int idx, double frac) {
    final ctx = _keys[idx]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 400));
    } else if (_scroll.hasClients) {
      // الآية غير مبنية بعد: اقفز لموضع تقريبي ثم ثبّتها.
      _scroll.jumpTo((frac * _scroll.position.maxScrollExtent).clamp(0.0, _scroll.position.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _keys[idx]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: 0.25);
      });
    }
  }

  @override
  void dispose() {
    if (widget.follow) QuranPlayer.instance.removeListener(_onPlayer);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _setSize(double v) async {
    setState(() => _size = v.clamp(18, 44));
    (await SharedPreferences.getInstance()).setDouble(_kFont, _size);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surah;
    final count = QuranData.verseCount(s);
    return Scaffold(
      appBar: AppBar(
        title: Text(QuranData.name(s)),
        actions: [
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => _setSize(_size - 2)),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () => _setSize(_size + 2)),
        ],
      ),
      // ListView.builder يبني الآيات الظاهرة فقط، فيبقى خفيفًا على الهواتف.
      bottomNavigationBar: widget.follow ? const PlayerBar() : null,
      body: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: count,
        itemBuilder: (context, i) {
          final v = i + 1;
          final active = widget.follow && i == _current;
          final red = Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);
          return Padding(
            key: widget.follow ? (_keys[i] ??= GlobalKey()) : null,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${QuranData.verse(s, v)} ${QuranData.endMark(v)}',
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: _size,
                height: 2,
                color: active ? red : null,
                fontWeight: active ? FontWeight.w700 : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
