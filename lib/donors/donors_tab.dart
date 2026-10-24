import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'donors_repository.dart';

class DonorsTab extends StatefulWidget {
  const DonorsTab({super.key});

  @override
  State<DonorsTab> createState() => _DonorsTabState();
}

class _DonorsTabState extends State<DonorsTab> {
  late Future<List<Donor>> _future = donorsRepository.approvedDonors();

  Future<void> _openForm() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _DonorForm(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جزاك الله خيرًا. سيظهر اسمك بعد تأكيد إدارة المسجد.')),
      );
      setState(() => _future = donorsRepository.approvedDonors());
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
      body: FutureBuilder<List<Donor>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا يوجد متبرعون بعد.\nبعد تبرعك اضغط «سجّل تبرعي» لتظهر باسمك أو كفاعل خير.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: list.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: Text(list[i].displayName),
              trailing: Text(DateFormat.yMMMd('ar').format(list[i].date)),
            ),
          );
        },
      ),
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
  bool _anonymous = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await donorsRepository.submit(name: _anonymous ? null : _name.text.trim());
    if (mounted) Navigator.of(context).pop(true);
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
        const SizedBox(height: 16),
        FilledButton(
          onPressed: canSend && !_busy ? _submit : null,
          child: const Text('إرسال'),
        ),
      ]),
    );
  }
}
