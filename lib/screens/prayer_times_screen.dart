import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/prayer_calc.dart';

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  PrayerTimes _times() => PrayerCalc.forDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final t = _times();
    final fmt = DateFormat.jm('ar');
    final rows = <(String, String, DateTime)>[
      ('الفجر', 'fajr', t.fajr),
      ('الشروق', 'sunrise', t.sunrise),
      ('الظهر', 'dhuhr', t.dhuhr),
      ('العصر', 'asr', t.asr),
      ('المغرب', 'maghrib', t.maghrib),
      ('العشاء', 'isha', t.isha),
    ];
    final next = t.nextPrayer();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Image.asset('assets/logo/icon.png', height: 84)),
        const SizedBox(height: 8),
        Text(
          DateFormat.yMMMMEEEEd('ar').format(DateTime.now()),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          Card(
            color: r.$2 == next.name ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              title: Text(r.$1),
              trailing: Text(
                fmt.format(PrayerCalc.adjusted(r.$2, r.$3)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
