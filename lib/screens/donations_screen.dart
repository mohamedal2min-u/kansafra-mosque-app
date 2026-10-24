import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              title: Text(m.title),
              subtitle: Text(m.details),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'نسخ',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: m.details));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم النسخ')),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
