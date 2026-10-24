import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// هوية المستخدم لحفظ سجل تبرعاته ومحادثات الدعم:
/// معرّف عشوائي للجهاز دائمًا، وحساب Google اختياريًا لنقل السجل بين الأجهزة.
class Identity extends ChangeNotifier {
  Identity._();
  static final instance = Identity._();

  static const _kDevice = 'device_id';
  String? _device;
  GoogleSignInAccount? _user;

  bool get googleEnabled => MosqueConfig.googleWebClientId.isNotEmpty;
  GoogleSignInAccount? get user => _user;

  late final GoogleSignIn _gsi = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: MosqueConfig.googleWebClientId,
  );

  Future<String> deviceId() async {
    if (_device != null) return _device!;
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_kDevice);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString(_kDevice, id);
    }
    return _device = id;
  }

  Future<void> restore() async {
    if (!googleEnabled) return;
    try {
      _user = await _gsi.signInSilently();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> signIn() async {
    _user = await _gsi.signIn();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _user = null;
    notifyListeners();
  }

  /// معاملات تُرسل إلى الجدول: device دائمًا، و idToken إن كان المستخدم مسجّلًا بحساب Google.
  Future<Map<String, String>> params() async {
    final m = {'device': await deviceId()};
    if (googleEnabled && _user != null) {
      try {
        final auth = await (_user!.authentication);
        if (auth.idToken != null) m['idToken'] = auth.idToken!;
      } catch (_) {}
    }
    return m;
  }
}
