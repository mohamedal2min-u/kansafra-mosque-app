import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/quran/quran_data.dart';
import 'package:kansafra_mosque/quran/tafsir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('التفسير الميسّر: لكل آية تفسير', () async {
    await QuranData.load();
    expect(await Tafsir.load(), isTrue);
    for (var s = 1; s <= QuranData.surahCount; s++) {
      for (final v in [1, QuranData.verseCount(s)]) {
        expect(Tafsir.of(s, v), isNotNull, reason: 'سورة $s آية $v');
        expect(Tafsir.of(s, v)!.trim(), isNotEmpty);
      }
    }
    expect(Tafsir.of(2, 255), contains('آية الكرسي'));
    expect(Tafsir.of(2, 999), isNull);
  });
}
