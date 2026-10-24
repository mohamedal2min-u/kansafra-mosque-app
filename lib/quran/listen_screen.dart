import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_data.dart';

import 'player.dart';
import 'reader_screen.dart';
import 'reciters.dart';

const kFavReciters = 'fav_reciters';
const kLastReciterId = 'last_reciter_id';
const kLastMoshaf = 'last_moshaf';

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
  int? _lastId; // آخر قارئ اختاره المستخدم (محفوظ)
  Set<int> _favs = {};
  bool _onlyFav = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _lastId = p.getInt(kLastReciterId);
          _favs = (p.getStringList(kFavReciters) ?? const []).map(int.parse).toSet();
        });
      }
    });
  }

  Future<void> _toggleFav(Reciter r) async {
    setState(() => _favs.contains(r.id) ? _favs.remove(r.id) : _favs.add(r.id));
    (await SharedPreferences.getInstance()).setStringList(kFavReciters, _favs.map((e) => '$e').toList());
  }

  Future<void> _open(Reciter r) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(kLastReciterId, r.id);
    if (!mounted) return;
    setState(() => _lastId = r.id);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReciterScreen(reciter: r)));
  }

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
            .where((r) => !_onlyFav || _favs.contains(r.id))
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
          if (_lastId != null && _query.isEmpty)
            Builder(builder: (context) {
              final last = snap.data!.where((r) => r.id == _lastId).firstOrNull;
              if (last == null) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(last.name),
                  subtitle: const Text('آخر قارئ اخترتَه'),
                  trailing: const Icon(Icons.play_circle_rounded),
                  onTap: () => _open(last),
                ),
              );
            }),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: FilterChip(
                    avatar: Icon(Icons.star_rounded, size: 18, color: Theme.of(context).colorScheme.tertiary),
                    label: const Text('المفضلة'),
                    selected: _onlyFav,
                    onSelected: (v) => setState(() => _onlyFav = v),
                  ),
                ),
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
                trailing: IconButton(
                  tooltip: 'مفضلة',
                  icon: Icon(
                    _favs.contains(list[i].id) ? Icons.star_rounded : Icons.star_border_rounded,
                    color: _favs.contains(list[i].id) ? Theme.of(context).colorScheme.tertiary : null,
                  ),
                  onPressed: () => _toggleFav(list[i]),
                ),
                onTap: () => _open(list[i]),
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
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString('$kLastMoshaf:${widget.reciter.id}');
      final m = widget.reciter.moshafs.where((e) => e.name == saved).firstOrNull;
      if (m != null && mounted) setState(() => _moshaf = m);
    });
  }

  Future<void> _saveMoshaf(Moshaf m) async =>
      (await SharedPreferences.getInstance()).setString('$kLastMoshaf:${widget.reciter.id}', m.name);

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
              onChanged: (m) { setState(() => _moshaf = m!); _saveMoshaf(m!); },
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
                  trailing: Icon(current && player.playing ? Icons.pause_circle : Icons.play_circle, size: 40),
                  selected: current,
                  onTap: () async {
                    if (!current) await player.play(widget.reciter, _moshaf, s);
                    if (!context.mounted) return;
                    // تُفتح الآيات ويُعلَّم الجاري تلاوته بالأحمر.
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: s, follow: true)),
                    );
                  },
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
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_next), onPressed: p.next),
                IconButton(
                  iconSize: 68,
                  icon: Icon(p.playing ? Icons.pause_circle : Icons.play_circle),
                  onPressed: p.toggle,
                ),
                IconButton(iconSize: 38, icon: const Icon(Icons.skip_previous), onPressed: p.previous),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
