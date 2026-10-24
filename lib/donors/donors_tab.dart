import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import 'donors_repository.dart';

class DonorsTab extends StatefulWidget {
  const DonorsTab({super.key});

  @override
  State<DonorsTab> createState() => _DonorsTabState();
}

String _when(DateTime d) {
  final l = d.toLocal();
  return '${DateFormat.yMMMd('ar').format(l)} - ${DateFormat.jm('ar').format(l)}';
}

class _DonorsTabState extends State<DonorsTab> {
  late Future<List<Donor>> _future = donorsRepository.donors();

  void _reload() => setState(() => _future = donorsRepository.donors());

  Future<void> _openForm() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DonorForm(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جزاك الله خيرًا وتقبّل منك')));
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.favorite),
        label: const Text('سجّل تبرعي'),
      ),
      body: Column(children: [
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
                    child: Text('لا يوجد متبرعون بعد.\nاضغط «سجّل تبرعي» لتظهر باسمك أو كفاعل خير.',
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
                        leading: const Icon(Icons.volunteer_activism),
                        title: Text(d.line),
                        subtitle: Text(_when(d.date)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _DonorForm extends StatefulWidget {
  const _DonorForm();

  @override
  State<_DonorForm> createState() => _DonorFormState();
}

class _DonorFormState extends State<_DonorForm> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  bool _anonymous = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await donorsRepository.add(
        name: _anonymous ? null : _name.text.trim(),
        amount: _amount.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'تعذّر الإرسال. تحقّق من الإنترنت وأعد المحاولة.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _anonymous || _name.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          title: const Text('أتبرع باسم «فاعل خير»'),
          value: _anonymous,
          onChanged: (v) => setState(() => _anonymous = v),
        ),
        if (!_anonymous)
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم الذي يظهر في القائمة'),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          decoration: const InputDecoration(labelText: 'المبلغ (اختياري)'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: canSend && !_busy ? _submit : null,
          child: const Text('إرسال'),
        ),
      ]),
    );
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
