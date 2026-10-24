import 'package:flutter/material.dart';

import 'player.dart';
import 'quran_data.dart';

/// شريط تشغيل القرآن الدائم أعلى التطبيق: إيقاف مؤقت وإيقاف نهائي والتنقل بين السور.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = QuranPlayer.instance;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        if (p.surah == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Row(children: [
                IconButton(
                  tooltip: 'إيقاف',
                  icon: Icon(Icons.stop_circle_rounded, color: scheme.onPrimary, size: 40),
                  onPressed: p.stop,
                ),
                IconButton(
                  tooltip: p.playing ? 'إيقاف مؤقت' : 'تشغيل',
                  icon: Icon(p.playing ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                      color: scheme.onPrimary, size: 54),
                  onPressed: p.toggle,
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سورة ${QuranData.name(p.surah!)}',
                        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700)),
                    Text(p.error ?? p.reciter?.name ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
                  ]),
                ),
                IconButton(
                  tooltip: 'السابقة',
                  icon: Icon(Icons.skip_previous_rounded, color: scheme.onPrimary, size: 34),
                  onPressed: p.previous,
                ),
                IconButton(
                  tooltip: 'التالية',
                  icon: Icon(Icons.skip_next_rounded, color: scheme.onPrimary, size: 34),
                  onPressed: p.next,
                ),
              ]),
            ),
            StreamBuilder<Duration>(
              stream: p.position,
              builder: (context, s) {
                final total = p.duration?.inMilliseconds ?? 0;
                final pos = s.data?.inMilliseconds ?? 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? (pos / total).clamp(0.0, 1.0) : null,
                      minHeight: 5,
                      backgroundColor: scheme.onPrimary.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation(scheme.tertiary),
                    ),
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }
}
