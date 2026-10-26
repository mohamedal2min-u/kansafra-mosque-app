import 'package:flutter/material.dart';

import 'player.dart';
import 'radios.dart';

/// البث المباشر: إذاعات القرآن الكريم المعروفة ثم إذاعات القرّاء والتفسير.
class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  late Future<List<RadioStation>> _future = RadioApi.load();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = QuranPlayer.instance;
    return FutureBuilder<List<RadioStation>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        final all = snap.data ?? const <RadioStation>[];
        final list = all.where((r) => r.name.contains(_query)).toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ابحث عن إذاعة أو قارئ'),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (all.length <= RadioApi.featured.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(children: [
                const Expanded(
                    child:
                        Text('تعذّر تحميل بقية الإذاعات. تحقّق من الإنترنت.')),
                TextButton(
                    onPressed: () => setState(() => _future = RadioApi.load()),
                    child: const Text('إعادة')),
              ]),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: p,
              builder: (context, _) => ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final current = p.radio?.url == r.url;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          r.featured ? cs.tertiary : cs.primaryContainer,
                      child: Icon(
                          r.featured
                              ? Icons.radio_rounded
                              : Icons.graphic_eq_rounded,
                          color: r.featured ? Colors.white : cs.primary),
                    ),
                    title: Text(r.name,
                        style: TextStyle(
                            fontWeight: r.featured ? FontWeight.w700 : null)),
                    subtitle: current
                        ? Text(p.playing ? 'يُبث الآن' : 'متوقف مؤقتًا',
                            style: TextStyle(color: cs.primary))
                        : null,
                    trailing: Icon(
                        current && p.playing
                            ? Icons.pause_circle
                            : Icons.play_circle,
                        size: 40,
                        color: cs.primary),
                    selected: current,
                    onTap: () => current ? p.toggle() : p.playRadio(r),
                  );
                },
              ),
            ),
          ),
        ]);
      },
    );
  }
}
