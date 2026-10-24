import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/adhan_catalog.dart';
import '../services/adhan_service.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  AdhanPermissions? _perm;
  AdhanChoice _choice = AdhanChoice(adhanVoices.first, false);
  bool _enabled = true;
  AudioPlayer? _player; // يُنشأ عند أول استماع فقط
  String? _playingId;
  String _query = '';
  String? _downloadingId; // مؤذن إضافي قيد التحميل

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPerm();
    AdhanCatalog.restore().then((_) {
      if (mounted) setState(() {});
      return AdhanCatalog.refresh();
    }).then((_) {
      if (mounted) setState(() {});
    });
    () async {
      final c = await AppSettings.adhanChoice();
      final e = await AppSettings.adhanEnabled();
      if (mounted) setState(() { _choice = c; _enabled = e; });
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
    _player?.dispose();
    super.dispose();
  }

  Future<void> _pick(AdhanChoice c) async {
    final v = c.voice;
    // المؤذن الإضافي يُحمَّل مرة واحدة عند أول اختيار له (وللطول الآخر عند تبديله).
    if (v != null && v.isRemote && !await AdhanCatalog.isDownloaded(v, c.long)) {
      setState(() => _downloadingId = v.id);
      final ok = await AdhanCatalog.download(v, c.long);
      if (!mounted) return;
      setState(() => _downloadingId = null);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّر تحميل الصوت. تأكد من الاتصال بالإنترنت، وأن الهاتف أندرويد 10 أو أحدث.')));
        return;
      }
    }
    setState(() => _choice = c);
    await AppSettings.setAdhanChoice(c);
    await AdhanService.instance.scheduleAll(force: true);
  }

  Future<void> _preview(AdhanVoice v) async {
    final id = '${v.id}_${_choice.long}';
    if (_playingId == id) {
      await _player?.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = id);
    try {
      final player = _player ??= AudioPlayer();
      if (v.isRemote) {
        await player.setUrl(v.url(_choice.long)!);
      } else {
        await player.setAsset(v.asset(_choice.long));
      }
      await player.play();
    } catch (_) {}
    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _choice.voice?.id ?? 'default';
    final perm = _perm;
    final q = _query.trim();
    final allVoices = [...adhanVoices, ...remoteVoices];
    final voices = [
      for (final v in allVoices)
        if (q.isEmpty || v.name.contains(q) || v.id == selected) v,
    ];
    return ListView(children: [
      if (perm != null && !perm.ok)
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الأذان لن يعمل والتطبيق مغلق حتى تفعّل:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (!perm.notifications)
                OutlinedButton.icon(
                  onPressed: () async { await AdhanService.instance.enableNotifications(); _loadPerm(); },
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('تفعيل الإشعارات'),
                ),
              if (!perm.exactAlarms)
                OutlinedButton.icon(
                  onPressed: () async { await AdhanService.instance.enableExactAlarms(); _loadPerm(); },
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
      ListTile(
        leading: const Icon(Icons.battery_saver),
        title: const Text('استثناء التطبيق من توفير البطارية'),
        subtitle: const Text('يمنع بعض الهواتف من إيقاف الأذان في الخلفية.'),
        onTap: () => AdhanService.instance.ignoreBatteryOptimizations(),
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
          onSelectionChanged: (s) => _pick(AdhanChoice(_choice.voice, s.first)),
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('المؤذن'),
      ),
      if (allVoices.length > 8)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'ابحث عن مؤذن',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (t) => setState(() => _query = t),
          ),
        ),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (id) {
          if (id == null) return;
          final v = allVoices.where((e) => e.id == id).firstOrNull;
          _pick(AdhanChoice(v, _choice.long));
        },
        child: Column(children: [
          for (final v in voices)
            RadioListTile<String>(
              title: Text(v.name),
              value: v.id,
              subtitle: v.isRemote ? const Text('يُحمَّل عند اختياره') : null,
              secondary: _downloadingId == v.id
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: Icon(_playingId == '${v.id}_${_choice.long}' ? Icons.stop_circle : Icons.play_circle),
                      tooltip: 'استماع',
                      onPressed: () => _preview(v),
                    ),
            ),
          const RadioListTile<String>(title: Text('صوت الإشعار العادي'), value: 'default'),
        ]),
      ),
      ExpansionTile(
        title: const Text('مصادر تسجيلات الأذان'),
        children: [
          for (final v in allVoices)
            ListTile(dense: true, title: Text(v.name), subtitle: Text(v.credit)),
        ],
      ),
    ]);
  }
}
