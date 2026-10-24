import 'dart:async';

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

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with WidgetsBindingObserver {
  static const _order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _labels = {'sunrise': 'الشروق', ...PrayerCalc.names};

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
      'fajr': t.fajr, 'sunrise': t.sunrise, 'dhuhr': t.dhuhr,
      'asr': t.asr, 'maghrib': t.maghrib, 'isha': t.isha,
    };
    return {for (final e in raw.entries) e.key: PrayerCalc.adjusted(e.key, e.value)};
  }

  /// يحسب مواقيت اليوم مرة واحدة، ويُعاد الحساب عند تغيّر اليوم أو بعد مرور الصلاة القادمة فقط.
  void _compute(DateTime now) {
    _day = DateTime(now.year, now.month, now.day);
    _today = _times(now);
    String? key;
    for (final k in _order) {
      if (_today[k]!.isAfter(now)) { key = k; break; }
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
    final sameDay = now.year == _day.year && now.month == _day.month && now.day == _day.day;
    if (!sameDay || !_nextTime.isAfter(now)) {
      final old = _nextKey;
      _compute(now);
      if (mounted && (old != _nextKey || !sameDay)) setState(() {});
    }
    final left = _nextTime.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    _countdown.value = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
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
        Card(
          color: scheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('الصلاة القادمة: ${_labels[_nextKey]}', style: TextStyle(color: scheme.onPrimary)),
              const SizedBox(height: 4),
              ValueListenableBuilder<String>(
                valueListenable: _countdown,
                builder: (_, v, __) => Text(
                  v,
                  style: TextStyle(
                    color: scheme.onPrimary, fontSize: 36,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ]),
          ),
        ),
        for (final k in _order)
          Card(
            color: k == _nextKey ? scheme.primaryContainer : null,
            child: ListTile(
              title: Text(_labels[k]!),
              trailing: Text(fmt.format(_today[k]!), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
      ],
    );
  }
}
