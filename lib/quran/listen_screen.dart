import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quran_data.dart';

import 'audio_store.dart';
import 'downloader.dart';
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
          _favs = (p.getStringList(kFavReciters) ?? const [])
              .map(int.parse)
              .toSet();
        });
      }
    });
  }

  Future<void> _toggleFav(Reciter r) async {
    setState(() => _favs.contains(r.id) ? _favs.remove(r.id) : _favs.add(r.id));
    (await SharedPreferences.getInstance())
        .setStringList(kFavReciters, _favs.map((e) => '$e').toList());
  }

  Future<void> _open(Reciter r) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(kLastReciterId, r.id);
    if (!mounted) return;
    setState(() => _lastId = r.id);
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReciterScreen(reciter: r)));
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
              const Text(
                  'تعذّر تحميل قائمة القرّاء.\nالقراءة تعمل بدون إنترنت.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: FilledButton(
                    onPressed: () =>
                        setState(() => _future = ReciterApi.load()),
                    child: const Text('إعادة المحاولة'),
                  )),
            ]),
          );
        }
        final list = snap.data!
            .where((r) => !_onlyFav || _favs.contains(r.id))
            .where((r) => _tag == ReciterTag.all || r.tags.contains(_tag))
            .where((r) =>
                _query.isEmpty ||
                QuranData.normalize(r.name)
                    .contains(QuranData.normalize(_query)))
            .toList();
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'ابحث عن قارئ'),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: FilterChip(
                    avatar: Icon(Icons.star_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary),
                    label: const Text('المفضلة'),
                    selected: _onlyFav,
                    onSelected: (v) => setState(() {
                      _onlyFav = v;
                      if (v) _tag = ReciterTag.all;
                    }),
                  ),
                ),
                for (final t in ReciterTag.values)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    child: ChoiceChip(
                      label: Text(t.label),
                      selected: !_onlyFav && _tag == t,
                      onSelected: (_) => setState(() {
                        _tag = t;
                        _onlyFav = false;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _onlyFav
                            ? 'لا توجد مفضلة بعد.\nاضغط النجمة ⭐ بجانب أي قارئ لإضافته.'
                            : 'لا توجد نتائج.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(list[i].name),
                      subtitle: Text('${list[i].moshafs.length} رواية/تلاوة'),
                      trailing: IconButton(
                        tooltip: 'مفضلة',
                        icon: Icon(
                          _favs.contains(list[i].id)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: _favs.contains(list[i].id)
                              ? Theme.of(context).colorScheme.tertiary
                              : null,
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
  Set<int> _saved = {};
  int _listenSecs = 0;
  Map<String, dynamic>? _pinned; // القارئ المحمَّل على الهاتف (واحد فقط)
  int _lastDone = -1;

  @override
  void dispose() {
    QuranDownloader.instance.removeListener(_onDownload);
    super.dispose();
  }

  void _onDownload() {
    final d = QuranDownloader.instance;
    if (d.done != _lastDone || !d.running) {
      _lastDone = d.done;
      _refreshSaved();
    }
  }

  @override
  void initState() {
    super.initState();
    QuranDownloader.instance.addListener(_onDownload);
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString('$kLastMoshaf:${widget.reciter.id}');
      final m =
          widget.reciter.moshafs.where((e) => e.name == saved).firstOrNull;
      if (m != null && mounted) setState(() => _moshaf = m);
      _refreshSaved();
    });
    AudioStore.listenSeconds(widget.reciter.id).then((v) {
      if (mounted) setState(() => _listenSecs = v);
    });
  }

  Future<void> _refreshSaved() async {
    final s = await AudioStore.savedSurahs(widget.reciter, _moshaf);
    final pin = await AudioStore.pinned();
    if (mounted) {
      setState(() {
        _saved = s;
        _pinned = pin;
      });
    }
  }

  bool get _isPinnedHere =>
      _pinned != null &&
      _pinned!['id'] == widget.reciter.id &&
      _pinned!['m'] == _moshaf.name;

  static String _fmt(int b) => b < 1024 * 1024 * 1024
      ? '${(b / 1024 / 1024).round()} م.ب'
      : '${(b / 1024 / 1024 / 1024).toStringAsFixed(1)} غ.ب';

  Future<void> _startDownload() async {
    final msg = ScaffoldMessenger.of(context);
    if (!await QuranDownloader.onWifi()) {
      msg.showSnackBar(const SnackBar(
          content: Text(
              'التحميل متاح على Wi-Fi فقط. اتصل بشبكة Wi-Fi ثم أعد المحاولة.')));
      return;
    }
    if (!mounted) return;
    final replacing = _pinned != null && !_isPinnedHere;
    final size = QuranDownloader.estimateBytes(_moshaf);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحميل المصحف للاستماع بدون إنترنت'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.reciter.name}\n${_moshaf.name}'),
              const SizedBox(height: 8),
              Text('عدد السور: ${_moshaf.surahs.length}'),
              FutureBuilder<int?>(
                future: size,
                builder: (_, snap) => Text(snap.connectionState !=
                        ConnectionState.done
                    ? 'الحجم التقريبي: جارٍ الحساب...'
                    : snap.data == null
                        ? 'الحجم التقريبي: غير معروف (قد يبلغ مئات الميغابايت)'
                        : 'الحجم التقريبي: ${_fmt(snap.data!)}'),
              ),
              const SizedBox(height: 8),
              const Text(
                  '• يعمل على Wi-Fi فقط، ويتوقف إن انقطع ويمكنك المتابعة.'),
              const Text('• قارئ واحد فقط على الهاتف.'),
              if (replacing)
                Text('• سيُحذف المحمَّل سابقًا (${_pinned!['name']}).',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تحميل')),
        ],
      ),
    );
    if (ok == true) {
      QuranDownloader.instance.start(widget.reciter, _moshaf);
    }
  }

  Widget _downloadCard(BuildContext context) {
    final d = QuranDownloader.instance;
    final cs = Theme.of(context).colorScheme;
    final here =
        d.reciter?.id == widget.reciter.id && d.moshaf?.name == _moshaf.name;
    final complete =
        _saved.length >= _moshaf.surahs.length && _moshaf.surahs.isNotEmpty;
    Widget body;
    if (d.running) {
      body = here
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text('جارٍ التحميل: ${d.done} / ${d.total} سورة')),
                TextButton(onPressed: d.pause, child: const Text('إيقاف مؤقت')),
              ]),
              LinearProgressIndicator(
                  value: d.total == 0 ? null : d.done / d.total),
            ])
          : const Text('يجري تحميل مصحف قارئ آخر...');
    } else if (complete && _isPinnedHere) {
      body = Row(children: [
        Icon(Icons.download_done_rounded, color: cs.primary),
        const SizedBox(width: 8),
        const Expanded(
            child: Text('مصحف هذا القارئ محفوظ على الهاتف (يعمل بدون إنترنت)')),
        TextButton(
          onPressed: () async {
            await d.deleteAll();
            _refreshSaved();
          },
          child: const Text('حذف'),
        ),
      ]);
    } else {
      final partial = _isPinnedHere && _saved.isNotEmpty;
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d.error != null && partial)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(d.error!, style: TextStyle(color: cs.error))),
        if (_listenSecs >= kRegularListenSeconds && !partial)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child:
                Text('استمعتَ لهذا القارئ أكثر من ساعة، يمكنك تحميله كاملًا.'),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: Icon(
                partial ? Icons.play_arrow_rounded : Icons.download_rounded),
            label: Text(partial
                ? 'متابعة التحميل (${_saved.length} / ${_moshaf.surahs.length})'
                : 'تحميل مصحف هذا القارئ (Wi-Fi فقط)'),
            onPressed: partial
                ? () async {
                    if (!await QuranDownloader.onWifi()) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('التحميل متاح على Wi-Fi فقط.')));
                      }
                      return;
                    }
                    d.start(widget.reciter, _moshaf);
                  }
                : _startDownload,
          ),
        ),
      ]);
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(padding: const EdgeInsets.all(12), child: body),
    );
  }

  Future<void> _saveMoshaf(Moshaf m) async =>
      (await SharedPreferences.getInstance())
          .setString('$kLastMoshaf:${widget.reciter.id}', m.name);

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
                  DropdownMenuItem(
                      value: m,
                      child: Text(m.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (m) {
                setState(() => _moshaf = m!);
                _saveMoshaf(m!);
                _refreshSaved();
              },
            ),
          ),
        if (AudioStore.supported)
          ListenableBuilder(
              listenable: QuranDownloader.instance,
              builder: (context, _) => _downloadCard(context)),
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
                  subtitle: _saved.contains(s)
                      ? const Text('محفوظة على الهاتف (تعمل بدون إنترنت)')
                      : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_saved.contains(s))
                      Icon(Icons.download_done_rounded,
                          color: Theme.of(context).colorScheme.primary),
                    // زر التشغيل: صوت فقط بدون فتح النص.
                    IconButton(
                      iconSize: 40,
                      tooltip:
                          current && player.playing ? 'إيقاف مؤقت' : 'تشغيل',
                      icon: Icon(current && player.playing
                          ? Icons.pause_circle
                          : Icons.play_circle),
                      onPressed: () => current
                          ? player.toggle()
                          : player.play(widget.reciter, _moshaf, s),
                    ),
                  ]),
                  selected: current,
                  // الضغط على السطر: يفتح النص مع التتبّع (ويشغّل السورة إن لم تكن شغّالة).
                  onTap: () async {
                    if (!current) await player.play(widget.reciter, _moshaf, s);
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              SurahReaderScreen(surah: s, follow: true)),
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
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${QuranData.name(p.surah!)} - ${p.reciter!.name}',
                    overflow: TextOverflow.ellipsis),
                if (p.error != null)
                  Text(p.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                StreamBuilder<Duration>(
                  stream: p.position,
                  builder: (context, s) {
                    final total = p.duration?.inSeconds.toDouble() ?? 0;
                    final pos = (s.data?.inSeconds.toDouble() ?? 0)
                        .clamp(0, total > 0 ? total : 1)
                        .toDouble();
                    return Slider(
                      value: total > 0 ? pos : 0,
                      max: total > 0 ? total : 1,
                      onChanged: (v) => p.seek(Duration(seconds: v.toInt())),
                    );
                  },
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_next),
                      onPressed: p.next),
                  IconButton(
                    iconSize: 68,
                    icon: Icon(
                        p.playing ? Icons.pause_circle : Icons.play_circle),
                    onPressed: p.toggle,
                  ),
                  IconButton(
                      iconSize: 38,
                      icon: const Icon(Icons.skip_previous),
                      onPressed: p.previous),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}
