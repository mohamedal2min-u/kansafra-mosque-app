import 'package:shared_preferences/shared_preferences.dart';

/// صوت تنبيه الأذان. الملفان الصوتيان يوضعان في android/app/src/main/res/raw/
enum AdhanSound {
  defaultSound('default', 'صوت الإشعار العادي', null),
  shortAdhan('adhan_short', 'أذان قصير', 'adhan_short'),
  fullAdhan('adhan_full', 'أذان كامل', 'adhan_full');

  final String id;
  final String label;
  final String? rawName;
  const AdhanSound(this.id, this.label, this.rawName);

  static AdhanSound fromId(String? id) =>
      values.firstWhere((e) => e.id == id, orElse: () => defaultSound);
}

class AppSettings {
  static const _kSound = 'adhan_sound';
  static const _kEnabled = 'adhan_enabled';

  static Future<AdhanSound> adhanSound() async {
    final p = await SharedPreferences.getInstance();
    return AdhanSound.fromId(p.getString(_kSound));
  }

  static Future<void> setAdhanSound(AdhanSound v) async =>
      (await SharedPreferences.getInstance()).setString(_kSound, v.id);

  static Future<bool> adhanEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_kEnabled) ?? true;

  static Future<void> setAdhanEnabled(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kEnabled, v);
}
