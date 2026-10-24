import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'account/account_screen.dart';
import 'account/identity.dart';
import 'config.dart';
import 'settings.dart';
import 'services/adhan_service.dart';
import 'quran/mini_player.dart';
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
  await ThemeController.load();
  Identity.instance.restore();
  runApp(const MosqueApp());
}

const kGreen = Color(0xFF0F5A38);
const kGold = Color(0xFFB8902F);

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  final base = ColorScheme.fromSeed(seedColor: kGreen, brightness: b);
  final scheme = base.copyWith(
    primary: dark ? const Color(0xFF7CD3A6) : kGreen,
    onPrimary: dark ? const Color(0xFF06271A) : Colors.white,
    primaryContainer: dark ? const Color(0xFF1C4A33) : const Color(0xFFD9ECE0),
    onPrimaryContainer: dark ? const Color(0xFFD9ECE0) : const Color(0xFF0A3B25),
    tertiary: dark ? const Color(0xFFE2B957) : kGold,
    surface: dark ? const Color(0xFF0E1A14) : const Color(0xFFF7F3E8),
    onSurface: dark ? const Color(0xFFE8EFEA) : const Color(0xFF1B2A22),
    surfaceContainerHighest: dark ? const Color(0xFF18281F) : Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: 'Tajawal', color: scheme.primary, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: scheme.surfaceContainerHighest, surfaceTintColor: Colors.transparent),
  );
}

class MosqueApp extends StatelessWidget {
  const MosqueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
      themeMode: mode,
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
    ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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
            icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'فاتح / داكن',
            onPressed: () => ThemeController.set(
                Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark),
          ),
          IconButton(
            icon: const _AccountAvatar(),
            tooltip: 'حسابي',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
          ),
        ],
      ),
      body: Column(children: [
        const MiniPlayer(),
        Expanded(child: _pages[_index]),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 68,
        height: 68,
        child: FloatingActionButton(
          heroTag: 'donate',
          shape: const CircleBorder(),
          elevation: donating ? 8 : 4,
          backgroundColor: scheme.tertiary,
          foregroundColor: Colors.white,
          tooltip: 'التبرعات',
          onPressed: () => setState(() => _index = _donate),
          child: const Icon(Icons.volunteer_activism_rounded, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(children: [
          _item(0, Icons.access_time_filled_rounded, 'الأذان'),
          _item(1, Icons.menu_book_rounded, 'القرآن'),
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
          _item(3, Icons.support_agent_rounded, 'الدعم'),
          _item(4, Icons.settings_rounded, 'الإعدادات'),
        ]),
      ),
    );
  }
}

/// أيقونة الحساب أعلى التطبيق: صورة Google الشخصية إن سجّل المستخدم دخوله، وإلا أيقونة عامة.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Identity.instance,
      builder: (context, _) {
        final photo = Identity.instance.user?.photoUrl;
        if (photo == null) return const Icon(Icons.account_circle);
        return CircleAvatar(
          radius: 14,
          backgroundImage: NetworkImage(photo),
          onBackgroundImageError: (_, __) {},
        );
      },
    );
  }
}
