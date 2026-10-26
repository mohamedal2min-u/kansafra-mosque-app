import 'package:flutter/material.dart';

import '../config.dart';
import '../launcher.dart';

/// صفحة المساعدة والدعم: المحادثة مع المسجد عبر ماسنجر (صفحة المسجد على فيسبوك).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(MosqueConfig.name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('المساعدة والدعم',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 20),
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Icon(Icons.chat_rounded,
                  size: 44, color: Color(0xFF0084FF)),
              const SizedBox(height: 8),
              Text('تحدّث معنا مباشرة',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'للاستفسار أو الاقتراح أو الإبلاغ عن مشكلة، راسل المسجد عبر ماسنجر.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              if (Launcher.supported)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0084FF),
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('فتح المحادثة في ماسنجر'),
                    onPressed: () => Launcher.openWithFeedback(
                        context, MosqueConfig.messengerUrl,
                        packages: MosqueConfig.messengerPackages,
                        appUrl: MosqueConfig.messengerAppUrl,
                        label: 'ماسنجر'),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (Launcher.supported)
          Card(
            child: ListTile(
              leading: const Icon(Icons.facebook,
                  color: Color(0xFF1877F2), size: 36),
              title: const Text('تابعنا على فيسبوك'),
              subtitle: const Text('أخبار المسجد ومواعيده'),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => Launcher.openWithFeedback(
                  context, MosqueConfig.facebookUrl,
                  packages: MosqueConfig.facebookPackages,
                  appUrl: MosqueConfig.facebookAppUrl,
                  label: 'صفحة فيسبوك'),
            ),
          ),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'أوقات الأذان والقرآن تعمل بدون إنترنت. الاستماع للقرآن وقائمة المتبرعين يحتاجان إنترنت.\n'
              'إن لم يصلك تنبيه الأذان، اسمح للتطبيق بالإشعارات والتنبيهات الدقيقة من إعدادات الهاتف.',
            ),
          ),
        ),
      ],
    );
  }
}
