import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'khatma.dart';
import 'listen_screen.dart' show PlayerBar;
import 'player.dart';
import 'timings.dart';
import 'quran_data.dart';

/// قائمة السور (القراءة تعمل بدون إنترنت: النص مضمّن في التطبيق).
class SurahListScreen extends StatefulWidget {
  const SurahListScreen({super.key});

  @override
  State<SurahListScreen> createState() => _SurahListScreenState();
}

class _SurahListScreenState extends State<SurahListScreen> {
  @override
  void initState() {
    super.initState();
    Khatma.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: Khatma.instance.time);
    if (t != null) {
      await Khatma.instance.setReminder(at: t);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      itemCount: QuranData.surahCount + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return ValueListenableBuilder<Bookmark?>(
            valueListenable: Khatma.instance.mark,
            builder: (context, m, _) => Card(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.bookmark_rounded, color: cs.tertiary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              m == null ? 'ختمتي' : 'وصلتَ إلى: ${m.label}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      if (m == null)
                        const Text(
                            'أثناء القراءة اضغط على أي آية ثم «وصلتُ إلى هنا» لتضع علامة، وتكمل منها غدًا.')
                      else ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.menu_book_rounded),
                            label: const Text('أكمل القراءة'),
                            onPressed: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SurahReaderScreen(
                                  surah: m.surah, initialVerse: m.verse),
                            )),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('تذكير يومي بإكمال الورد'),
                          subtitle: Text(
                              'الساعة ${Khatma.instance.time.format(context)}، ولا يُرسَل في يوم قرأتَ فيه'),
                          value: Khatma.instance.remind,
                          onChanged: (v) async {
                            await Khatma.instance.setReminder(on: v);
                            if (mounted) setState(() {});
                          },
                        ),
                        if (Khatma.instance.remind)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              icon: const Icon(Icons.schedule_rounded),
                              label: const Text('تغيير وقت التذكير'),
                              onPressed: _pickTime,
                            ),
                          ),
                      ],
                    ]),
              ),
            ),
          );
        }
        final n = i;
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

  /// آية يُفتح عندها النص (للمتابعة من العلامة).
  final int? initialVerse;
  const SurahReaderScreen(
      {super.key, required this.surah, this.follow = false, this.initialVerse});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  static const _kFont = 'quran_font_size';
  static const _kFamily = 'quran_font_family';
  double _size = 26;
  // خط النسخ الواضح للقرآن افتراضيًا، أو خط التطبيق (Tajawal) بالتبديل من شريط العنوان.
  String _family = 'NotoNaskh';
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};
  StreamSubscription<Duration>? _posSub;
  late int _s = widget.surah; // السورة المعروضة (تتبع المشغّل في وضع المتابعة)
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
      final f = p.getString(_kFamily);
      if (mounted && (v != null || f != null)) {
        setState(() {
          if (v != null) _size = v;
          if (f != null) _family = f;
        });
      }
    });
    Khatma.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    final iv = widget.initialVerse;
    if (iv != null) {
      // الانتقال إلى آية العلامة بعد أول رسم.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final n = QuranData.verseCount(_s);
        _reveal(iv - 1, (iv - 1) / n);
      });
    }
    if (widget.follow) {
      _initWeights();
      QuranPlayer.instance.addListener(_onPlayer);
      _posSub = QuranPlayer.instance.position.listen(_onPosition);
    }
  }

  void _initWeights() {
    final n = QuranData.verseCount(_s);
    // البسملة تُتلى قبل أول آية في كل سورة عدا الفاتحة (هي آيتها الأولى) والتوبة.
    _introWeight = (_s == 1 || _s == 9) ? 0 : 45;
    var acc = _introWeight;
    _cum = [
      // وزن كل آية = حروفها + وقفة قصيرة بين الآيات.
      for (var i = 1; i <= n; i++) acc += QuranData.verse(_s, i).length + 6,
    ];
  }

  void _onPlayer() {
    if (!mounted) return;
    final cur = QuranPlayer.instance.surah;
    if (cur != null && cur != _s) {
      // انتقل المشغّل لسورة أخرى: نعرض نصّها ونتابعها.
      setState(() {
        _s = cur;
        _current = -1;
        _starts = null;
        _timingsAsked = false;
        _keys.clear();
        _initWeights();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else {
      setState(() {});
    }
  }

  /// الآية الحالية: بالتوقيت الحقيقي إن توفّر، وإلا بتقدير نسبة الوقت إلى طول النص.
  void _onPosition(Duration pos) {
    final p = QuranPlayer.instance;
    final dur = p.duration;
    if (!mounted ||
        p.surah != _s ||
        dur == null ||
        dur.inMilliseconds == 0 ||
        _cum == null) return;
    if (!_timingsAsked && p.reciter != null) {
      _timingsAsked = true;
      final asked = _s;
      VerseTimings.load(p.reciter!, asked, dur).then((t) {
        if (mounted && _s == asked)
          _starts = t; // تجاهل النتيجة إن انتقلنا لسورة أخرى
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
      Scrollable.ensureVisible(ctx,
          alignment: 0.25, duration: const Duration(milliseconds: 400));
    } else if (_scroll.hasClients) {
      // الآية غير مبنية بعد: اقفز لموضع تقريبي ثم ثبّتها.
      _scroll.jumpTo((frac * _scroll.position.maxScrollExtent)
          .clamp(0.0, _scroll.position.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _keys[idx]?.currentContext;
        if (c != null) Scrollable.ensureVisible(c, alignment: 0.25);
      });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    if (widget.follow) QuranPlayer.instance.removeListener(_onPlayer);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _toggleFamily() async {
    setState(() => _family = _family == 'NotoNaskh' ? 'Tajawal' : 'NotoNaskh');
    (await SharedPreferences.getInstance()).setString(_kFamily, _family);
  }

  void _verseMenu(int v) {
    final cur = Khatma.instance.mark.value;
    final here = cur != null && cur.surah == _s && cur.verse == v;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(Icons.bookmark_add_rounded,
                color: Theme.of(ctx).colorScheme.tertiary),
            title: Text(here ? 'العلامة هنا الآن' : 'وصلتُ إلى هنا (ضع علامة)'),
            subtitle: Text('سورة ${QuranData.name(_s)}، آية $v'),
            onTap: () async {
              Navigator.pop(ctx);
              await Khatma.instance.setMark(_s, v);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'حُفظت العلامة. تكمل منها لاحقًا من تبويب «قراءة»، وسنذكّرك يوميًا.'),
                ));
              }
            },
          ),
          if (cur != null)
            ListTile(
              leading: const Icon(Icons.bookmark_remove_outlined),
              title: const Text('إزالة العلامة'),
              onTap: () async {
                Navigator.pop(ctx);
                await Khatma.instance.clearMark();
              },
            ),
        ]),
      ),
    );
  }

  void _goToMark() {
    final m = Khatma.instance.mark.value;
    if (m == null) return;
    if (m.surah == _s) {
      _reveal(m.verse - 1, (m.verse - 1) / QuranData.verseCount(_s));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) =>
            SurahReaderScreen(surah: m.surah, initialVerse: m.verse),
      ));
    }
  }

  Future<void> _setSize(double v) async {
    setState(() => _size = v.clamp(18, 44));
    (await SharedPreferences.getInstance()).setDouble(_kFont, _size);
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    final count = QuranData.verseCount(s);
    return Scaffold(
      appBar: AppBar(
        title: Text(QuranData.name(s)),
        actions: [
          ValueListenableBuilder<Bookmark?>(
            valueListenable: Khatma.instance.mark,
            builder: (_, m, __) => m == null
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'الذهاب إلى العلامة',
                    icon: Icon(Icons.bookmark_rounded,
                        color: Theme.of(context).colorScheme.tertiary),
                    onPressed: _goToMark,
                  ),
          ),
          IconButton(
              tooltip: 'نوع الخط',
              icon: const Icon(Icons.font_download_outlined),
              onPressed: _toggleFamily),
          IconButton(
              icon: const Icon(Icons.text_decrease),
              onPressed: () => _setSize(_size - 2)),
          IconButton(
              icon: const Icon(Icons.text_increase),
              onPressed: () => _setSize(_size + 2)),
        ],
      ),
      // ListView.builder يبني الآيات الظاهرة فقط، فيبقى خفيفًا على الهواتف.
      bottomNavigationBar: widget.follow ? const PlayerBar() : null,
      body: ValueListenableBuilder<Bookmark?>(
        valueListenable: Khatma.instance.mark,
        builder: (context, _, __) => ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: count,
          itemBuilder: (context, i) {
            final v = i + 1;
            final active = widget.follow && i == _current;
            final red = Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFFF6B6B)
                : const Color(0xFFD32F2F);
            final mk = Khatma.instance.mark.value;
            final marked = mk != null && mk.surah == s && mk.verse == v;
            final gold = Theme.of(context).colorScheme.tertiary;
            return Padding(
              key: _keys[i] ??= GlobalKey(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _verseMenu(v),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: marked
                      ? BoxDecoration(
                          color: gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10))
                      : null,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (marked)
                          Padding(
                            padding: const EdgeInsets.only(top: 14, left: 6),
                            child: Icon(Icons.bookmark_rounded, color: gold),
                          ),
                        Expanded(
                          child: Text(
                            '${QuranData.verse(s, v)} ${QuranData.endMark(v)}',
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontFamily: _family,
                              fontSize: _size,
                              height: _family == 'NotoNaskh' ? 1.9 : 2,
                              color: active ? red : null,
                              fontWeight: active ? FontWeight.w700 : null,
                            ),
                          ),
                        ),
                      ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
