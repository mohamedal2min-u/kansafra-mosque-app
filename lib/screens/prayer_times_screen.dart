import '../quran/khatma.dart';
import '../quran/player.dart';
import '../quran/radio_screen.dart';
import '../quran/radios.dart';
import '../quran/quran_data.dart';
import '../quran/reader_screen.dart';
import '../quran/reading_stats.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

import '../flavor.dart';
import '../services/adhan_service.dart';
import '../services/home_place.dart';
import '../services/prayer_calc.dart';
import '../services/travel_watch.dart';
import '../widgets/hero_banner.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  static const _order = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
  static const _labels = {'sunrise': 'الشروق', ...PrayerCalc.names};
  static const _icons = {
    'fajr': Icons.nightlight_round,
    'sunrise': Icons.wb_twilight_rounded,
    'dhuhr': Icons.wb_sunny_rounded,
    'asr': Icons.sunny,
    'maghrib': Icons.nights_stay_rounded,
    'isha': Icons.bedtime_rounded,
  };

  Timer? _timer;
  // العدّاد يتحدّث بدون إعادة بناء الشاشة كلها، فيبقى الاستهلاك قليلًا.
  final _countdown = ValueNotifier<String>('');
  late String _dayKey;
  late Map<String, DateTime> _today; // كنصفرة
  Map<String, DateTime>? _homeToday; // مكان السكن (إن حُدّد)
  late String _nextKey;
  late DateTime _nextTime;
  bool _locateLater = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HijriCalendar.setLocal('ar');
    HomePlace.site.addListener(_placeChanged);
    _compute(DateTime.now());
    _tick();
    _start();
  }

  void _placeChanged() {
    _compute(DateTime.now());
    _tick();
    if (mounted) setState(() {});
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  // لا مؤقت والتطبيق في الخلفية.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tick();
      _start();
      TravelWatch.check(); // مرة كل 3 ساعات على الأكثر
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomePlace.site.removeListener(_placeChanged);
    _timer?.cancel();
    _countdown.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

  /// يحسب مواقيت اليوم مرة واحدة، ويُعاد الحساب عند تغيّر اليوم أو بعد مرور الصلاة القادمة فقط.
  /// كل الأوقات لحظات حقيقية؛ العرض بتوقيت كل مكان عبر wall. الصلاة القادمة والعدّاد
  /// لمكان الأذان: مكان السكن إن حُدّد، وإلا كنصفرة.
  /// العمود الأساسي: كنصفرة في تطبيق المسجد، ومكان المستخدم في «رفيق المسلم».
  PrayerSite get _base =>
      AppFlavor.general ? HomePlace.active : PrayerSite.mosque;

  void _compute(DateTime now) {
    final home = HomePlace.site.value;
    _dayKey = _key(now);
    _today = _base.day(_base.wall(now)) ?? PrayerCalc.day(PrayerCalc.wall(now));
    // عمود كنصفرة بجانب مكان السكن: في تطبيق المسجد فقط.
    _homeToday = AppFlavor.general ? null : home?.day(home.now());
    final (k, t) = HomePlace.active.next(now) ?? PrayerCalc.next(now);
    _nextKey = k;
    _nextTime = t;
  }

  String _key(DateTime now) =>
      '${_ymd(_base.wall(now))}|${_ymd(HomePlace.site.value?.wall(now) ?? now)}';

  void _tick() {
    final now = DateTime.now();
    final sameDay = _key(now) == _dayKey;
    if (!sameDay || !_nextTime.isAfter(now)) {
      final old = _nextKey;
      _compute(now);
      if (mounted && (old != _nextKey || !sameDay)) setState(() {});
    }
    final left = _nextTime.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    _countdown.value =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  Future<void> _confirmHere() async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await TravelWatch.confirmHere();
    messenger.showSnackBar(SnackBar(
        content: Text(err ?? 'حُفظت شبكة كنصفرة. سننبّهك إن ابتعدت عنها.')));
  }

  Future<void> _locate() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('جارٍ تحديد موقعك… (قد يستغرق نصف دقيقة)'),
        duration: Duration(seconds: 45)));
    final err = await HomePlace.locate();
    messenger.hideCurrentSnackBar();
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    try {
      await AdhanService.instance.scheduleAll(force: true);
    } catch (_) {}
    messenger.showSnackBar(SnackBar(
        content: Text('صار الأذان على توقيت ${HomePlace.site.value!.name}')));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.jm('ar');
    final home = HomePlace.site.value;
    // التاريخ بتوقيت مكان السكن إن حُدّد، وإلا بتوقيت المسجد.
    final now = AppFlavor.general
        ? _base.now()
        : (home?.now() ?? PrayerCalc.mosqueNow());
    final h = HijriCalendar.fromDate(now);
    final scheme = Theme.of(context).colorScheme;
    final homeTimes = _homeToday;
    final timeStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);
    final mosqueStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600);
    Widget col(String text, TextStyle? style) => SizedBox(
        width: 76,
        child: Text(text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const HeroBanner(),
        const SizedBox(height: 12),
        Text(
          '${DateFormat.yMMMMEEEEd('ar').format(now)}\n${h.hDay} ${h.longMonthName} ${h.hYear} هـ',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _NextPrayerCard(
            label: _labels[_nextKey]!,
            place: AppFlavor.general
                ? 'بتوقيت ${_base.name}${HomePlace.approximate.value || home == null ? ' (تقريبي)' : ''}'
                : (home == null ? null : 'بتوقيت ${home.name}'),
            countdown: _countdown),
        const _LiveRadioCard(),
        ValueListenableBuilder<bool>(
          valueListenable: TravelWatch.askHere,
          builder: (_, ask, __) => !ask
              ? const SizedBox.shrink()
              : _InfoCard(
                  icon: Icons.home_work_rounded,
                  title: 'هل أنت الآن في كنصفرة؟',
                  text:
                      'نحفظ شبكة الإنترنت التي تستعملها هنا (ولو واي فاي تركيًا). فإن ابتعدت عن كنصفرة يومًا (حلب مثلًا) أو سافرت، نقترح عليك الأذان على توقيت مكانك. يمكنك تغيير ذلك من الإعدادات.',
                  action: 'نعم، أنا في كنصفرة',
                  actionIcon: Icons.check_rounded,
                  onAction: _confirmHere,
                  secondary: 'لا، أنا خارجها',
                  onSecondary: () {
                    TravelWatch.answeredAway();
                    _locate();
                  },
                  dismiss: 'ليس الآن',
                  onDismiss: TravelWatch.answeredAway),
        ),
        ValueListenableBuilder<TravelHint?>(
          valueListenable: TravelWatch.hint,
          builder: (_, h, __) => h == null
              ? const SizedBox.shrink()
              : _InfoCard(
                  icon: Icons.public_rounded,
                  title: h.name.isEmpty
                      ? 'يبدو أنك خارج كنصفرة'
                      : 'أنت في ${h.name}؟',
                  text:
                      'اجعل الأذان على توقيت ${h.name.isEmpty ? 'مكانك' : h.name}، وتبقى مواقيت كنصفرة ظاهرة بجانبه.',
                  action: 'نعم، على توقيت مكاني',
                  actionIcon: Icons.my_location_rounded,
                  onAction: _locate,
                  secondary: h.byNetwork ? 'أنا في كنصفرة' : null,
                  onSecondary: _confirmHere,
                  dismiss: 'لا، شكرًا',
                  onDismiss: TravelWatch.dismiss),
        ),
        if (AppFlavor.general &&
            !_locateLater &&
            (home == null || HomePlace.approximate.value))
          _InfoCard(
              icon: Icons.wifi_rounded,
              title: 'مواقيت دقيقة لمكانك',
              text: home == null
                  ? 'المواقيت الآن لمكة المكرمة. حدّد موقعك (من الواي فاي، بلا GPS) لتصير المواقيت والأذان لمدينتك. يبقى موقعك على هاتفك.'
                  : 'المواقيت لـ${home.name} بشكل تقريبي. حدّد موقعك (من الواي فاي، بلا GPS) لمواقيت أدق. يبقى موقعك على هاتفك.',
              action: 'تحديد موقعي',
              actionIcon: Icons.my_location_rounded,
              onAction: _locate,
              dismiss: 'لاحقًا',
              onDismiss: () => setState(() => _locateLater = true)),
        const _ResumeReadingCard(),
        const SizedBox(height: 6),
        if (homeTimes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              col(
                  home!.name,
                  Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w700)),
              col('كنصفرة', Theme.of(context).textTheme.labelMedium),
            ]),
          ),
        for (final k in _order)
          Card(
            color: k == _nextKey ? scheme.primaryContainer : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: k == _nextKey
                    ? scheme.tertiary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: k == _nextKey ? 1.6 : 1,
              ),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor:
                    k == _nextKey ? scheme.tertiary : scheme.primaryContainer,
                child: Icon(_icons[k],
                    color: k == _nextKey ? Colors.white : scheme.primary,
                    size: 22),
              ),
              title: Text(_labels[k]!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              subtitle: k == _nextKey ? const Text('الصلاة القادمة') : null,
              trailing: homeTimes == null
                  ? Text(fmt.format(_base.wall(_today[k]!)), style: timeStyle)
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      col(fmt.format(home!.wall(homeTimes[k]!)), timeStyle),
                      col(fmt.format(PrayerCalc.wall(_today[k]!)), mosqueStyle),
                    ]),
            ),
          ),
      ],
    );
  }
}

/// بطاقة الصلاة القادمة: تدرّج أخضر مع زخرفة نجمية خفيفة وعدّاد ذهبي.
class _NextPrayerCard extends StatelessWidget {
  final String label;
  final String? place; // «بتوقيت ستوكهولم» حين يكون الأذان على مكان السكن
  final ValueNotifier<String> countdown;
  const _NextPrayerCard(
      {required this.label, this.place, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1C6B45), Color(0xFF0A3B25)],
          ),
        ),
        child: CustomPaint(
          painter: _StarPatternPainter(),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Text('الصلاة القادمة',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
              if (place != null)
                Text(place!,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13)),
              const SizedBox(height: 6),
              ValueListenableBuilder<String>(
                valueListenable: countdown,
                builder: (_, v, __) => Text(
                  v,
                  style: const TextStyle(
                    color: Color(0xFFF1D58A),
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const step = 46.0;
    for (var y = 0.0; y < size.height + step; y += step) {
      for (var x = 0.0; x < size.width + step; x += step) {
        final c = Offset(x, y);
        // نجمة ثمانية من مربعين متداخلين
        for (var k = 0; k < 2; k++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = math.pi / 4 * (k * 1) + math.pi / 2 * i;
            final p = c + Offset(math.cos(a), math.sin(a)) * 16;
            i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// بطاقة اقتراح في الرئيسية: عنوان ونص وزر تنفيذ، وزر ثانٍ اختياري، وزر إخفاء.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final IconData actionIcon;
  final VoidCallback onAction;
  final String? secondary;
  final VoidCallback? onSecondary;
  final String dismiss;
  final VoidCallback onDismiss;
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.action,
      required this.actionIcon,
      required this.onAction,
      this.secondary,
      this.onSecondary,
      required this.dismiss,
      required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.tertiary),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: cs.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(text),
          const SizedBox(height: 6),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(action),
                ),
                if (secondary != null)
                  OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42)),
                      onPressed: onSecondary,
                      child: Text(secondary!)),
                TextButton(onPressed: onDismiss, child: Text(dismiss)),
              ]),
        ]),
      ),
    );
  }
}

/// البث المباشر في الرئيسية: إذاعتا القرآن الكريم (القاهرة والسعودية) بضغطة، وباقي الإذاعات من «المزيد».
class _LiveRadioCard extends StatelessWidget {
  const _LiveRadioCard();

  static const _short = {-1: 'القاهرة', -2: 'السعودية'};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = QuranPlayer.instance;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => Row(children: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('مباشر',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text('إذاعة القرآن',
                  style: Theme.of(context).textTheme.labelSmall),
            ]),
            const SizedBox(width: 8),
            for (final st in RadioApi.featured)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _StationButton(
                    label: _short[st.id] ?? st.name,
                    on: p.radio?.url == st.url && p.playing,
                    onTap: () => p.radio?.url == st.url
                        ? (p.playing ? p.stop() : p.toggle())
                        : p.playRadio(st),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'كل الإذاعات',
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('البث المباشر')),
                    body: const RadioScreen()),
              )),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StationButton extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _StationButton(
      {required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: on ? cs.primary : cs.primaryContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 22, color: on ? Colors.white : cs.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : cs.onPrimaryContainer)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// متابعة القراءة: تظهر في الرئيسية إن وضع المستخدم علامة في المصحف، وتفتح من آخر آية وصل إليها.
class _ResumeReadingCard extends StatefulWidget {
  const _ResumeReadingCard();

  @override
  State<_ResumeReadingCard> createState() => _ResumeReadingCardState();
}

class _ResumeReadingCardState extends State<_ResumeReadingCard> {
  @override
  void initState() {
    super.initState();
    Future.wait([Khatma.instance.load(), ReadingStats.instance.load()])
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _open(Bookmark m) async {
    await QuranData.load(); // النص مضمّن، ويُحمَّل مرة واحدة
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SurahReaderScreen(surah: m.surah, initialVerse: m.verse),
    ));
    if (mounted) setState(() {}); // تحديث وقت اليوم بعد العودة
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<Bookmark?>(
      valueListenable: Khatma.instance.mark,
      builder: (context, m, _) {
        if (m == null) return const SizedBox.shrink();
        final today = ReadingStats.instance.today;
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _open(m),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: cs.tertiary,
                    child:
                        const Icon(Icons.bookmark_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('تابع قراءتك',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onPrimaryContainer)),
                          const SizedBox(height: 2),
                          Text(m.label,
                              style: TextStyle(color: cs.onPrimaryContainer)),
                          if (today >= 60)
                            Text('قرأتَ اليوم ${ReadingStats.format(today)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: cs.onPrimaryContainer
                                            .withValues(alpha: 0.8))),
                        ]),
                  ),
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: cs.onPrimaryContainer),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
