import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// متبرع في القائمة. إن كان [name] فارغًا يُعرض «فاعل خير».
class Donor {
  final String name;
  final String amount;
  final DateTime date;
  const Donor({required this.name, required this.amount, required this.date});

  String get displayName => name.trim().isEmpty ? 'فاعل خير' : name.trim();
  String get line => amount.trim().isEmpty ? '$displayName تبرّع' : '$displayName تبرّع بـ ${amount.trim()}';
}

abstract class DonorsRepository {
  Future<List<Donor>> donors();
  Future<void> add({String? name, String? amount});
}

/// قائمة مشتركة عبر جدول Google Sheets و Apps Script (انظر tools/DONORS_SETUP.md).
class SheetsDonorsRepository implements DonorsRepository {
  final String url;
  SheetsDonorsRepository(this.url);

  List<Donor> _parse(String body) => [
        for (final r in jsonDecode(body) as List)
          Donor(
            name: r['name'] as String,
            amount: r['amount'] as String,
            date: DateTime.tryParse(r['date'] as String) ?? DateTime.now(),
          ),
      ];

  @override
  Future<List<Donor>> donors() async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return _parse(utf8.decode(res.bodyBytes));
  }

  @override
  Future<void> add({String? name, String? amount}) async {
    final uri = Uri.parse(url).replace(queryParameters: {
      'action': 'add',
      'name': name ?? '',
      'amount': amount ?? '',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  }
}

/// بديل للتجربة قبل ربط الجدول: يحفظ في الذاكرة على هذا الجهاز فقط.
class InMemoryDonorsRepository implements DonorsRepository {
  final _list = <Donor>[];

  @override
  Future<List<Donor>> donors() async => List.unmodifiable(_list.reversed);

  @override
  Future<void> add({String? name, String? amount}) async =>
      _list.add(Donor(name: name ?? '', amount: amount ?? '', date: DateTime.now()));
}

final DonorsRepository donorsRepository = MosqueConfig.donorsUrl.isEmpty
    ? InMemoryDonorsRepository()
    : SheetsDonorsRepository(MosqueConfig.donorsUrl);
