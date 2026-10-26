import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'identity.dart';

class MyDonation {
  final DateTime date;
  final String name;
  final String amount;
  MyDonation(this.date, this.name, this.amount);
}

class MyMessage {
  final DateTime date;
  final String type;
  final String message;
  final String reply;
  final DateTime? replyDate;
  MyMessage(this.date, this.type, this.message, this.reply, this.replyDate);
}

/// سبب فشل تحميل السجل: auth = رفض الخادم رمز Google، server = ردّ غير متوقع من السكربت،
/// old = نسخة سكربت قديمة لا تعرف «mine».
class HistoryException implements Exception {
  final String reason;
  HistoryException(this.reason);
  @override
  String toString() => 'HistoryException($reason)';
}

class History {
  final List<MyDonation> donations;
  final List<MyMessage> messages;

  /// true: تعذّر التحقق من حساب Google عند الخادم، فعُرض سجل هذا الهاتف فقط.
  final bool deviceOnly;
  History(this.donations, this.messages, {this.deviceOnly = false});
}

/// يقرأ سجل المستخدم من الجدول (تبرعاته ومحادثات الدعم وردود المسجد).
/// إن فشل الخادم مع رمز حساب Google (غالبًا لأن إذن التحقق لم يُمنح للسكربت بعد)،
/// نعيد المحاولة بمعرّف الهاتف فقط ونعرض سجل الهاتف بدل خطأ.
Future<History> fetchHistory() async {
  final signedIn = Identity.instance.user != null;
  try {
    return await _fetch(withToken: true);
  } on HistoryException catch (e) {
    if (signedIn && (e.reason == 'server' || e.reason == 'auth')) {
      final h = await _fetch(withToken: false);
      return History(h.donations, h.messages, deviceOnly: true);
    }
    rethrow;
  }
}

Future<History> _fetch({required bool withToken}) async {
  final uri = Uri.parse(MosqueConfig.donorsUrl).replace(queryParameters: {
    'action': 'mine',
    ...await Identity.instance.params(withToken: withToken),
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  final Object? body;
  try {
    body = jsonDecode(utf8.decode(res.bodyBytes));
  } catch (_) {
    // صفحة HTML بدل JSON: عادةً السكربت يحتاج إذن UrlFetch أو نشرًا جديدًا.
    throw HistoryException('server');
  }
  if (body is List) throw HistoryException('old');
  final j = body as Map<String, dynamic>;
  if (j['error'] != null) throw HistoryException('auth');
  DateTime d(String s) => DateTime.tryParse(s) ?? DateTime.now();
  return History(
    [
      for (final r in j['donations'] as List)
        MyDonation(d(r['date']), r['name'], r['amount'])
    ],
    [
      for (final r in j['messages'] as List)
        MyMessage(d(r['date']), r['type'], r['message'], r['reply'],
            (r['replyDate'] as String).isEmpty ? null : d(r['replyDate'])),
    ],
  );
}
