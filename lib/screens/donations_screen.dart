import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../donors/donors_tab.dart';

class DonationsScreen extends StatelessWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: const [
        TabBar(tabs: [Tab(text: 'طرق التبرع'), Tab(text: 'المتبرعون')]),
        Expanded(child: TabBarView(children: [_Methods(), DonorsTab()])),
      ]),
    );
  }
}

class _Methods extends StatelessWidget {
  const _Methods();

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
              leading: m.logo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(m.logo!, width: 64, height: 40, fit: BoxFit.cover),
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
