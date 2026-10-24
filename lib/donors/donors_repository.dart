import 'dart:convert';

import 'package:http/http.dart' as http;

import '../account/identity.dart';
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

/// يستخرج أول رقم من نص المبلغ (يدعم الأرقام العربية الهندية). 0 إن لم يوجد.
double parseAmount(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final t = s.split('').map((c) => ar.contains(c) ? '${ar.indexOf(c)}' : c).join().replaceAll(',', '');
  final m = RegExp(r'\d+(\.\d+)?').firstMatch(t);
  return m == null ? 0 : double.parse(m.group(0)!);
}

/// مجموع تبرعات اسم واحد. «فاعل خير» لا يُجمع لأنهم أشخاص مختلفون.
class TopDonor {
  final String name;
  final double total;
  final int count;
  const TopDonor(this.name, this.total, this.count);
}

/// أعلى [n] متبرعين بالمبلغ. الأسماء المتشابهة تُجمع، وفاعل الخير يبقى كل تبرع بمفرده.
List<TopDonor> topDonors(List<Donor> donors, {int n = 3}) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  final entries = <TopDonor>[];
  for (final d in donors) {
    final a = parseAmount(d.amount);
    if (a <= 0) continue;
    final anon = d.name.trim().isEmpty || d.name.trim() == 'فاعل خير';
    if (anon) {
      entries.add(TopDonor('فاعل خير', a, 1));
    } else {
      final k = d.name.trim();
      totals[k] = (totals[k] ?? 0) + a;
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  entries.addAll(totals.entries.map((e) => TopDonor(e.key, e.value, counts[e.key]!)));
  entries.sort((a, b) => b.total.compareTo(a.total));
  return entries.take(n).toList();
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
      ...await Identity.instance.params(),
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
