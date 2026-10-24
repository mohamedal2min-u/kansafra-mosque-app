import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/adhan_service.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AdhanChoice _choice = AdhanChoice(adhanVoices.first, false);
  bool _enabled = true;
  AudioPlayer? _player; // يُنشأ عند أول استماع فقط
  String? _playingId;

  @override
  void initState() {
    super.initState();
    () async {
      final c = await AppSettings.adhanChoice();
      final e = await AppSettings.adhanEnabled();
      if (mounted) setState(() { _choice = c; _enabled = e; });
    }();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _pick(AdhanChoice c) async {
    setState(() => _choice = c);
    await AppSettings.setAdhanChoice(c);
    await AdhanService.instance.scheduleAll(force: true);
  }

  Future<void> _preview(AdhanVoice v) async {
    // المعاينة بمقطع قصير فقط (الأذان الكامل يُشغَّل عند وقت الصلاة)، لتخفيف حجم التطبيق.
    final id = v.id;
    if (_playingId == id) {
      await _player?.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = id);
    try {
      final player = _player ??= AudioPlayer();
      await player.setAsset(v.asset(false));
      await player.play();
    } catch (_) {}
    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _choice.voice?.id ?? 'default';
    return ListView(children: [
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
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (id) {
          if (id == null) return;
          final v = adhanVoices.where((e) => e.id == id).firstOrNull;
          _pick(AdhanChoice(v, _choice.long));
        },
        child: Column(children: [
          for (final v in adhanVoices)
            RadioListTile<String>(
              title: Text(v.name),
              value: v.id,
              secondary: IconButton(
                icon: Icon(_playingId == v.id ? Icons.stop_circle : Icons.play_circle),
                tooltip: 'استماع لمقطع',
                onPressed: () => _preview(v),
              ),
            ),
          const RadioListTile<String>(title: Text('صوت الإشعار العادي'), value: 'default'),
        ]),
      ),
      ExpansionTile(
        title: const Text('مصادر تسجيلات الأذان'),
        children: [
          for (final v in adhanVoices)
            ListTile(dense: true, title: Text(v.name), subtitle: Text('${v.credit} (Wikimedia Commons)')),
        ],
      ),
    ]);
  }
}
