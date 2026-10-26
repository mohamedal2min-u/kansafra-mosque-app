import '../quran/khatma.dart';
import '../quran/quran_data.dart';
import '../quran/reader_screen.dart';
import '../quran/reading_stats.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../services/adhan_service.dart';
import '../services/home_place.dart';
import '../services/prayer_calc.dart';
import '../widgets/hero_banner.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  static const _order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _labels = {'sunrise': 'الشروق', ...PrayerCalc.names};
  static const _icons = {
    'fajr': Icons.nightlight_round,
    'sunrise': Icons.wb_twilight_rounded,
    'dhuhr': Icons.wb_sunny_rounded,
    'asr': Icons.sunny,
    'maghrib': Icons.nights_stay_rounded,
    'isha': Icons.bedtime_rounded,
  };

  Timer? _timer;
  // العدّاد يتحدّث بدون إعادة بناء الشاشة كلها، فيبقى الاستهلاك قليلًا.
  final _countdown = ValueNotifier<String>('');
  late String _dayKey;
  late Map<String, DateTime> _today; // كنصفرة
  Map<String, DateTime>? _homeToday; // مكان السكن (إن حُدّد)
  late String _nextKey;
  late DateTime _nextTime;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HijriCalendar.setLocal('ar');
    HomePlace.site.addListener(_placeChanged);
    _compute(DateTime.now());
    _tick();
    _start();
    if (HomePlace.site.value == null && HomePlace.looksAbroad) {
      HomePlace.hintDismissed().then((d) {
        if (mounted && !d) setState(() => _showHint = true);
      });
    }
  }

  void _placeChanged() {
    _compute(DateTime.now());
    _tick();
    if (mounted) setState(() => _showHint = false);
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // لا مؤقت والتطبيق في الخلفية.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomePlace.site.removeListener(_placeChanged);
    _timer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// يحسب مواقيت اليوم مرة واحدة، ويُعاد الحساب عند تغيّر اليوم أو بعد مرور الصلاة القادمة فقط.
  /// كل الأوقات لحظات حقيقية؛ العرض بتوقيت كل مكان عبر wall. الصلاة القادمة والعدّاد
  /// لمكان الأذان: مكان السكن إن حُدّد، وإلا كنصفرة.
  void _compute(DateTime now) {
    final home = HomePlace.site.value;
    _dayKey = _key(now);
    _today = PrayerCalc.day(PrayerCalc.wall(now));
    _homeToday = home?.day(home.now());
    final (k, t) = HomePlace.active.next(now) ?? PrayerCalc.next(now);
    _nextKey = k;
    _nextTime = t;
  }

  String _key(DateTime now) =>
      '${_ymd(PrayerCalc.wall(now))}|${_ymd(HomePlace.site.value?.wall(now) ?? now)}';

  void _tick() {
    final now = DateTime.now();
    final sameDay = _key(now) == _dayKey;
    if (!sameDay || !_nextTime.isAfter(now)) {
      final old = _nextKey;
      _compute(now);
      if (mounted && (old != _nextKey || !sameDay)) setState(() {});
    }
    final left = _nextTime.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    _countdown.value =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  Future<void> _locate() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('جارٍ تحديد موقعك…'), duration: Duration(seconds: 3)));
    final err = await HomePlace.locate();
    messenger.hideCurrentSnackBar();
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    try {
      await AdhanService.instance.scheduleAll(force: true);
    } catch (_) {}
    messenger.showSnackBar(SnackBar(
        content: Text('صار الأذان على توقيت ${HomePlace.site.value!.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.jm('ar');
    final home = HomePlace.site.value;
    // التاريخ بتوقيت مكان السكن إن حُدّد، وإلا بتوقيت المسجد.
    final now = home?.now() ?? PrayerCalc.mosqueNow();
    final h = HijriCalendar.fromDate(now);
    final scheme = Theme.of(context).colorScheme;
    final homeTimes = _homeToday;
    final timeStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    final mosqueStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600);
    Widget col(String text, TextStyle? style) => SizedBox(
        width: 76,
        child: Text(text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const HeroBanner(),
        const SizedBox(height: 12),
        Text(
          '${DateFormat.yMMMMEEEEd('ar').format(now)}\n${h.hDay} ${h.longMonthName} ${h.hYear} هـ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _NextPrayerCard(
            label: _labels[_nextKey]!,
            place: home == null ? null : 'بتوقيت ${home.name}',
            countdown: _countdown),
        if (_showHint)
          _AbroadHint(
              onLocate: _locate,
              onDismiss: () {
                HomePlace.dismissHint();
                setState(() => _showHint = false);
              }),
        const _ResumeReadingCard(),
        const SizedBox(height: 6),
        if (homeTimes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              col(
                  home!.name,
                  Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
              col('كنصفرة', Theme.of(context).textTheme.labelMedium),
            ]),
          ),
        for (final k in _order)
          Card(
            color: k == _nextKey ? scheme.primaryContainer : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: k == _nextKey
                    ? scheme.tertiary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: k == _nextKey ? 1.6 : 1,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor:
                    k == _nextKey ? scheme.tertiary : scheme.primaryContainer,
                child: Icon(_icons[k],
                    color: k == _nextKey ? Colors.white : scheme.primary,
                    size: 22),
              ),
              title: Text(_labels[k]!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              subtitle: k == _nextKey ? const Text('الصلاة القادمة') : null,
              trailing: homeTimes == null
                  ? Text(fmt.format(PrayerCalc.wall(_today[k]!)),
                      style: timeStyle)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      col(fmt.format(home!.wall(homeTimes[k]!)), timeStyle),
                      col(fmt.format(PrayerCalc.wall(_today[k]!)), mosqueStyle),
                    ]),
            ),
          ),
      ],
    );
  }
}

/// بطاقة الصلاة القادمة: تدرّج أخضر مع زخرفة نجمية خفيفة وعدّاد ذهبي.
class _NextPrayerCard extends StatelessWidget {
  final String label;
  final String? place; // «بتوقيت ستوكهولم» حين يكون الأذان على مكان السكن
  final ValueNotifier<String> countdown;
  const _NextPrayerCard(
      {required this.label, this.place, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1C6B45), Color(0xFF0A3B25)],
          ),
        ),
        child: CustomPaint(
          painter: _StarPatternPainter(),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Text('الصلاة القادمة',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              if (place != null)
                Text(place!,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13)),
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: countdown,
                builder: (_, v, __) => Text(
                  v,
                  style: const TextStyle(
                    color: Color(0xFFF1D58A),
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 46.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final c = Offset(x, y);
        // نجمة ثمانية من مربعين متداخلين
        for (var k = 0; k < 2; k++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = math.pi / 4 * (k * 1) + math.pi / 2 * i;
            final p = c + Offset(math.cos(a), math.sin(a)) * 16;
            i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// اقتراح لمن هاتفه على غير توقيت سوريا: أذان على توقيت مكان سكنه، ومواقيت كنصفرة بجانبه.
class _AbroadHint extends StatelessWidget {
  final VoidCallback onLocate;
  final VoidCallback onDismiss;
  const _AbroadHint({required this.onLocate, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.tertiary),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.public_rounded, color: cs.tertiary),
            const SizedBox(width: 8),
            Text('تسكن خارج سوريا؟',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          const Text(
              'اجعل الأذان على توقيت مكان سكنك (أم القرى)، وتبقى مواقيت كنصفرة ظاهرة بجانبه.'),
          Row(children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              onPressed: onLocate,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: const Text('تحديد موقعي'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onDismiss, child: const Text('لا، شكرًا')),
          ]),
        ]),
      ),
    );
  }
}

/// متابعة القراءة: تظهر في الرئيسية إن وضع المستخدم علامة في المصحف، وتفتح من آخر آية وصل إليها.
class _ResumeReadingCard extends StatefulWidget {
  const _ResumeReadingCard();

  @override
  State<_ResumeReadingCard> createState() => _ResumeReadingCardState();
}

class _ResumeReadingCardState extends State<_ResumeReadingCard> {
  @override
  void initState() {
    super.initState();
    Future.wait([Khatma.instance.load(), ReadingStats.instance.load()])
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _open(Bookmark m) async {
    await QuranData.load(); // النص مضمّن، ويُحمَّل مرة واحدة
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurahReaderScreen(surah: m.surah, initialVerse: m.verse),
    ));
    if (mounted) setState(() {}); // تحديث وقت اليوم بعد العودة
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Bookmark?>(
      valueListenable: Khatma.instance.mark,
      builder: (context, m, _) {
        if (m == null) return const SizedBox.shrink();
        final today = ReadingStats.instance.today;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _open(m),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.tertiary,
                    child:
                        const Icon(Icons.bookmark_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تابع قراءتك',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onPrimaryContainer)),
                          const SizedBox(height: 2),
                          Text(m.label,
                              style: TextStyle(color: cs.onPrimaryContainer)),
                          if (today >= 60)
                            Text('قرأتَ اليوم ${ReadingStats.format(today)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: cs.onPrimaryContainer
                                            .withValues(alpha: 0.8))),
                        ]),
                  ),
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: cs.onPrimaryContainer),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
