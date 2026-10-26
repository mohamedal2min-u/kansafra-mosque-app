import '../quran/khatma.dart';
import '../quran/quran_data.dart';
import '../quran/reader_screen.dart';
import '../quran/reading_stats.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

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
  late DateTime _day;
  late Map<String, DateTime> _today;
  late String _nextKey;
  late DateTime _nextTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HijriCalendar.setLocal('ar');
    _compute(DateTime.now());
    _tick();
    _start();
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
    _timer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  Map<String, DateTime> _times(DateTime d) {
    final t = PrayerCalc.forDate(d);
    final raw = {
      'fajr': t.fajr,
      'sunrise': t.sunrise,
      'dhuhr': t.dhuhr,
      'asr': t.asr,
      'maghrib': t.maghrib,
      'isha': t.isha,
    };
    return {
      for (final e in raw.entries) e.key: PrayerCalc.adjusted(e.key, e.value)
    };
  }

  /// يحسب مواقيت اليوم مرة واحدة، ويُعاد الحساب عند تغيّر اليوم أو بعد مرور الصلاة القادمة فقط.
  void _compute(DateTime now) {
    _day = DateTime(now.year, now.month, now.day);
    _today = _times(now);
    String? key;
    for (final k in _order) {
      if (_today[k]!.isAfter(now)) {
        key = k;
        break;
      }
    }
    if (key == null) {
      _nextKey = 'fajr';
      _nextTime = _times(now.add(const Duration(days: 1)))['fajr']!;
    } else {
      _nextKey = key;
      _nextTime = _today[key]!;
    }
  }

  void _tick() {
    final now = DateTime.now();
    final sameDay =
        now.year == _day.year && now.month == _day.month && now.day == _day.day;
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

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.jm('ar');
    final now = DateTime.now();
    final h = HijriCalendar.fromDate(now);
    final scheme = Theme.of(context).colorScheme;

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
        _NextPrayerCard(label: _labels[_nextKey]!, countdown: _countdown),
        const _ResumeReadingCard(),
        const SizedBox(height: 6),
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
              trailing: Text(fmt.format(_today[k]!),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

/// بطاقة الصلاة القادمة: تدرّج أخضر مع زخرفة نجمية خفيفة وعدّاد ذهبي.
class _NextPrayerCard extends StatelessWidget {
  final String label;
  final ValueNotifier<String> countdown;
  const _NextPrayerCard({required this.label, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
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
