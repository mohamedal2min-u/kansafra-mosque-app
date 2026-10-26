import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/quran/quran_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranData.load();
  });

  test('عدد السور والآيات', () {
    expect(QuranData.surahCount, 114);
    expect(QuranData.verseCount(1), 7);
    expect(QuranData.verseCount(2), 286);
    var total = 0;
    for (var n = 1; n <= 114; n++) {
      total += QuranData.verseCount(n);
    }
    expect(total, QuranData.totalVerses);
  });

  test('الترتيب المطلق للآية', () {
    expect(QuranData.absIndex(1, 1), 1);
    expect(QuranData.absIndex(2, 1), 8);
    expect(QuranData.absIndex(114, QuranData.verseCount(114)),
        QuranData.totalVerses);
  });

  test('أجزاء المصحف 30 وتبدأ بصحيح', () {
    expect(QuranData.juzStarts.length, 30);
    expect(QuranData.juzStarts.first, (1, 1));
    expect(QuranData.juzStarts.last, (78, 1));
    for (final (s, v) in QuranData.juzStarts) {
      expect(v, inInclusiveRange(1, QuranData.verseCount(s)));
    }
  });

  test('البحث يتجاهل التشكيل والهمزات', () {
    expect(QuranData.normalize('ٱلرَّحْمَٰنِ ٱلرَّحِيمِ'), 'الرحمن الرحيم');
    final r = QuranData.search('الرحمن الرحيم');
    expect(r, isNotEmpty);
    expect(r.contains((1, 3)), isTrue);
    expect(QuranData.search('ا'), isEmpty); // أقل من حرفين
  });
}
