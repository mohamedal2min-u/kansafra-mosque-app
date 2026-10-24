/// إعدادات المسجد. عدّل القيم هنا فقط.
class MosqueConfig {
  static const name = 'مسجد كنصفرة الكبير';

  // إحداثيات تقريبية لبلدة كنصفرة (جبل الزاوية، إدلب) - يُرجى التأكد منها.
  static const latitude = 35.68;
  static const longitude = 36.38;

  /// المنطقة الزمنية لجدولة التنبيهات.
  static const timeZone = 'Asia/Damascus';

  /// تعديل دقائق لكل صلاة لمطابقة جدول المسجد (مثال: {'fajr': 2}).
  static const minuteAdjustments = <String, int>{};

  /// طرق التبرع - ضع بيانات المسجد الحقيقية (لا تُنشر أرقام غير مؤكدة).
  static const donationMethods = <DonationMethod>[
    DonationMethod(title: 'تحويل بنكي', details: 'اسم الحساب / الرقم: (يُضاف من إدارة المسجد)'),
    DonationMethod(title: 'شام كاش', details: 'الرقم: (يُضاف من إدارة المسجد)'),
    DonationMethod(title: 'التسليم المباشر', details: 'لدى لجنة المسجد بعد الصلاة'),
  ];
}

class DonationMethod {
  final String title;
  final String details;
  const DonationMethod({required this.title, required this.details});
}
