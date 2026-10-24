import 'package:flutter/material.dart';
import 'quran_data.dart';

import 'player.dart';
import 'reciters.dart';

/// الاستماع: قائمة القرّاء مع تصنيفات وبحث.
class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key});

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late Future<List<Reciter>> _future = ReciterApi.load();
  ReciterTag _tag = ReciterTag.all;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Reciter>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('الاستماع يحتاج إنترنت.\nالقراءة تعمل بدون إنترنت.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => setState(() => _future = ReciterApi.load()),
                child: const Text('إعادة المحاولة'),
              ),
            ]),
          );
        }
        final list = snap.data!
            .where((r) => _tag == ReciterTag.all || r.tags.contains(_tag))
            .where((r) => r.name.contains(_query))
            .toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن قارئ'),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in ReciterTag.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: _tag == t,
                      onSelected: (_) => setState(() => _tag = t),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(list[i].name),
                subtitle: Text('${list[i].moshafs.length} رواية/تلاوة'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ReciterScreen(reciter: list[i])),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class ReciterScreen extends StatefulWidget {
  final Reciter reciter;
  const ReciterScreen({super.key, required this.reciter});

  @override
  State<ReciterScreen> createState() => _ReciterScreenState();
}

class _ReciterScreenState extends State<ReciterScreen> {
  late Moshaf _moshaf = widget.reciter.moshafs.first;

  @override
  Widget build(BuildContext context) {
    final player = QuranPlayer.instance;
    return Scaffold(
      appBar: AppBar(title: Text(widget.reciter.name)),
      body: Column(children: [
        if (widget.reciter.moshafs.length > 1)
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<Moshaf>(
              isExpanded: true,
              initialValue: _moshaf,
              items: [
                for (final m in widget.reciter.moshafs)
                  DropdownMenuItem(value: m, child: Text(m.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (m) => setState(() => _moshaf = m!),
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: player,
            builder: (context, _) => ListView.builder(
              itemCount: _moshaf.surahs.length,
              itemBuilder: (context, i) {
                final s = _moshaf.surahs[i];
                final current = player.surah == s && player.moshaf == _moshaf;
                return ListTile(
                  leading: CircleAvatar(child: Text('$s')),
                  title: Text(QuranData.name(s)),
                  trailing: Icon(current && player.playing ? Icons.pause_circle : Icons.play_circle),
                  selected: current,
                  onTap: () => current ? player.toggle() : player.play(widget.reciter, _moshaf, s),
                );
              },
            ),
          ),
        ),
        const PlayerBar(),
      ]),
    );
  }
}

class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final p = QuranPlayer.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        if (p.surah == null) return const SizedBox.shrink();
        return Material(
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${QuranData.name(p.surah!)} - ${p.reciter!.name}',
                  overflow: TextOverflow.ellipsis),
              if (p.error != null) Text(p.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              StreamBuilder<Duration>(
                stream: p.position,
                builder: (context, s) {
                  final total = p.duration?.inSeconds.toDouble() ?? 0;
                  final pos = (s.data?.inSeconds.toDouble() ?? 0).clamp(0, total > 0 ? total : 1).toDouble();
                  return Slider(
                    value: total > 0 ? pos : 0,
                    max: total > 0 ? total : 1,
                    onChanged: (v) => p.seek(Duration(seconds: v.toInt())),
                  );
                },
              ),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.skip_next), onPressed: p.next),
                IconButton(
                  iconSize: 40,
                  icon: Icon(p.playing ? Icons.pause_circle : Icons.play_circle),
                  onPressed: p.toggle,
                ),
                IconButton(icon: const Icon(Icons.skip_previous), onPressed: p.previous),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
