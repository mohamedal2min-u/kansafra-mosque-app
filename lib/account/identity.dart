import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
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

  /// عدد السجلات التي نُقلت من الهاتف إلى الحساب في آخر دخول (لرسالة للمستخدم).
  int movedOnSignIn = 0;

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
      if (_user != null) await claimDeviceHistory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> signIn() async {
    _user = await _gsi.signIn();
    if (_user != null) movedOnSignIn = await claimDeviceHistory();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _user = null;
    notifyListeners();
  }

  /// ينقل سجل هذا الهاتف إلى الحساب. الجدول يفعلها لأول حساب فقط، ويرجع عدد السجلات المنقولة.
  Future<int> claimDeviceHistory() async {
    try {
      final uri = Uri.parse(MosqueConfig.donorsUrl).replace(
          queryParameters:
              await params().then((m) => {...m, 'action': 'claim'}));
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      final m = RegExp(r'"moved":(\d+)').firstMatch(res.body);
      return m == null ? 0 : int.parse(m.group(1)!);
    } catch (_) {
      return 0;
    }
  }

  /// معاملات تُرسل إلى الجدول: device دائمًا، و idToken إن كان المستخدم مسجّلًا بحساب Google.
  Future<Map<String, String>> params({bool withToken = true}) async {
    final m = {'device': await deviceId()};
    if (withToken && googleEnabled && _user != null) {
      try {
        final auth = await (_user!.authentication);
        if (auth.idToken != null) m['idToken'] = auth.idToken!;
      } catch (_) {}
    }
    return m;
  }
}
