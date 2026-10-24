import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
          for (final m in MosqueConfig.donationMethods) _MethodCard(m),
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

const _launcher = MethodChannel('kansafra/launcher');

/// ينسخ رقم الحساب ثم يحاول فتح شام كاش. إن لم يُفتح يطلب من المستخدم فتحه ولصق الرقم.
Future<void> _openShamCash(BuildContext context, DonationMethod m) async {
  await Clipboard.setData(ClipboardData(text: m.details));
  var opened = false;
  if (!kIsWeb && MosqueConfig.shamCashPackages.isNotEmpty) {
    try {
      opened = await _launcher.invokeMethod<bool>('openApp', {'packages': MosqueConfig.shamCashPackages}) ?? false;
    } catch (_) {}
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('افتح تطبيق شام كاش وامسح الرمز، أو الصق رقم الحساب (نُسخ تلقائيًا) في خانة التحويل.'),
      duration: Duration(seconds: 6),
    ));
  }
}

class _MethodCard extends StatelessWidget {
  final DonationMethod m;
  const _MethodCard(this.m);

  Widget _leading() => m.logo != null
      ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(m.logo!, width: 64, height: 40, fit: BoxFit.cover, cacheWidth: 160),
        )
      : CircleAvatar(
          backgroundColor: Color(m.color),
          foregroundColor: Colors.white,
          child: Text(m.badge, style: const TextStyle(fontWeight: FontWeight.bold)),
        );

  @override
  Widget build(BuildContext context) {
    if (m.details.isEmpty) {
      return Card(
        child: ListTile(
          leading: _leading(),
          title: Text(m.title),
          subtitle: const Text('تُضاف بيانات الحساب قريبًا'),
        ),
      );
    }
    // طريقة جاهزة: تُفتح بالضغط لعرض الحساب والـ QR.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: _leading(),
        title: Text(m.title),
        subtitle: m.holder == null ? null : Text('باسم: ${m.holder}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SizedBox(height: 10),
          const Text('اضغط الزر ليُفتح تطبيق شام كاش، ثم الصق رقم الحساب (نُسخ تلقائيًا) واكتب المبلغ:', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => _openShamCash(context, m),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('افتح شام كاش وتبرّع'),
          ),
        ],
      ),
    );
  }
}
