import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../donors/donors_tab.dart';

/// صفحة التبرعات: قائمة المتبرعين (الأعلى ثم الأحدث) وزر «تبرع الآن» ثابت أسفلها.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  Key _listKey = UniqueKey();

  Future<void> _donate() async {
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MethodsPage()));
    if (sent == true && mounted) setState(() => _listKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(child: DonorsList(key: _listKey)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), // مسافة فوق الزر الأوسط البارز
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.tertiary,
            foregroundColor: const Color(0xFF14301F),
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: _donate,
          icon: const Icon(Icons.favorite),
          label: const Text('تبرع الآن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }
}

/// طرق التبرع (شام كاش وبطاقات وPayPal) وزر تسجيل التبرع لتظهر في القائمة.
class MethodsPage extends StatelessWidget {
  const MethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طرق التبرع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'ساهم في إعمار المسجد وخدمة أهل البلدة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final m in MosqueConfig.donationMethods)
            Card(
              child: ListTile(
                leading: m.logo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(m.logo!, width: 64, height: 40, fit: BoxFit.cover, cacheWidth: 160),
                      )
                    : CircleAvatar(
                        backgroundColor: Color(m.color),
                        foregroundColor: Colors.white,
                        child: Text(m.badge, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                title: Text(m.title),
                subtitle: Text(m.details.isEmpty ? 'تُضاف بيانات الحساب قريبًا' : m.details),
                trailing: m.details.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: 'نسخ',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: m.details));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ')));
                        },
                      ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'بعد التبرع سجّله هنا لتظهر في قائمة المتبرعين باسمك أو كفاعل خير.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: () async {
              final sent = await showDonorForm(context);
              if (sent && context.mounted) Navigator.of(context).pop(true);
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('سجّلت تبرعي'),
          ),
        ),
      ),
    );
  }
}
