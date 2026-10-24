import 'package:flutter/material.dart';
import 'quran_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// قائمة السور (القراءة تعمل بدون إنترنت: النص مضمّن في التطبيق).
class SurahListScreen extends StatelessWidget {
  const SurahListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: QuranData.surahCount,
      itemBuilder: (context, i) {
        final n = i + 1;
        return ListTile(
          leading: CircleAvatar(child: Text('$n')),
          title: Text(QuranData.name(n)),
          subtitle: Text(
              '${QuranData.isMakki(n) ? 'مكية' : 'مدنية'} • ${QuranData.verseCount(n)} آية'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SurahReaderScreen(surah: n)),
          ),
        );
      },
    );
  }
}

class SurahReaderScreen extends StatefulWidget {
  final int surah;
  const SurahReaderScreen({super.key, required this.surah});

  @override
  State<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends State<SurahReaderScreen> {
  static const _kFont = 'quran_font_size';
  double _size = 26;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final v = p.getDouble(_kFont);
      if (v != null && mounted) setState(() => _size = v);
    });
  }

  Future<void> _setSize(double v) async {
    setState(() => _size = v.clamp(18, 44));
    (await SharedPreferences.getInstance()).setDouble(_kFont, _size);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surah;
    final count = QuranData.verseCount(s);
    return Scaffold(
      appBar: AppBar(
        title: Text(QuranData.name(s)),
        actions: [
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => _setSize(_size - 2)),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () => _setSize(_size + 2)),
        ],
      ),
      // ListView.builder يبني الآيات الظاهرة فقط، فيبقى خفيفًا على الهواتف.
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: count,
        itemBuilder: (context, i) {
          final v = i + 1;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${QuranData.verse(s, v)} ${QuranData.endMark(v)}',
              textAlign: TextAlign.justify,
              style: TextStyle(fontSize: _size, height: 2),
            ),
          );
        },
      ),
    );
  }
}
