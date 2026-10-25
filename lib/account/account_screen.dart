import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../donors/donors_repository.dart';
import 'history_api.dart';
import 'identity.dart';
import '../quran/reading_stats.dart';

String _when(DateTime d) {
  final l = d.toLocal();
  return '${DateFormat.yMMMd('ar').format(l)} - ${DateFormat.jm('ar').format(l)}';
}

/// «حسابي»: سجل تبرعاتي ومحادثات الدعم، مع دخول Google اختياري.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<History> _future = fetchHistory();
  final _id = Identity.instance;

  static String _errorText(Object? e) {
    if (e is HistoryException) {
      switch (e.reason) {
        case 'auth':
          return 'تعذّر التحقق من حساب Google. سجّل الخروج ثم ادخل من جديد.';
        case 'server':
          return 'خادم السجل لم يردّ بشكل صحيح. أبلغ إدارة التطبيق ليُحدَّث السكربت (إذن الاتصال الخارجي).';
        case 'old':
          return 'خادم السجل بنسخة قديمة. أبلغ إدارة التطبيق ليُحدَّث السكربت.';
      }
    }
    return 'تعذّر تحميل السجل. تحقّق من الإنترنت.';
  }

  void _reload() => setState(() => _future = fetchHistory());

  Future<void> _toggleSignIn() async {
    try {
      if (_id.user == null) {
        await _id.signIn();
        if (mounted && _id.movedOnSignIn > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('نُقل سجلّك (${_id.movedOnSignIn}) إلى حسابك.')),
          );
        }
      } else {
        await _id.signOut();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر الدخول بحساب Google.')));
      }
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حسابي'),
          bottom:
              const TabBar(tabs: [Tab(text: 'تبرعاتي'), Tab(text: 'رسائلي')]),
        ),
        body: Column(children: [
          const _ReadingCard(),
          ListenableBuilder(
            listenable: _id,
            builder: (context, _) => Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: _id.user?.photoUrl == null
                    ? const Icon(Icons.account_circle, size: 40)
                    : CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(_id.user!.photoUrl!)),
                title: Text(_id.user?.displayName ??
                    _id.user?.email ??
                    'سجلّك محفوظ على هذا الجهاز'),
                subtitle: Text(_id.googleEnabled
                    ? (_id.user == null
                        ? 'ادخل بحساب Google وينتقل سجلّ هذا الهاتف إلى حسابك لتراه من أي جهاز.'
                        : '${_id.user!.email} • سجلك مرتبط بحسابك.')
                    : 'لا حاجة لتسجيل دخول.'),
                trailing: _id.googleEnabled
                    ? TextButton(
                        onPressed: _toggleSignIn,
                        child: Text(_id.user == null ? 'دخول' : 'خروج'))
                    : null,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<History>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_errorText(snap.error),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: FilledButton(
                              onPressed: _reload,
                              child: const Text('إعادة المحاولة'))),
                    ]),
                  );
                }
                final h = snap.data!;
                return TabBarView(
                    children: [_Donations(h.donations), _Messages(h.messages)]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Donations extends StatelessWidget {
  final List<MyDonation> items;
  const _Donations(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('تظهر تبرعاتك هنا بعد تأكيد إدارة المسجد وصول الدفع.',
              textAlign: TextAlign.center),
        ),
      );
    }
    final total = items.fold<double>(0, (s, d) => s + parseAmount(d.amount));
    return ListView(children: [
      ListTile(
        title: const Text('مجموع تبرعاتك'),
        trailing: Text(
            total == total.roundToDouble()
                ? '${total.toInt()}'
                : total.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleLarge),
      ),
      const Divider(),
      for (final d in items)
        ListTile(
          leading: Icon(Icons.favorite_rounded,
              color: Theme.of(context).colorScheme.tertiary),
          title: Text(d.amount.isEmpty ? 'تبرّعت' : 'تبرّعت بـ ${d.amount}'),
          subtitle:
              Text('${_when(d.date)}${d.name.isEmpty ? '' : ' • ${d.name}'}'),
        ),
    ]);
  }
}

class _Messages extends StatelessWidget {
  final List<MyMessage> items;
  const _Messages(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('لا توجد رسائل دعم بعد.'));
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final m in items)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.type} • ${_when(m.date)}',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(m.message),
              const SizedBox(height: 8),
              if (m.reply.isEmpty)
                Text('بانتظار الرد', style: TextStyle(color: scheme.outline))
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'رد المسجد${m.replyDate == null ? '' : ' • ${_when(m.replyDate!)}'}',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(m.reply),
                      ]),
                ),
            ]),
          ),
        ),
    ]);
  }
}

/// وقت قراءة القرآن في المصحف: اليوم وهذا الأسبوع والإجمالي وأيام القراءة المتتالية.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<void>(
      future: ReadingStats.instance.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const SizedBox.shrink();
        final st = ReadingStats.instance;
        final week = st.lastWeek;
        final maxV = week.fold<int>(1, (a, b) => b > a ? b : a);
        Widget stat(String label, String value) => Expanded(
              child: Column(children: [
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ]),
            );
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_stories_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text('وقت قراءتي للقرآن',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                stat('اليوم', ReadingStats.format(st.today)),
                stat('هذا الشهر', ReadingStats.format(st.thisMonth)),
                stat('هذه السنة', ReadingStats.format(st.thisYear)),
                stat('الإجمالي', ReadingStats.format(st.total)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final v in week)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Container(
                          height: 4 + 32 * (v / maxV),
                          decoration: BoxDecoration(
                            color: v == 0 ? cs.outlineVariant : cs.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              if (st.streak > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      '${st.streak} ${st.streak == 1 ? 'يوم' : 'أيام'} متتالية من القراءة',
                      style: TextStyle(
                          color: cs.tertiary, fontWeight: FontWeight.w700)),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('يُحسب الوقت وشاشة القراءة مفتوحة والتطبيق أمامك.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// تفاصيل وقت القراءة: لكل يوم (آخر 30 يومًا) ولكل شهر ولكل سنة.
class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  int _mode = 0; // 0 يومي، 1 شهري، 2 سنوي

  @override
  Widget build(BuildContext context) {
    final st = ReadingStats.instance;
    final rows = <(String, int)>[];
    if (_mode == 0) {
      for (final e in st.lastDays(30)) {
        rows.add((DateFormat.yMMMEd('ar').format(e.key), e.value));
      }
    } else if (_mode == 1) {
      for (final e in st.monthList) {
        rows.add(('${_months[e.key.$2 - 1]} ${e.key.$1}', e.value));
      }
    } else {
      for (final e in st.yearList) {
        rows.add(('${e.key}', e.value));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('وقت قراءتي للقرآن')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('يومي')),
              ButtonSegment(value: 1, label: Text('شهري')),
              ButtonSegment(value: 2, label: Text('سنوي')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('لا توجد قراءة مسجَّلة بعد.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    title: Text(rows[i].$1),
                    trailing: Text(ReadingStats.format(rows[i].$2),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: rows[i].$2 == 0
                              ? Theme.of(context).disabledColor
                              : null,
                        )),
                  ),
                ),
        ),
      ]),
    );
  }
}
