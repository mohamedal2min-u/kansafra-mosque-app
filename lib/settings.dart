import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مؤذن مضمّن في التطبيق. لإضافة مؤذن: ضع الملفين adhan_<raw>_long.mp3 و adhan_<raw>_short.mp3
/// في assets/adhan/ وفي android/app/src/main/res/raw/ ثم أضف سطرًا هنا.
class AdhanVoice {
  final String id;
  final String raw; // أحرف إنجليزية صغيرة وأرقام فقط
  final String name;
  final String credit; // الترخيص والمؤلف (ملف assets/adhan/CREDITS.md)
  const AdhanVoice(this.id, this.raw, this.name, this.credit);

  String rawName(bool long) => 'adhan_${raw}_${long ? 'long' : 'short'}';
  String asset(bool long) => 'assets/adhan/${rawName(long)}.mp3';
}

const adhanVoices = <AdhanVoice>[
  AdhanVoice('voice1', 'v1', 'أذان هادئ', 'Adam-synagda - CC0'),
  AdhanVoice('voice2', 'v2', 'أذان مختصر', 'ملكية عامة'),
  AdhanVoice('voice3', 'v3', 'عاقب عزيز', 'Atcovi - CC BY-SA 4.0'),
  AdhanVoice('voice4', 'v4', 'الحرم المكي (2013)', 'Seyfula Islam - CC BY 3.0'),
];

/// اختيار المستخدم لصوت التنبيه. [voice] فارغ مع [auto] خطأ يعني صوت الإشعار العادي.
/// [auto] (الافتراضي): لكل صلاة مؤذن مختلف من المؤذنين المضمّنين بالتناوب.
class AdhanChoice {
  static const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  final AdhanVoice? voice;
  final bool long;
  final bool auto;
  const AdhanChoice(this.voice, this.long, {this.auto = false});

  String get id => auto ? 'auto_${long ? 'long' : 'short'}' : voice == null ? 'default' : '${voice!.id}_${long ? 'long' : 'short'}';
  String get label => auto
      ? 'تلقائي: مؤذن مختلف لكل صلاة (${long ? 'كامل' : 'قصير'})'
      : voice == null ? 'صوت الإشعار العادي' : '${voice!.name} (${long ? 'كامل' : 'قصير'})';

  /// المؤذن الذي يُنادى به لهذه الصلاة في الوضع التلقائي.
  AdhanVoice voiceFor(String prayer) =>
      adhanVoices[prayers.indexOf(prayer).clamp(0, prayers.length - 1) % adhanVoices.length];

  /// اسم ملف الصوت لهذه الصلاة (null = صوت الإشعار العادي).
  String? rawNameFor(String prayer) => auto ? voiceFor(prayer).rawName(long) : voice?.rawName(long);
}

class AppSettings {
  static const _kVoice = 'adhan_voice';
  static const _kLong = 'adhan_long';
  static const _kEnabled = 'adhan_enabled';

  static Future<AdhanChoice> adhanChoice() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kVoice) ?? 'auto';
    final long = p.getBool(_kLong) ?? false;
    if (id == 'auto') return AdhanChoice(null, long, auto: true);
    return AdhanChoice(adhanVoices.where((v) => v.id == id).firstOrNull, long);
  }

  static Future<void> setAdhanChoice(AdhanChoice c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kVoice, c.auto ? 'auto' : c.voice?.id ?? 'default');
    await p.setBool(_kLong, c.long);
  }

  static Future<bool> adhanEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? true;

  static Future<void> setAdhanEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
}

/// وضع المظهر: تلقائي (حسب الهاتف) أو فاتح أو داكن، ويُحفظ.
class ThemeController {
  static const _k = 'theme_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    final v = (await SharedPreferences.getInstance()).getString(_k);
    mode.value = ThemeMode.values.where((m) => m.name == v).firstOrNull ?? ThemeMode.system;
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    await (await SharedPreferences.getInstance()).setString(_k, m.name);
  }
}
