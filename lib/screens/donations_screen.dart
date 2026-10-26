import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../launcher.dart';
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
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const MethodsPage()));
    if (mounted) setState(() => _listKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(child: DonorsList(key: _listKey)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.tertiary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: _donate,
          icon: const Icon(Icons.favorite),
          label: const Text('تبرع الآن',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
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
            Text(text,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      item(Icons.shield_rounded, 'لا نحفظ بيانات بطاقتك'),
      item(Icons.lock_rounded, 'اسمك اختياري'),
      item(Icons.verified_rounded, 'قائمة المتبرعين معلنة'),
    ]);
  }
}

/// يشرح خطوات التبرع بشام كاش، ثم ينسخ رقم الحساب ويفتح التطبيق.
/// (لا يوجد رابط دفع مباشر معلن من شام كاش؛ الفتح المباشر لصفحة المبلغ يحتاج حساب تاجر رسميًا عندهم.)
Future<void> _openShamCash(BuildContext context, DonationMethod m) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      Widget step(int n, String text) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                  radius: 12,
                  backgroundColor: cs.primary,
                  child: Text('$n',
                      style: TextStyle(color: cs.onPrimary, fontSize: 13))),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ]),
          );
      return AlertDialog(
        title: const Text('التبرع عبر شام كاش'),
        content: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.holder != null)
                          Text('المستلم: ${m.holder}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        SelectableText(m.details,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(fontSize: 13)),
                      ]),
                ),
                const SizedBox(height: 10),
                step(1, 'اضغط «فتح شام كاش». يُنسخ رقم الحساب تلقائيًا.'),
                step(2, 'في شام كاش اختر «Send» ثم «New».'),
                step(3,
                    'الصق رقم الحساب. تأكد أن اسم المستلم يطابق الاسم أعلاه ثم اضغط «Send».'),
                step(4,
                    'اكتب المبلغ، وفي الملاحظة: «تبرع لجامع كنصفرة الكبير».'),
                step(5,
                    'اضغط «Add» لحفظ الحساب في المفضلة، فيصير التبرع القادم بضغطة واحدة.'),
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح شام كاش'),
          ),
        ],
      );
    },
  );
  if (go != true) return;
  await Clipboard.setData(ClipboardData(text: m.details));
  var opened = false;
  if (!kIsWeb && MosqueConfig.shamCashPackages.isNotEmpty) {
    final url = MosqueConfig.shamCashPayUrl.replaceAll('{account}', m.details);
    opened = await Launcher.openApp(MosqueConfig.shamCashPackages,
        url: url.isEmpty ? null : url);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? 'نُسخ رقم الحساب. الصقه في شام كاش.'
          : 'لم نجد تطبيق شام كاش. ثبّته وافتحه، ثم الصق رقم الحساب (نُسخ تلقائيًا).'),
      duration: const Duration(seconds: 6),
    ));
  }
}

class _MethodCard extends StatelessWidget {
  final DonationMethod m;
  const _MethodCard(this.m);

  Widget _leading() => m.logo != null
      ? ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(m.logo!,
              width: 64, height: 40, fit: BoxFit.cover, cacheWidth: 160),
        )
      : CircleAvatar(
          backgroundColor: Color(m.color),
          foregroundColor: Colors.white,
          child: Text(m.badge,
              style: const TextStyle(fontWeight: FontWeight.bold)),
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
          const Text(
              'اضغط الزر ليُفتح تطبيق شام كاش، ثم الصق رقم الحساب (نُسخ تلقائيًا) واكتب المبلغ:',
              textAlign: TextAlign.center),
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
