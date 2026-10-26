import 'package:flutter/material.dart';

import '../account/identity.dart';
import 'leaderboard.dart';
import 'reading_stats.dart';

/// ترتيب القرّاء بوقت القراءة: هذا الشهر، وكل الأوقات.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  Boards? _boards;
  String? _error;
  bool _loading = true;
  bool _monthly = true;
  bool _on = true;
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await Leaderboard.cached();
    final on = await Leaderboard.participating();
    final name = await Leaderboard.name();
    if (mounted) {
      setState(() {
        _boards ??= cached;
        _on = on;
        _name = name;
      });
    }
    try {
      final b = await Leaderboard.fetch();
      if (mounted) {
        setState(() {
          _boards = b;
          _error = null;
        });
      }
    } on LeaderboardUnavailable {
      if (mounted) {
        setState(() => _error = 'الترتيب غير متاح بعد. حاول لاحقًا.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = _boards == null
            ? 'تعذّر تحميل الترتيب. تحقّق من الإنترنت.'
            : null); // نعرض آخر ترتيب محفوظ بصمت
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editName() async {
    final google = Identity.instance.user?.displayName?.split(' ').first;
    final ctl = TextEditingController(text: _name ?? google ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسمك في الترتيب'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'مثلًا: أبو محمد'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('حفظ')),
        ],
      ),
    );
    if (v == null) return;
    setState(() {
      _name = v.trim().isEmpty ? null : v.trim();
      _loading = true;
    });
    await Leaderboard.setName(v);
    await _load();
  }

  Future<void> _toggle(bool on) async {
    setState(() {
      _on = on;
      _loading = true;
    });
    await Leaderboard.setParticipating(on);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final board = _monthly ? _boards?.month : _boards?.all;
    final me = board?.top.where((e) => e.me).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('ترتيب القرّاء')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.badge_rounded, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'اسمك في الترتيب: ${_name ?? me?.name ?? 'قارئ برقم'}',
                              style: tt.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        TextButton(
                            onPressed: _on ? _editName : null,
                            child:
                                Text(_name == null ? 'اختر اسمًا' : 'تغيير')),
                      ]),
                      if (Identity.instance.user == null)
                        Padding(
                          padding: const EdgeInsets.only(right: 32, bottom: 4),
                          child: Text(
                              'سجّل الدخول بحساب Google من «حسابي» ليبقى ترتيبك إن غيّرت هاتفك.',
                              style: tt.bodySmall),
                        ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('أظهرني في الترتيب'),
                        value: _on,
                        onChanged: _loading ? null : _toggle,
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('هذا الشهر')),
                ButtonSegment(value: false, label: Text('كل الأوقات')),
              ],
              selected: {_monthly},
              onSelectionChanged: (s) => setState(() => _monthly = s.first),
            ),
            const SizedBox(height: 12),
            if (_loading && board == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && board == null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (board != null) ...[
              if (_on)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      board.rank == 0
                          ? 'اقرأ في المصحف دقيقة على الأقل لتظهر في الترتيب.'
                          : 'ترتيبك: ${board.rank} من ${board.count} قارئ',
                      textAlign: TextAlign.center,
                      style: tt.titleSmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w700)),
                ),
              if (board.top.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا أحد في الترتيب بعد. كن أول القرّاء!',
                      textAlign: TextAlign.center),
                ),
              for (var i = 0; i < board.top.length; i++)
                _Row(rank: i + 1, entry: board.top[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final BoardEntry entry;
  const _Row({required this.rank, required this.entry});

  // الأول نجمة ذهبية صفراء، والثاني فضية، والثالث برونزية.
  static const _stars = {
    1: Color(0xFFFFC107),
    2: Color(0xFFB0BEC5),
    3: Color(0xFFCD7F32),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final star = _stars[rank];
    return Card(
      color: entry.me ? cs.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: entry.me ? cs.primary : cs.outlineVariant,
            width: entry.me ? 1.6 : 1),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: star == null
              ? CircleAvatar(
                  backgroundColor: cs.surfaceContainerHighest,
                  child: Text('$rank',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                )
              : Stack(alignment: Alignment.center, children: [
                  Icon(Icons.star_rounded, color: star, size: 44),
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('$rank',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ),
                ]),
        ),
        title: Text(entry.me ? '${entry.name} (أنت)' : entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight:
                    rank <= 3 || entry.me ? FontWeight.w700 : FontWeight.w500)),
        trailing: Text(ReadingStats.formatShort(entry.seconds),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
