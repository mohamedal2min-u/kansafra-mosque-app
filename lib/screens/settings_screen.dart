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
  final _player = AudioPlayer();
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
    _player.dispose();
    super.dispose();
  }

  Future<void> _pick(AdhanChoice c) async {
    setState(() => _choice = c);
    await AppSettings.setAdhanChoice(c);
    await AdhanService.instance.scheduleAll();
  }

  Future<void> _preview(AdhanChoice c) async {
    if (c.voice == null) return;
    if (_playingId == c.id) {
      await _player.stop();
      setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = c.id);
    try {
      await _player.setAsset(c.voice!.asset(c.long));
      await _player.play();
    } catch (_) {}
    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final v in adhanVoices) ...[AdhanChoice(v, false), AdhanChoice(v, true)],
      const AdhanChoice(null, false),
    ];
    return ListView(children: [
      SwitchListTile(
        title: const Text('تنبيه الأذان'),
        value: _enabled,
        onChanged: (v) async {
          setState(() => _enabled = v);
          await AppSettings.setAdhanEnabled(v);
          await AdhanService.instance.scheduleAll();
        },
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('صوت الأذان'),
      ),
      RadioGroup<String>(
        groupValue: _choice.id,
        onChanged: (id) {
          if (id != null) _pick(options.firstWhere((o) => o.id == id));
        },
        child: Column(children: [
          for (final o in options)
            RadioListTile<String>(
              title: Text(o.label),
              value: o.id,
              secondary: o.voice == null
                  ? null
                  : IconButton(
                      icon: Icon(_playingId == o.id ? Icons.stop_circle : Icons.play_circle),
                      tooltip: 'استماع',
                      onPressed: () => _preview(o),
                    ),
            ),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('القصير هو الأنسب للتنبيه، وقد يقطع النظام الأذان الكامل. اضغط ▶ للاستماع قبل الاختيار.'),
      ),
    ]);
  }
}
