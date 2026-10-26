import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quran_data.dart';

/// «التفسير الميسّر» مضمّن في التطبيق (يعمل بدون إنترنت)، يُحمَّل عند أول طلب فقط.
class Tafsir {
  static const source = 'التفسير الميسّر — مجمع الملك فهد لطباعة المصحف الشريف';
  static List<List<String>>? _data;
  static Future<bool>? _loading;

  static Future<bool> load() => _loading ??= _load();

  static Future<bool> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/tafsir/muyassar.json');
      _data = await compute(_parse, raw);
      return true;
    } catch (_) {
      _loading = null; // يُعاد المحاولة لاحقًا
      return false;
    }
  }

  static List<List<String>> _parse(String raw) => [
        for (final s in jsonDecode(raw) as List)
          [for (final t in s as List) t as String]
      ];

  static bool get ready => _data != null;

  static String? of(int surah, int verse) {
    final d = _data;
    if (d == null || surah < 1 || surah > d.length) return null;
    final s = d[surah - 1];
    return verse >= 1 && verse <= s.length ? s[verse - 1] : null;
  }
}

/// نافذة تفسير آية: نص الآية ثم تفسيرها، مع التنقل للآية السابقة والتالية.
Future<void> showTafsirSheet(BuildContext context, int surah, int verse) async {
  await Tafsir.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TafsirSheet(surah: surah, verse: verse),
  );
}

class _TafsirSheet extends StatefulWidget {
  final int surah;
  final int verse;
  const _TafsirSheet({required this.surah, required this.verse});

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  late int _s = widget.surah;
  late int _v = widget.verse;

  void _step(int d) {
    var s = _s, v = _v + d;
    if (v < 1) {
      if (s == 1) return;
      s--;
      v = QuranData.verseCount(s);
    } else if (v > QuranData.verseCount(s)) {
      if (s == QuranData.surahCount) return;
      s++;
      v = 1;
    }
    setState(() {
      _s = s;
      _v = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final text = Tafsir.of(_s, _v);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(
                tooltip: 'الآية السابقة',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _step(-1)),
            Expanded(
              child: Text('تفسير سورة ${QuranData.name(_s)}، آية $_v',
                  textAlign: TextAlign.center,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            IconButton(
                tooltip: 'الآية التالية',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _step(1)),
          ]),
        ),
        Expanded(
          child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(
                      '${QuranData.verse(_s, _v)} ${QuranData.endMark(_v)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'NotoNaskh',
                          fontSize: 22,
                          height: 1.9,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(height: 16),
                Text(
                  text ?? 'تعذّر تحميل التفسير.',
                  style: tt.bodyLarge?.copyWith(height: 1.9, fontSize: 17),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: Text(Tafsir.source,
                          style: tt.bodySmall?.copyWith(color: cs.outline))),
                  if (text != null)
                    IconButton(
                      tooltip: 'نسخ',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text:
                                '${QuranData.verse(_s, _v)} (${QuranData.name(_s)}: $_v)\n\nالتفسير: $text\n\n${Tafsir.source}'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('نُسخ')));
                        }
                      },
                    ),
                ]),
              ]),
        ),
      ]),
    );
  }
}
