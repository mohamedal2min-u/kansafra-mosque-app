import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import 'donors_repository.dart';

class DonorsList extends StatefulWidget {
  const DonorsList({super.key});

  @override
  State<DonorsList> createState() => _DonorsListState();
}

String _when(DateTime d) {
  final l = d.toLocal();
  return '${DateFormat.yMMMd('ar').format(l)} - ${DateFormat.jm('ar').format(l)}';
}

class _DonorsListState extends State<DonorsList> {
  late Future<List<Donor>> _future = donorsRepository.donors();

  void _reload() => setState(() => _future = donorsRepository.donors());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
        if (MosqueConfig.donorsUrl.isEmpty)
          const MaterialBanner(
            content: Text('وضع تجريبي: الأسماء تظهر على هذا الجهاز فقط حتى يُربط الجدول المشترك.'),
            actions: [SizedBox.shrink()],
          ),
        Expanded(
          child: FutureBuilder<List<Donor>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('تعذّر تحميل القائمة. تحقّق من الإنترنت.'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                  ]),
                );
              }
              // الأحدث أولًا.
              final list = [...snap.data!]..sort((a, b) => b.date.compareTo(a.date));
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا يوجد متبرعون بعد.\nتظهر الأسماء هنا بعد تأكيد إدارة المسجد وصول التبرع.',
                        textAlign: TextAlign.center),
                  ),
                );
              }
              final top = topDonors(list);
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (top.isNotEmpty) _TopDonors(top),
                    if (top.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Text('آخر التبرعات', style: Theme.of(context).textTheme.titleSmall),
                      ),
                    for (final d in list)
                      ListTile(
                        leading: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.tertiary),
                        title: Text(d.line),
                        subtitle: Text(_when(d.date)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
    ]);
  }
}

/// أعلى ثلاثة متبرعين: نجمة ذهبية وفضية وبرونزية.
class _TopDonors extends StatelessWidget {
  final List<TopDonor> top;
  const _TopDonors(this.top);

  static const _colors = [Color(0xFFE2B33C), Color(0xFF9AA3AD), Color(0xFFB4783F)];
  static const _titles = ['المركز الأول', 'المركز الثاني', 'المركز الثالث'];

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          Text('أعلى المتبرعين', style: Theme.of(context).textTheme.titleMedium),
          for (var i = 0; i < top.length; i++)
            ListTile(
              leading: Icon(Icons.star, size: 36, color: _colors[i]),
              title: Text(top[i].name),
              subtitle: Text('${_titles[i]} • ${top[i].count == 1 ? 'تبرع واحد' : '${top[i].count} تبرعات'}'),
              trailing: Text(_fmt(top[i].total), style: Theme.of(context).textTheme.titleMedium),
            ),
        ]),
      ),
    );
  }
}
