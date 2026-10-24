import 'package:flutter/material.dart';

import '../services/adhan_service.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AdhanSound _sound = AdhanSound.defaultSound;
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
            RadioListTile<AdhanSound>(title: Text(s.label), value: s),
        ]),
      ),
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('الأذان القصير هو الأنسب للتنبيهات. الأذان الكامل طويل وقد يقطعه النظام.'),
      ),
    ]);
  }
}
