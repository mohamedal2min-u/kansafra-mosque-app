import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../quran/audio_store.dart';
import 'adhan_catalog_screen.dart';
import '../quran/downloader.dart';
import '../quran/player.dart';
import '../config.dart';
import '../launcher.dart';
import '../services/adhan_service.dart';
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
      if (mounted)
        setState(() {
          _choice = c;
          _enabled = e;
        });
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

  Future<void> _preview(AdhanVoice v) async {
    final p = QuranPlayer.instance;
    final id = '${v.id}_${_choice.long}';
    if (p.previewId == id) {
      await p.stop();
      return;
    }
    try {
      await p.preview(id, v.name,
          (tag) => AudioSource.asset(v.asset(_choice.long), tag: tag));
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
          onTap: () async {
            final ok = await Launcher.openUrl(MosqueConfig.facebookUrl);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تعذّر فتح الرابط.')));
            }
          },
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
