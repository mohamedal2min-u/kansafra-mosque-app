import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account/account_screen.dart';
import 'account/identity.dart';
import 'config.dart';
import 'services/adhan_service.dart';
import 'quran/quran_home.dart';
import 'screens/donations_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'screens/prayer_times_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // التنبيهات مدعومة على أندرويد وآيفون فقط؛ على الويب/الكمبيوتر نعرض الواجهة فقط.
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    // بعد أول إطار حتى لا يؤخّر طلب الأذونات فتح التطبيق.
    WidgetsBinding.instance.addPostFrameCallback((_) => AdhanService.instance.init());
  }
  Identity.instance.restore();
  runApp(const MosqueApp());
}

class MosqueApp extends StatelessWidget {
  const MosqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: MosqueConfig.name,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1B5E20),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _pages = [PrayerTimesScreen(), QuranHome(), SupportScreen(), DonationsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(MosqueConfig.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'حسابي',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.access_time), label: 'الأذان'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'القرآن'),
          NavigationDestination(icon: Icon(Icons.support_agent), label: 'الدعم'),
          NavigationDestination(icon: Icon(Icons.volunteer_activism), label: 'التبرعات'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
