import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../donors/donors_repository.dart';
import '../quran/reading_stats.dart';
import 'history_api.dart';
import 'identity.dart';

String _when(DateTime d) {
  final l = d.toLocal();
  return '${DateFormat.yMMMd('ar').format(l)} - ${DateFormat.jm('ar').format(l)}';
}

/// «حسابي»: الحساب، ووقت قراءتي للقرآن، وسجل تبرعاتي.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<History> _future = fetchHistory();
  final _id = Identity.instance;

  static String _errorText(Object? e) {
    if (e is HistoryException) {
      switch (e.reason) {
        case 'auth':
          return 'تعذّر التحقق من حساب Google. سجّل الخروج ثم ادخل من جديد.';
        case 'server':
          return 'خادم السجل لم يردّ بشكل صحيح. أبلغ إدارة التطبيق ليُحدَّث السكربت (إذن الاتصال الخارجي).';
        case 'old':
          return 'خادم السجل بنسخة قديمة. أبلغ إدارة التطبيق ليُحدَّث السكربت.';
      }
    }
    return 'تعذّر تحميل السجل. تحقّق من الإنترنت.';
  }

  void _reload() => setState(() => _future = fetchHistory());

  Future<void> _toggleSignIn() async {
    try {
      if (_id.user == null) {
        await _id.signIn();
        if (mounted && _id.movedOnSignIn > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('نُقل سجلّك (${_id.movedOnSignIn}) إلى حسابك.')),
          );
        }
      } else {
        await _id.signOut();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذّر الدخول بحساب Google.')));
      }
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProfileCard(onToggle: _toggleSignIn),
          const SizedBox(height: 16),
          const _ReadingCard(),
          const SizedBox(height: 16),
          _DonationsSection(
              future: _future, onRetry: _reload, errorText: _errorText),
        ],
      ),
    );
  }
}

/// بطاقة الحساب: الصورة والاسم وحالة الدخول وزر الدخول/الخروج.
class _ProfileCard extends StatelessWidget {
  final VoidCallback onToggle;
  const _ProfileCard({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = Identity.instance;
    return ListenableBuilder(
      listenable: id,
      builder: (context, _) {
        final user = id.user;
        final name = user?.displayName ?? user?.email ?? 'زائر';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primary,
                backgroundImage: user?.photoUrl == null
                    ? null
                    : NetworkImage(user!.photoUrl!),
                onBackgroundImageError:
                    user?.photoUrl == null ? null : (_, __) {},
                child: user?.photoUrl == null
                    ? Icon(Icons.person_rounded, size: 36, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onPrimaryContainer)),
                      const SizedBox(height: 2),
                      Text(
                        user == null
                            ? 'سجلّك محفوظ على هذا الهاتف'
                            : (user.email),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                cs.onPrimaryContainer.withValues(alpha: 0.8)),
                      ),
                    ]),
              ),
            ]),
            if (id.googleEnabled) ...[
              const SizedBox(height: 12),
              if (user == null)
                Text(
                    'ادخل بحساب Google لينتقل سجلّ هذا الهاتف إلى حسابك فتراه من أي جهاز.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: user == null
                    ? FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46)),
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('الدخول بحساب Google'),
                        onPressed: onToggle,
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            foregroundColor: cs.onPrimaryContainer),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('تسجيل الخروج'),
                        onPressed: onToggle,
                      ),
              ),
            ],
          ]),
        );
      },
    );
  }
}

/// سجل التبرعات: المجموع ثم القائمة، مع حالة خطأ مضغوطة بدل أن تملأ الصفحة.
class _DonationsSection extends StatelessWidget {
  final Future<History> future;
  final VoidCallback onRetry;
  final String Function(Object?) errorText;
  const _DonationsSection(
      {required this.future, required this.onRetry, required this.errorText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<History>(
      future: future,
      builder: (context, snap) {
        Widget body;
        Widget? trailing;
        var deviceOnly = false;
        if (snap.connectionState != ConnectionState.done) {
          body = const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()));
        } else if (snap.hasError) {
          body = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Row(children: [
                Icon(Icons.cloud_off_rounded, color: cs.error),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(errorText(snap.error),
                        style: Theme.of(context).textTheme.bodyMedium)),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة')),
              ),
            ]),
          );
        } else {
          final items = snap.data!.donations;
          deviceOnly = snap.data!.deviceOnly;
          if (items.isEmpty) {
            body = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16)),
              child: const Text(
                  'تظهر تبرعاتك هنا بعد تأكيد إدارة المسجد وصول الدفع.',
                  textAlign: TextAlign.center),
            );
          } else {
            final total =
                items.fold<double>(0, (s, d) => s + parseAmount(d.amount));
            trailing = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  'المجموع ${total == total.roundToDouble() ? '${total.toInt()}' : total.toStringAsFixed(1)}',
                  style: TextStyle(
                      color: cs.tertiary, fontWeight: FontWeight.w700)),
            );
            body = Column(children: [
              for (final d in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.tertiary.withValues(alpha: 0.16),
                      child: Icon(Icons.favorite_rounded,
                          color: cs.tertiary, size: 20),
                    ),
                    title: Text(
                        d.amount.isEmpty ? 'تبرّعت' : 'تبرّعت بـ ${d.amount}'),
                    subtitle: Text(
                        '${_when(d.date)}${d.name.isEmpty ? '' : ' • ${d.name}'}'),
                  ),
                ),
            ]);
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.volunteer_activism_rounded, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text('تبرعاتي',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (trailing != null) trailing,
          ]),
          const SizedBox(height: 10),
          if (deviceOnly)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cs.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: cs.tertiary),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text(
                        'يُعرض سجل هذا الهاتف فقط. ربط حسابك بالسجل ينتظر تحديث خادم المسجد.')),
              ]),
            ),
          body,
        ]);
      },
    );
  }
}

const _dayLetters = {1: 'ن', 2: 'ث', 3: 'ر', 4: 'خ', 5: 'ج', 6: 'س', 7: 'ح'};
String _dayLetter(DateTime d) => _dayLetters[d.weekday]!;

/// وقت قراءة القرآن: رقم اليوم كبيرًا، ثم الشهر والسنة والإجمالي، وأعمدة آخر 7 أيام.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return FutureBuilder<void>(
      future: ReadingStats.instance.load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final st = ReadingStats.instance;
        final week = st.lastWeek;
        final maxV = week.fold<int>(1, (a, b) => b > a ? b : a);
        final now = DateTime.now();
        Widget tile(String label, String value) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(value,
                      textAlign: TextAlign.center,
                      style:
                          tt.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: tt.bodySmall),
                ]),
              ),
            );
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_stories_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('وقت قراءتي للقرآن',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700))),
              if (st.streak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 16, color: cs.tertiary),
                    const SizedBox(width: 4),
                    Text('${st.streak} ${st.streak == 1 ? 'يوم' : 'أيام'}',
                        style: TextStyle(
                            color: cs.tertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ]),
                ),
            ]),
            const SizedBox(height: 14),
            Center(
              child: Column(children: [
                Text(ReadingStats.format(st.today),
                    style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800, color: cs.primary)),
                Text('قرأتَ اليوم', style: tt.bodySmall),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              tile('هذا الشهر', ReadingStats.formatShort(st.thisMonth)),
              tile('هذه السنة', ReadingStats.formatShort(st.thisYear)),
              tile('الإجمالي', ReadingStats.formatShort(st.total)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 64,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < week.length; i++)
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              height: 4 + 34 * (week[i] / maxV),
                              decoration: BoxDecoration(
                                color: week[i] == 0
                                    ? cs.outlineVariant
                                    : (i == week.length - 1
                                        ? cs.tertiary
                                        : cs.primary),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              _dayLetter(now.subtract(
                                  Duration(days: week.length - 1 - i))),
                              style: tt.labelSmall),
                        ]),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
                'يُحسب الوقت ما دامت شاشة القراءة تتحرك، ويتوقف إن بقيت ساكنة أكثر من دقيقتين.',
                style: tt.bodySmall),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.bar_chart_rounded),
                label: const Text('التفاصيل: يومي وشهري وسنوي'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const ReadingHistoryScreen())),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// تفاصيل وقت القراءة: لكل يوم (آخر 30 يومًا) ولكل شهر ولكل سنة.
class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر'
  ];
  int _mode = 0; // 0 يومي، 1 شهري، 2 سنوي

  @override
  Widget build(BuildContext context) {
    final st = ReadingStats.instance;
    final rows = <(String, int)>[];
    if (_mode == 0) {
      for (final e in st.lastDays(30)) {
        rows.add((DateFormat.yMMMEd('ar').format(e.key), e.value));
      }
    } else if (_mode == 1) {
      for (final e in st.monthList) {
        rows.add(('${_months[e.key.$2 - 1]} ${e.key.$1}', e.value));
      }
    } else {
      for (final e in st.yearList) {
        rows.add(('${e.key}', e.value));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('وقت قراءتي للقرآن')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('يومي')),
              ButtonSegment(value: 1, label: Text('شهري')),
              ButtonSegment(value: 2, label: Text('سنوي')),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('لا توجد قراءة مسجَّلة بعد.'))
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    title: Text(rows[i].$1),
                    trailing: Text(ReadingStats.format(rows[i].$2),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: rows[i].$2 == 0
                              ? Theme.of(context).disabledColor
                              : null,
                        )),
                  ),
                ),
        ),
      ]),
    );
  }
}
