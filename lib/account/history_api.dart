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

class History {
  final List<MyDonation> donations;
  final List<MyMessage> messages;
  History(this.donations, this.messages);
}

/// يقرأ سجل المستخدم من الجدول (تبرعاته ومحادثات الدعم وردود المسجد).
Future<History> fetchHistory() async {
  final uri = Uri.parse(MosqueConfig.donorsUrl).replace(queryParameters: {
    'action': 'mine',
    ...await Identity.instance.params(),
  });
  final res = await http.get(uri).timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  if (j['error'] != null) throw Exception('auth');
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
