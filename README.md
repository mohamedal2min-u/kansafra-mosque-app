# تطبيق مسجد كنصفرة الكبير

تطبيق Flutter: مواقيت الصلاة (حساب محلي بدون إنترنت عبر `adhan`) وصفحة التبرعات.

## التشغيل
```
flutter create . --platforms=android,ios   # مرة واحدة لتوليد مجلدات المنصات
flutter pub get
flutter run
```
عدّل `lib/config.dart` (الإحداثيات، تعديل الدقائق، بيانات التبرع).

## التالي
- إشعارات/صوت الأذان (flutter_local_notifications)
- التبرع الإلكتروني إن وُجدت بوابة دفع متاحة
