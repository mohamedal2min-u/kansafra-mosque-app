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
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const MethodsPage()));
    if (mounted) setState(() => _listKey = UniqueKey());
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
            foregroundColor: Colors.white,
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
          const _TrustRow(),
          const SizedBox(height: 8),
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
            'تظهر أسماء المتبرعين ومبالغهم في القائمة بعد تأكيد إدارة المسجد وصول الدفع، ولا يكتبها المتبرع بنفسه.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ثلاث نقاط ثقة صادقة: التطبيق لا يعالج الدفع ولا يحفظ بيانات البطاقة، والاسم اختياري.
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget item(IconData icon, String text) => Expanded(
          child: Column(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: scheme.primaryContainer,
              child: Icon(icon, color: scheme.primary, size: 26),
            ),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      item(Icons.shield_rounded, 'لا نحفظ بيانات بطاقتك'),
      item(Icons.lock_rounded, 'اسمك اختياري'),
      item(Icons.verified_rounded, 'قائمة المتبرعين معلنة'),
    ]);
  }
}
