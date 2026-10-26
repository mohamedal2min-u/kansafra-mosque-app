import 'package:flutter/material.dart';

import '../launcher.dart';

/// شرح السماح للتطبيق بالعمل في الخلفية: بدونه يوقف توفير البطارية القرآن والبث بعد إطفاء الشاشة.
Future<void> showBackgroundHelp(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.battery_saver_rounded),
        title: const Text('ليستمر الصوت والشاشة مطفأة'),
        content: const Text(
            'هاتفك يقيّد التطبيق لتوفير البطارية، فقد يتوقف القرآن أو البث بعد إطفاء الشاشة.\n\n'
            'افتح إعدادات التطبيق ← البطارية ← اختر «غير مقيّد».\n\n'
            'وفي هواتف سامسونج أيضًا: الإعدادات ← البطارية ← حدود الاستخدام في الخلفية، '
            'وتأكد أن التطبيق ليس في «التطبيقات النائمة» أو «النائمة بعمق».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('لاحقًا')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () {
              Navigator.pop(ctx);
              Launcher.openAppDetails();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
