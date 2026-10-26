import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:just_audio/just_audio.dart';
import '../adhan/adhan_catalog.dart';
import '../quran/player.dart';
import '../settings.dart';

/// مؤذنون أونلاين: استمع من الإنترنت، وعند الاختيار يُحمَّل المقطع على الهاتف ويُعتمد للأذان.
class AdhanCatalogScreen extends StatefulWidget {
  final CustomAdhan? current;
  final Future<void> Function(CustomAdhan) onPicked;
  const AdhanCatalogScreen(
      {super.key, required this.current, required this.onPicked});

  @override
  State<AdhanCatalogScreen> createState() => _AdhanCatalogScreenState();
}

class _AdhanCatalogScreenState extends State<AdhanCatalogScreen> {
  late Future<List<OnlineAdhan>> _future = AdhanCatalog.load();
  Set<String> _downloaded = {};
  String _query = '';
  bool _onlyFajr = false;
  String? _busyId;
  String? _currentId;

  @override
  void initState() {
    super.initState();
    _currentId = widget.current?.id;
    AdhanCatalog.downloaded().then((s) {
      if (mounted) setState(() => _downloaded = s);
    });
  }

  @override
  void dispose() {
    if (QuranPlayer.instance.previewId != null) QuranPlayer.instance.stop();
    super.dispose();
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _preview(OnlineAdhan v) async {
    final p = QuranPlayer.instance;
    if (p.previewId == v.id) {
      await p.stop();
      return;
    }
    try {
      final f = await AdhanCatalog.file(v);
      final local = _downloaded.contains(v.id) && await f.exists();
      await p.preview(
          v.id,
          v.name,
          (tag) => local
              ? AudioSource.file(f.path, tag: tag)
              : AudioSource.uri(Uri.parse(v.url), tag: tag));
    } catch (e) {
      if (mounted) _msg('تعذّر تشغيل الصوت: ${'$e'.split('\n').first}');
    }
  }

  Future<void> _choose(OnlineAdhan v) async {
    if (!AdhanCatalog.supported) {
      _msg('الاختيار يعمل على أندرويد فقط.');
      return;
    }
    setState(() => _busyId = v.id);
    CustomAdhan c;
    try {
      c = await AdhanCatalog.downloadAndRegister(v);
    } on PlatformException catch (e) {
      if (mounted) {
        _msg('تعذّر تسجيل الصوت في النظام: ${e.message ?? e.code}');
        setState(() => _busyId = null);
      }
      return;
    } catch (e) {
      if (mounted) {
        _msg('تعذّر التحميل: ${'$e'.split('\n').first}');
        setState(() => _busyId = null);
      }
      return;
    }
    try {
      await widget.onPicked(c); // يحفظ الاختيار ويعيد جدولة الأذان
      if (!mounted) return;
      setState(() {
        _downloaded.add(v.id);
        _currentId = v.id;
      });
      _msg('تم تحميل واعتماد: ${v.name}');
    } catch (e) {
      if (mounted) _msg('تعذّرت جدولة الأذان: ${'$e'.split('\n').first}');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _remove(OnlineAdhan v) async {
    await AdhanCatalog.delete(v);
    if (mounted) setState(() => _downloaded.remove(v.id));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مؤذنون من الإنترنت')),
      body: FutureBuilder<List<OnlineAdhan>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'تعذّر تحميل قائمة المؤذنين.\nتأكد من الاتصال بالإنترنت.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: FilledButton(
                      onPressed: () =>
                          setState(() => _future = AdhanCatalog.load()),
                      child: const Text('إعادة المحاولة')),
                ),
              ]),
            );
          }
          final list = snap.data!
              .where((v) => !_onlyFajr || v.fajr)
              .where((v) => v.name.contains(_query))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search), hintText: 'ابحث عن مؤذن'),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                FilterChip(
                    label: const Text('أذان الفجر'),
                    selected: _onlyFajr,
                    onSelected: (v) => setState(() => _onlyFajr = v)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'عند اختيار مؤذن يُحمَّل على هاتفك (نحو 250 ك.ب) ويعمل بعدها بدون إنترنت.',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(AdhanCatalog.disabled
                          ? 'قائمة المؤذنين متوقفة مؤقتًا.'
                          : 'لا توجد نتائج.'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final v = list[i];
                        final has = _downloaded.contains(v.id);
                        final isCurrent = _currentId == v.id;
                        final busy = _busyId == v.id;
                        final sub = isCurrent
                            ? 'المعتمد الآن'
                            : has
                                ? 'محمَّل على الهاتف'
                                : v.fajr
                                    ? 'أذان الفجر'
                                    : '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          child: Row(children: [
                            ListenableBuilder(
                              listenable: QuranPlayer.instance,
                              builder: (_, __) => IconButton(
                                iconSize: 34,
                                tooltip: 'استماع',
                                icon: Icon(
                                    QuranPlayer.instance.previewId == v.id
                                        ? Icons.stop_circle
                                        : Icons.play_circle),
                                onPressed: () => _preview(v),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge),
                                    if (sub.isNotEmpty)
                                      Text(sub,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: isCurrent
                                                      ? cs.primary
                                                      : null)),
                                  ]),
                            ),
                            if (busy)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5)),
                              )
                            else if (isCurrent)
                              Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(Icons.check_circle_rounded,
                                      color: cs.primary))
                            else ...[
                              if (has)
                                IconButton(
                                    tooltip: 'حذف من الهاتف',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _remove(v)),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 40)),
                                onPressed: () => _choose(v),
                                child: Text(has ? 'اعتماد' : 'تحميل'),
                              ),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
