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
  AdhanVoice('voice1', 'v1', 'أذان هادئ', 'Wikimedia Commons - Adam-synagda - CC0'),
  AdhanVoice('voice2', 'v2', 'أذان مختصر', 'Wikimedia Commons - ملكية عامة'),
  AdhanVoice('voice3', 'v3', 'عاقب عزيز', 'Wikimedia Commons - Atcovi - CC BY-SA 4.0'),
  AdhanVoice('voice4', 'v4', 'الحرم المكي (2013)', 'Wikimedia Commons - Seyfula Islam - CC BY 3.0'),
  AdhanVoice('voice5', 'v5', 'علي ملا (الحرم المكي)', 'archive.org - الرخصة غير محددة'),
  AdhanVoice('voice6', 'v6', 'مشاري العفاسي', 'archive.org - الرخصة غير محددة'),
  AdhanVoice('voice7', 'v7', 'ناصر القطامي', 'archive.org - الرخصة غير محددة'),
  AdhanVoice('voice8', 'v8', 'فاروق حضراوي', 'archive.org - الرخصة غير محددة'),
];

/// اختيار المستخدم لصوت التنبيه. [voice] فارغ يعني صوت الإشعار العادي.
class AdhanChoice {
  final AdhanVoice? voice;
  final bool long;
  const AdhanChoice(this.voice, this.long);

  String get id => voice == null ? 'default' : '${voice!.id}_${long ? 'long' : 'short'}';
  String get label => voice == null ? 'صوت الإشعار العادي' : '${voice!.name} (${long ? 'كامل' : 'قصير'})';
  String? get rawName => voice?.rawName(long);
}

class AppSettings {
  static const _kVoice = 'adhan_voice';
  static const _kLong = 'adhan_long';
  static const _kEnabled = 'adhan_enabled';

  static Future<AdhanChoice> adhanChoice() async {
    final p = await SharedPreferences.getInstance();
    final id = p.getString(_kVoice) ?? adhanVoices.first.id;
    final voice = adhanVoices.where((v) => v.id == id).firstOrNull;
    return AdhanChoice(voice, p.getBool(_kLong) ?? false);
  }

  static Future<void> setAdhanChoice(AdhanChoice c) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kVoice, c.voice?.id ?? 'default');
    await p.setBool(_kLong, c.long);
  }

  static Future<bool> adhanEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? true;

  static Future<void> setAdhanEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
}
