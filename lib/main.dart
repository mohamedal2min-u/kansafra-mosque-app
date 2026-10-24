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

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B6B3F),
    brightness: b,
    tertiary: const Color(0xFFC9A24A), // ذهبي للتبرع والتمييز
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 19, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
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
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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
  // 0 الأذان، 1 القرآن، 2 التبرعات (الزر الأوسط البارز)، 3 الدعم، 4 الإعدادات
  int _index = 0;
  static const _pages = [PrayerTimesScreen(), QuranHome(), DonationsScreen(), SupportScreen(), SettingsScreen()];
  static const _donate = 2;

  Widget _item(int i, IconData icon, String label) {
    final selected = _index == i;
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _index = i),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: selected ? FontWeight.bold : null)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final donating = _index == _donate;
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          heroTag: 'donate',
          shape: const CircleBorder(),
          elevation: donating ? 8 : 4,
          backgroundColor: scheme.tertiary,
          foregroundColor: const Color(0xFF14301F),
          tooltip: 'التبرعات',
          onPressed: () => setState(() => _index = _donate),
          child: const Icon(Icons.volunteer_activism, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(children: [
          _item(0, Icons.access_time, 'الأذان'),
          _item(1, Icons.menu_book, 'القرآن'),
          // مكان الزر الأوسط
          SizedBox(
            width: 84,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('التبرعات',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: donating ? scheme.primary : scheme.onSurfaceVariant)),
              ),
            ),
          ),
          _item(3, Icons.support_agent, 'الدعم'),
          _item(4, Icons.settings, 'الإعدادات'),
        ]),
      ),
    );
  }
}
