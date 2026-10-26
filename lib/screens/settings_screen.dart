import 'dart:ui' as ui;

import 'package:adhan/adhan.dart' show CalculationMethod;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../quran/audio_store.dart';
import 'adhan_catalog_screen.dart';
import 'diagnostics_screen.dart';
import '../quran/downloader.dart';
import '../quran/player.dart';
import '../config.dart';
import '../launcher.dart';
import '../services/adhan_service.dart';
import '../flavor.dart';
import '../services/home_place.dart';
import '../services/travel_watch.dart';
import '../services/prayer_calc.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  AdhanPermissions? _perm;
  AdhanChoice _choice = const AdhanChoice(null, false, auto: true);
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPerm();
    () async {
      final c = await AppSettings.adhanChoice();
      final e = await AppSettings.adhanEnabled();
      if (mounted) {
        setState(() {
          _choice = c;
          _enabled = e;
        });
      }
    }();
  }

  Future<void> _loadPerm() async {
    final p = await AdhanService.instance.permissions();
    if (mounted) setState(() => _perm = p);
  }

  // عند الرجوع من إعدادات الهاتف نحدّث الحالة.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadPerm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (QuranPlayer.instance.previewId != null) QuranPlayer.instance.stop();
    super.dispose();
  }

  Future<void> _pick(AdhanChoice c) async {
    setState(() => _choice = c);
    await AppSettings.setAdhanChoice(c);
    await AdhanService.instance.scheduleAll(force: true);
  }

  bool _locating = false;

  /// يحدّد مكان السكن ويجعل الأذان على توقيته.
  Future<void> _locate() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final err = await HomePlace.locate();
    if (mounted) setState(() => _locating = false);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    await AdhanService.instance.scheduleAll(force: true);
    messenger.showSnackBar(SnackBar(
        content: Text('صار الأذان على توقيت ${HomePlace.site.value!.name}')));
  }

  static String _adjSummary(Map<String, int> adj) {
    final parts = [
      for (final e in PrayerCalc.names.entries)
        if ((adj[e.key] ?? 0) != 0)
          '${e.value}: ${adj[e.key]! > 0 ? 'تأخير' : 'تقديم'} ${adj[e.key]!.abs()} د',
    ];
    return parts.isEmpty ? 'بلا تعديل' : parts.join('، ');
  }

  Future<void> _saveHome(PrayerSite s) async {
    await HomePlace.set(s);
    await AdhanService.instance.scheduleAll(force: true);
  }

  Future<void> _pickMethod(PrayerSite home) async {
    final m = await showDialog<CalculationMethod>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('طريقة الحساب'),
        children: [
          RadioGroup<CalculationMethod>(
            groupValue: home.method,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(children: [
              for (final e in PrayerSite.methods.entries)
                RadioListTile<CalculationMethod>(
                    title: Text(e.value), value: e.key),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
                'الأدق: اختر طريقة مسجدك المحلي، ثم طابق الدقائق مع جدوله.',
                style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (m != null && m != home.method) {
      await _saveHome(home.copyWith(method: m));
    }
  }

  Future<void> _editAdjustments(PrayerSite home) async {
    final adj = Map<String, int>.of(home.adjustments);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                  'قدّم أو أخّر كل صلاة بالدقائق لتطابق جدول مسجدك المحلي.'),
            ),
            for (final e in PrayerCalc.names.entries)
              ListTile(
                title: Text(e.value),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: (adj[e.key] ?? 0) <= -60
                        ? null
                        : () =>
                            setSheet(() => adj[e.key] = (adj[e.key] ?? 0) - 1),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                        '${(adj[e.key] ?? 0) > 0 ? '+' : ''}${adj[e.key] ?? 0}',
                        textAlign: TextAlign.center,
                        textDirection: ui.TextDirection.ltr, // «-5» لا «5-»
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: (adj[e.key] ?? 0) >= 60
                        ? null
                        : () =>
                            setSheet(() => adj[e.key] = (adj[e.key] ?? 0) + 1),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    adj.removeWhere((_, v) => v == 0);
    if (adj.toString() != home.adjustments.toString()) {
      await _saveHome(home.copyWith(adjustments: adj));
    }
  }

  /// طريقة الحساب وتعديل الدقائق لمكان المستخدم.
  List<Widget> _siteTiles(PrayerSite home, double indent) => [
        ListTile(
          contentPadding: EdgeInsetsDirectional.only(start: indent, end: 16),
          title: const Text('طريقة الحساب'),
          subtitle: Text(home.methodName),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _pickMethod(home),
        ),
        ListTile(
          contentPadding: EdgeInsetsDirectional.only(start: indent, end: 16),
          title: const Text('مطابقة مسجدك (تعديل بالدقائق)'),
          subtitle: Text(_adjSummary(home.adjustments)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _editAdjustments(home),
        ),
      ];

  /// «رفيق المسلم»: المواقيت لمكان المستخدم دائمًا (من الواي فاي)، مع زر التحديث.
  Widget _generalPlace(PrayerSite? home) => Column(children: [
        ListTile(
          leading: const Icon(Icons.location_on_rounded),
          title: const Text('موقعك'),
          subtitle: Text(home == null
              ? 'مكة المكرمة، حتى تحدّد موقعك'
              : '${home.name}${HomePlace.approximate.value ? ' (تقريبي)' : ''}'),
          trailing: _locating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : IconButton(
                  icon: const Icon(Icons.my_location_rounded),
                  tooltip: 'تحديد موقعي (من الواي فاي)',
                  onPressed: _locate,
                ),
        ),
        if (home != null) ..._siteTiles(home, 16),
      ]);

  Future<void> _useMosqueTime() async {
    await HomePlace.clear();
    await AdhanService.instance.scheduleAll(force: true);
  }

  Future<void> _preview(AdhanVoice v) async {
    final p = QuranPlayer.instance;
    final id = '${v.id}_${_choice.long}';
    if (p.previewId == id) {
      await p.stop();
      return;
    }
    try {
      await p.preview(
          id, v.name, (tag) => AudioSource.asset(v.previewAsset, tag: tag));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final selected = _choice.custom != null
        ? 'custom'
        : _choice.auto
            ? 'auto'
            : _choice.voice?.id ?? 'default';
    final perm = _perm;
    return ListView(children: [
      if (perm != null && !perm.ok)
        Card(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Theme.of(context).colorScheme.tertiary),
          ),
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.notifications_active_rounded,
                    color: Theme.of(context).colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('فعّل التالي ليعمل الأذان والتطبيق مغلق:',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              if (!perm.notifications)
                OutlinedButton.icon(
                  onPressed: () async {
                    await AdhanService.instance.enableNotifications();
                    _loadPerm();
                  },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('تفعيل الإشعارات'),
                ),
              if (!perm.exactAlarms)
                OutlinedButton.icon(
                  onPressed: () async {
                    await AdhanService.instance.enableExactAlarms();
                    _loadPerm();
                  },
                  icon: const Icon(Icons.alarm_on),
                  label: const Text('السماح بالتنبيهات في وقتها الدقيق'),
                ),
            ]),
          ),
        ),
      SwitchListTile(
        title: const Text('تنبيه الأذان'),
        value: _enabled,
        onChanged: (v) async {
          setState(() => _enabled = v);
          await AppSettings.setAdhanEnabled(v);
          await AdhanService.instance.scheduleAll(force: true);
        },
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('توقيت الأذان'),
      ),
      ValueListenableBuilder<PrayerSite?>(
        valueListenable: HomePlace.site,
        builder: (_, home, __) => AppFlavor.general
            ? _generalPlace(home)
            : RadioGroup<bool>(
                groupValue: home != null,
                onChanged: (v) {
                  if (v == true && home == null) _locate();
                  if (v == false && home != null) _useMosqueTime();
                },
                child: Column(children: [
                  const RadioListTile<bool>(
                    title: Text('توقيت كنصفرة'),
                    subtitle: Text('مواقيت المسجد'),
                    value: false,
                  ),
                  RadioListTile<bool>(
                    title: const Text('توقيت مكان سكني'),
                    subtitle: Text(home == null
                        ? 'لمن يسكن خارج كنصفرة: يُحدَّد موقعك مرة واحدة'
                        : '${home.name}، وتبقى مواقيت كنصفرة ظاهرة في الرئيسية'),
                    value: true,
                    secondary: _locating
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : home == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.my_location_rounded),
                                tooltip: 'تحديث الموقع',
                                onPressed: _locate,
                              ),
                  ),
                  if (home != null) ..._siteTiles(home, 72),
                ]),
              ),
      ),
      if (!kIsWeb && !AppFlavor.general) const _TravelSection(),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('المظهر'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.mode,
          builder: (_, m, __) => SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_rounded),
                  label: Text('تلقائي')),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_rounded),
                  label: Text('فاتح')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_rounded),
                  label: Text('داكن')),
            ],
            selected: {m},
            onSelectionChanged: (s) => ThemeController.set(s.first),
          ),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('طول الأذان'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('قصير')),
            ButtonSegment(value: true, label: Text('كامل')),
          ],
          selected: {_choice.long},
          onSelectionChanged: (s) => _pick(AdhanChoice(_choice.voice, s.first,
              auto: _choice.auto, custom: _choice.custom)),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('المؤذن'),
      ),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (id) {
          if (id == null || id == 'custom') return;
          final v = adhanVoices.where((e) => e.id == id).firstOrNull;
          _pick(AdhanChoice(v, _choice.long, auto: id == 'auto'));
        },
        child: Column(children: [
          const RadioListTile<String>(
            title: Text('تلقائي (موصى به)'),
            subtitle: Text('مؤذن مختلف لكل صلاة، ويتبدّل كل يوم'),
            value: 'auto',
          ),
          for (final v in adhanVoices)
            RadioListTile<String>(
              title: Text(v.name),
              value: v.id,
              secondary: ListenableBuilder(
                listenable: QuranPlayer.instance,
                builder: (_, __) => IconButton(
                  icon: Icon(
                      QuranPlayer.instance.previewId ==
                              '${v.id}_${_choice.long}'
                          ? Icons.stop_circle
                          : Icons.play_circle,
                      size: 34),
                  tooltip: 'استماع',
                  onPressed: () => _preview(v),
                ),
              ),
            ),
          const RadioListTile<String>(
              title: Text('صوت الإشعار العادي'), value: 'default'),
          if (_choice.custom != null)
            RadioListTile<String>(
                title: Text(_choice.custom!.name),
                subtitle: const Text('محمَّل من الإنترنت'),
                value: 'custom'),
        ]),
      ),
      ListTile(
        leading: const Icon(Icons.cloud_download_rounded),
        title: const Text('المزيد من المؤذنين'),
        subtitle: const Text('نحو 140 مؤذنًا: استمع واختر، فيُحمَّل على هاتفك'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdhanCatalogScreen(
            current: _choice.custom,
            onPicked: (c) => _pick(AdhanChoice(null, _choice.long, custom: c)),
          ),
        )),
      ),
      if (AudioStore.supported) const _SavedAudioTile(),
      if (Launcher.supported)
        ListTile(
          leading:
              const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 30),
          title: const Text('صفحتنا على فيسبوك'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => Launcher.openWithFeedback(
              context, MosqueConfig.facebookUrl,
              packages: MosqueConfig.facebookPackages,
              appUrl: MosqueConfig.facebookAppUrl,
              label: 'صفحة فيسبوك'),
        ),
      ListTile(
        leading: const Icon(Icons.health_and_safety_rounded),
        title: const Text('تشخيص التطبيق'),
        subtitle: const Text('لماذا لا يصلني الأذان؟ وتجربة الصوت'),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
      ),
      if (Launcher.supported)
        ListTile(
          leading: const Icon(Icons.privacy_tip_rounded),
          title: const Text('سياسة الخصوصية'),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => Launcher.openWithFeedback(
              context, MosqueConfig.privacyUrl,
              label: 'سياسة الخصوصية'),
        ),
      ExpansionTile(
        title: const Text('مصادر تسجيلات الأذان'),
        children: [
          for (final v in adhanVoices)
            ListTile(
                dense: true, title: Text(v.name), subtitle: Text(v.credit)),
        ],
      ),
    ]);
  }
}

/// حجم التلاوات المحفوظة على الهاتف مع زر حذفها.
class _SavedAudioTile extends StatefulWidget {
  const _SavedAudioTile();

  @override
  State<_SavedAudioTile> createState() => _SavedAudioTileState();
}

class _SavedAudioTileState extends State<_SavedAudioTile> {
  late Future<(int, Map<String, dynamic>?)> _info = _load();

  Future<(int, Map<String, dynamic>?)> _load() async =>
      (await AudioStore.totalBytes(), await AudioStore.pinned());

  String _fmt(int b) => b < 1024 * 1024
      ? '${(b / 1024).round()} ك.ب'
      : '${(b / 1024 / 1024).toStringAsFixed(1)} م.ب';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(int, Map<String, dynamic>?)>(
      future: _info,
      builder: (context, snap) {
        final size = snap.data?.$1 ?? 0;
        final name = snap.data?.$2?['name'];
        return ListTile(
          leading: const Icon(Icons.download_done_rounded),
          title: const Text('مصحف محمَّل على الهاتف'),
          subtitle: Text(!snap.hasData
              ? '...'
              : size == 0
                  ? 'لا يوجد (التحميل من تبويب القرآن ← استماع)'
                  : '${name ?? 'قارئ'} · ${_fmt(size)}'),
          trailing: TextButton(
            onPressed: size == 0
                ? null
                : () async {
                    await QuranDownloader.instance.deleteAll();
                    if (mounted) setState(() => _info = _load());
                  },
            child: const Text('حذف'),
          ),
        );
      },
    );
  }
}

/// تنبيه السفر: تشغيل/إيقاف، وشبكات كنصفرة المحفوظة.
class _TravelSection extends StatefulWidget {
  const _TravelSection();

  @override
  State<_TravelSection> createState() => _TravelSectionState();
}

class _TravelSectionState extends State<_TravelSection> {
  bool _on = true;
  List<String> _nets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await TravelWatch.enabled();
    final nets = await TravelWatch.networks();
    if (mounted) {
      setState(() {
        _on = on;
        _nets = nets;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SwitchListTile(
        secondary: const Icon(Icons.travel_explore_rounded),
        title: const Text('تنبيه عند السفر'),
        subtitle: const Text(
            'إن ابتعدت عن كنصفرة يومًا (حلب مثلًا) أو يومين خارج سوريا، نقترح الأذان على توقيت مكانك'),
        value: _on,
        onChanged: (v) async {
          setState(() => _on = v);
          await TravelWatch.setEnabled(v);
        },
      ),
      if (_on)
        ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 72, end: 8),
          title: const Text('شبكات كنصفرة'),
          subtitle: Text(_nets.isEmpty
              ? 'لم تُحفظ شبكة بعد'
              : 'محفوظة: ${_nets.join('، ')}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.add_location_alt_rounded),
              tooltip: 'أنا في كنصفرة الآن: احفظ هذه الشبكة',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final err = await TravelWatch.confirmHere();
                messenger.showSnackBar(SnackBar(
                    content:
                        Text(err ?? 'حُفظت الشبكة الحالية كشبكة كنصفرة.')));
                _load();
              },
            ),
            if (_nets.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'مسح الشبكات المحفوظة',
                onPressed: () async {
                  await TravelWatch.clearNetworks();
                  _load();
                },
              ),
          ]),
        ),
    ]);
  }
}
