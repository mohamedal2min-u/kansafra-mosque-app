import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../services/prayer_calc.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  static const _order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _labels = {'sunrise': 'الشروق', ...PrayerCalc.names};

  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    HijriCalendar.setLocal('ar');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Map<String, DateTime> _day(DateTime d) {
    final t = PrayerCalc.forDate(d);
    final raw = {
      'fajr': t.fajr, 'sunrise': t.sunrise, 'dhuhr': t.dhuhr,
      'asr': t.asr, 'maghrib': t.maghrib, 'isha': t.isha,
    };
    return {for (final e in raw.entries) e.key: PrayerCalc.adjusted(e.key, e.value)};
  }

  @override
  Widget build(BuildContext context) {
    final today = _day(_now);
    String? nextKey;
    DateTime? nextTime;
    for (final k in _order) {
      if (today[k]!.isAfter(_now)) { nextKey = k; nextTime = today[k]; break; }
    }
    if (nextKey == null) {
      nextKey = 'fajr';
      nextTime = _day(_now.add(const Duration(days: 1)))['fajr'];
    }
    final left = nextTime!.difference(_now);
    String two(int n) => n.toString().padLeft(2, '0');
    final countdown = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final fmt = DateFormat.jm('ar');
    final h = HijriCalendar.fromDate(_now);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Image.asset('assets/logo/icon.png', height: 84)),
        const SizedBox(height: 8),
        Text(
          '${DateFormat.yMMMMEEEEd('ar').format(_now)}\n${h.hDay} ${h.longMonthName} ${h.hYear} هـ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Card(
          color: scheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('الصلاة القادمة: ${_labels[nextKey]}', style: TextStyle(color: scheme.onPrimary)),
              const SizedBox(height: 4),
              Text(countdown,
                  style: TextStyle(
                    color: scheme.onPrimary, fontSize: 36,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ]),
          ),
        ),
        for (final k in _order)
          Card(
            color: k == nextKey ? scheme.primaryContainer : null,
            child: ListTile(
              title: Text(_labels[k]!),
              trailing: Text(fmt.format(today[k]!), style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
      ],
    );
  }
}
