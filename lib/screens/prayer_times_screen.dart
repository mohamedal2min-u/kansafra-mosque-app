import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';

class PrayerTimesScreen extends StatelessWidget {
  const PrayerTimesScreen({super.key});

  PrayerTimes _times() {
    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;
    final coords = Coordinates(MosqueConfig.latitude, MosqueConfig.longitude);
    return PrayerTimes.today(coords, params);
  }

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
                fmt.format(r.$3.add(Duration(minutes: MosqueConfig.minuteAdjustments[r.$2] ?? 0))),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
      ],
    );
  }
}
