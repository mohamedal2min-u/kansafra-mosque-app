import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../donors/donors_repository.dart';
import 'history_api.dart';
import 'identity.dart';

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

  void _reload() => setState(() => _future = fetchHistory());

  Future<void> _toggleSignIn() async {
    try {
      if (_id.user == null) {
        await _id.signIn();
        if (mounted && _id.movedOnSignIn > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('نُقل سجلّك (${_id.movedOnSignIn}) إلى حسابك.')),
          );
        }
      } else {
        await _id.signOut();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر الدخول بحساب Google.')));
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
          bottom: const TabBar(tabs: [Tab(text: 'تبرعاتي'), Tab(text: 'رسائلي')]),
        ),
        body: Column(children: [
          ListenableBuilder(
            listenable: _id,
            builder: (context, _) => Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.account_circle),
                title: Text(_id.user?.email ?? 'سجلّك محفوظ على هذا الجهاز'),
                subtitle: Text(_id.googleEnabled
                    ? (_id.user == null ? 'ادخل بحساب Google وينتقل سجلّ هذا الهاتف إلى حسابك لتراه من أي جهاز.' : 'سجلك مرتبط بحسابك.')
                    : 'لا حاجة لتسجيل دخول.'),
                trailing: _id.googleEnabled
                    ? TextButton(onPressed: _toggleSignIn, child: Text(_id.user == null ? 'دخول' : 'خروج'))
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
                      const Text('تعذّر تحميل السجل. تحقّق من الإنترنت.'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                    ]),
                  );
                }
                final h = snap.data!;
                return TabBarView(children: [_Donations(h.donations), _Messages(h.messages)]);
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
    if (items.isEmpty) return const Center(child: Text('لا توجد تبرعات مسجّلة بعد.'));
    final total = items.fold<double>(0, (s, d) => s + parseAmount(d.amount));
    return ListView(children: [
      ListTile(
        title: const Text('مجموع تبرعاتك'),
        trailing: Text(total == total.roundToDouble() ? '${total.toInt()}' : total.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleLarge),
      ),
      const Divider(),
      for (final d in items)
        ListTile(
          leading: const Icon(Icons.volunteer_activism),
          title: Text(d.amount.isEmpty ? 'تبرّعت' : 'تبرّعت بـ ${d.amount}'),
          subtitle: Text('${_when(d.date)}${d.name.isEmpty ? '' : ' • ${d.name}'}'),
        ),
    ]);
  }
}

class _Messages extends StatelessWidget {
  final List<MyMessage> items;
  const _Messages(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('لا توجد رسائل دعم بعد.'));
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final m in items)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m.type} • ${_when(m.date)}', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(m.message),
              const SizedBox(height: 8),
              if (m.reply.isEmpty)
                Text('بانتظار الرد', style: TextStyle(color: scheme.outline))
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('رد المسجد${m.replyDate == null ? '' : ' • ${_when(m.replyDate!)}'}',
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
