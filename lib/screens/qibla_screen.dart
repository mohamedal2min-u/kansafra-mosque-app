import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../config.dart';
import '../services/qibla.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bearing = qiblaBearing(MosqueConfig.latitude, MosqueConfig.longitude);
    final hasCompass = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('اتجاه القبلة من المسجد: ${bearing.toStringAsFixed(1)}° عن الشمال',
              style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (hasCompass)
            StreamBuilder<CompassEvent>(
              stream: FlutterCompass.events,
              builder: (context, snap) {
                final heading = snap.data?.heading;
                if (heading == null) {
                  return const Text('لا يوجد حساس بوصلة في هذا الجهاز أو لم يبدأ بعد.');
                }
                return _Dial(angle: (bearing - heading) * pi / 180);
              },
            )
          else
            const Text('البوصلة الحية تعمل على الهاتف فقط.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          const Text('أبعد الهاتف عن المعادن والمغناطيس، وحرّكه على شكل ٨ لمعايرة البوصلة.',
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Dial extends StatelessWidget {
  final double angle;
  const _Dial({required this.angle});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 3)),
        ),
        Transform.rotate(angle: angle, child: Icon(Icons.navigation, size: 150, color: color)),
        const Positioned(top: 8, child: Icon(Icons.mosque, size: 28)),
      ]),
    );
  }
}
