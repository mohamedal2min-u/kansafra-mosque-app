import 'package:flutter_test/flutter_test.dart';
import 'package:kansafra_mosque/quran/khatma.dart';
import 'package:kansafra_mosque/quran/quran_data.dart';
import 'package:kansafra_mosque/quran/saved_verses.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranData.load();
  });

  test('العلامة والهدف: التقدم والورد اليومي', () async {
    SharedPreferences.setMockInitialValues({});
    final k = Khatma.instance;
    await k.load();
    await k.setMark(1, 1);
    expect(k.mark.value?.label, 'سورة الفاتحة، آية 1');
    await k.setGoal(30);
    expect(k.daysLeft, 30);
    // ما تبقى 6235 آية على 30 يومًا
    expect(k.dailyVerses, (6235 / 30).ceil());
    await k.setMark(114, 6);
    expect(k.progress, 1.0);
    expect(k.dailyVerses, 0);
    await k.setGoal(null);
    expect(k.daysLeft, isNull);
    await k.clearMark();
    expect(k.mark.value, isNull);
  });

  test('الآيات المحفوظة: حفظ وإزالة', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SavedVerses.instance;
    expect(await s.toggle(2, 255), isTrue);
    expect(s.contains(2, 255), isTrue);
    expect(await s.toggle(2, 255), isFalse);
    expect(s.contains(2, 255), isFalse);
  });
}
