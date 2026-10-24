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
  AdhanSound _sound = AdhanSound.shortAdhan;
  final _player = AudioPlayer();
  AdhanSound? _playing;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    () async {
      final s = await AppSettings.adhanSound();
      final e = await AppSettings.adhanEnabled();
      if (mounted) setState(() { _sound = s; _enabled = e; });
    }();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(AdhanSound s) async {
    if (s.asset == null) return;
    if (_playing == s) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = s);
    try {
      await _player.setAsset(s.asset!);
      await _player.play();
    } catch (_) {}
    if (mounted) setState(() => _playing = null);
  }

  Future<void> _apply() async => AdhanService.instance.scheduleAll();

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      SwitchListTile(
        title: const Text('تنبيه الأذان'),
        value: _enabled,
        onChanged: (v) async {
          setState(() => _enabled = v);
          await AppSettings.setAdhanEnabled(v);
          await _apply();
        },
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text('صوت الأذان'),
      ),
      RadioGroup<AdhanSound>(
        groupValue: _sound,
        onChanged: (v) async {
          if (v == null) return;
          setState(() => _sound = v);
          await AppSettings.setAdhanSound(v);
          await _apply();
        },
        child: Column(children: [
          for (final s in AdhanSound.values)
            RadioListTile<AdhanSound>(
              title: Text(s.label),
              value: s,
              secondary: s.asset == null
                  ? null
                  : IconButton(
                      icon: Icon(_playing == s ? Icons.stop_circle : Icons.play_circle),
                      tooltip: 'استماع',
                      onPressed: () => _preview(s),
                    ),
            ),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('المؤذن 2 (القصير) هو الأنسب للتنبيه. الأذان الكامل طويل وقد يقطعه النظام. اضغط ▶ للاستماع قبل الاختيار.'),
      ),
    ]);
  }
}
