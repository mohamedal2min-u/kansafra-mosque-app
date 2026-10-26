import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مؤذن مضمّن في التطبيق. لإضافة مؤذن: ضع الملفين adhan_<raw>_long.mp3 و adhan_<raw>_short.mp3
/// في assets/adhan/ وفي android/app/src/main/res/raw/ ثم أضف سطرًا هنا.
class AdhanVoice {
  final String id;
  final String raw; // أحرف إنجليزية صغيرة وأرقام فقط
  final String name;
  final String credit; // الترخيص والمؤلف (ملف assets/adhan/CREDITS.md)
  final bool hasLong; // بعض المؤذنين المضافين آليًا لهم نسخة قصيرة فقط
  final bool inAuto; // يدخل في الوضع التلقائي (مؤذن لكل صلاة)
  const AdhanVoice(this.id, this.raw, this.name, this.credit,
      {this.hasLong = true, this.inAuto = true});

  String rawName(bool long) =>
      'adhan_${raw}_${long && hasLong ? 'long' : 'short'}';
  // المعاينة داخل التطبيق دائمًا بالنسخة القصيرة (النسخة الكاملة في res/raw للإشعار فقط)، فيصغر التطبيق.
  String get previewAsset => 'assets/adhan/adhan_${raw}_short.mp3';
}

const _baseVoices = <AdhanVoice>[
  AdhanVoice(
      'voice1', 'v1', 'أذان هادئ', 'Adam-synagda - CC0 (Wikimedia Commons)'),
  AdhanVoice('voice2', 'v2', 'أذان مختصر', 'ملكية عامة (Wikimedia Commons)'),
  AdhanVoice(
      'voice3', 'v3', 'عاقب عزيز', 'Atcovi - CC BY-SA 4.0 (Wikimedia Commons)'),
  AdhanVoice('voice4', 'v4', 'الحرم المكي (2013)',
      'Seyfula Islam - CC BY 3.0 (Wikimedia Commons)'),
];

/// المؤذنون المضمّنون في التطبيق (المزيد يُحمَّل من الكتالوج الأونلاين عند الطلب).
const adhanVoices = _baseVoices;

/// مؤذن حمّله المستخدم من الكتالوج الأونلاين وسُجّل في النظام ([uri] من نوع content://).
class CustomAdhan {
  final String id;
  final String name;
  final String uri;
  const CustomAdhan(this.id, this.name, this.uri);

  Map<String, String> toJson() => {'id': id, 'name': name, 'uri': uri};
  static CustomAdhan? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return CustomAdhan(
          m['id'] as String, m['name'] as String, m['uri'] as String);
    } catch (_) {
      return null;
    }
  }
}

/// اختيار المستخدم لصوت التنبيه. [voice] فارغ مع [auto] خطأ يعني صوت الإشعار العادي.
/// [auto] (الافتراضي): لكل صلاة مؤذن مختلف من المؤذنين المضمّنين بالتناوب.
class AdhanChoice {
  static const prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
  final AdhanVoice? voice;
  final bool long;
  final bool auto;
  final CustomAdhan?
      custom; // مؤذن محمَّل من الكتالوج (يتقدّم على بقية الخيارات)
  const AdhanChoice(this.voice, this.long, {this.auto = false, this.custom});

  String get id => custom != null
      ? 'custom_${custom!.id}'
      : auto
          ? 'auto_${long ? 'long' : 'short'}'
          : voice == null
              ? 'default'
              : '${voice!.id}_${long ? 'long' : 'short'}';
  String get label => custom != null
      ? 'أذان: ${custom!.name}'
      : auto
          ? 'تلقائي: مؤذن مختلف لكل صلاة (${long ? 'كامل' : 'قصير'})'
          : voice == null
              ? 'صوت الإشعار العادي'
              : '${voice!.name} (${long ? 'كامل' : 'قصير'})';

  /// المؤذن لهذه الصلاة في الوضع التلقائي: خمسة مؤذنين مختلفين كل يوم، ويتبدّلون من يوم لآخر
  /// فيمرّ التطبيق على كل المؤذنين المضمّنين. [epochDay] = رقم اليوم منذ 1970.
  AdhanVoice voiceFor(String prayer, int epochDay) {
    final pool = adhanVoices.where((v) => v.inAuto).toList();
    final i = prayers.indexOf(prayer).clamp(0, prayers.length - 1);
    return pool[(epochDay * prayers.length + i) % pool.length];
  }

  /// اسم ملف الصوت لهذه الصلاة (null = صوت الإشعار العادي).
  String? rawNameFor(String prayer, int epochDay) => custom != null
      ? null
      : auto
          ? voiceFor(prayer, epochDay).rawName(long)
          : voice?.rawName(long);
}

class AppSettings {
  static const _kVoice = 'adhan_voice';
  static const _kLong = 'adhan_long';
  static const _kEnabled = 'adhan_enabled';
  static const _kCustom = 'adhan_custom';

  static Future<AdhanChoice> adhanChoice() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kVoice) ?? 'auto';
    final long = p.getBool(_kLong) ?? false;
    if (id == 'custom') {
      final c = CustomAdhan.fromJson(p.getString(_kCustom));
      if (c != null) return AdhanChoice(null, long, custom: c);
    }
    if (id == 'auto' || id == 'custom') {
      return AdhanChoice(null, long, auto: true);
    }
    return AdhanChoice(adhanVoices.where((v) => v.id == id).firstOrNull, long);
  }

  static Future<void> setAdhanChoice(AdhanChoice c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kVoice,
        c.custom != null
            ? 'custom'
            : c.auto
                ? 'auto'
                : c.voice?.id ?? 'default');
    if (c.custom != null) {
      await p.setString(_kCustom, jsonEncode(c.custom!.toJson()));
    }
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
    mode.value = ThemeMode.values.where((m) => m.name == v).firstOrNull ??
        ThemeMode.system;
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    await (await SharedPreferences.getInstance()).setString(_k, m.name);
  }
}
