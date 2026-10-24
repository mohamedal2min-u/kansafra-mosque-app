/// إعدادات المسجد. عدّل القيم هنا فقط.
class MosqueConfig {
  static const name = 'مسجد كنصفرة الكبير';

  static const latitude = 35.65862402383966;
  static const longitude = 36.48396655620541;

  /// رابط Web app لجدول المتبرعين (انظر tools/DONORS_SETUP.md). فارغ = قائمة تجريبية على هذا الجهاز فقط.
  static const donorsUrl =
      'https://script.google.com/macros/s/AKfycbyCZUIZbzX263x3MBMpB4AAc8-p7ZBTaWf_AZineSAZuR543p60bD35SLRwnTgR08Gimw/exec';

  /// Web client ID من Google Cloud Console لتفعيل «الدخول بحساب Google» (اختياري). فارغ = الدخول مخفي.
  /// يجب أن يكون هو نفسه WEB_CLIENT_ID في tools/donors_apps_script.gs.
  static const googleWebClientId =
      '843002779261-9mp73ui95d4f2h3hha9399m05bg3d611.apps.googleusercontent.com';

  /// المنطقة الزمنية لجدولة التنبيهات.
  static const timeZone = 'Asia/Damascus';

  /// تعديل دقائق لكل صلاة لمطابقة جدول المسجد (مثال: {'fajr': 2}).
  static const minuteAdjustments = <String, int>{};

  /// طرق التبرع. اترك [DonationMethod.details] فارغًا حتى تُضاف البيانات الحقيقية من إدارة المسجد.
  static const donationMethods = <DonationMethod>[
    DonationMethod(
      title: 'شام كاش',
      badge: '',
      color: 0xFF1E8E5A,
      logo: 'assets/pay/shamcash.png',
      // رقم الحساب مأخوذ من رمز QR المرسل من لجنة المسجد.
      details: '1dff3aa4e6d84e983b48c4f8ad6480b8',
      holder: 'توفيق أبو محمد',
      qr: 'assets/pay/shamcash_qr.jpg',
    ),
    DonationMethod(title: 'بطاقات الدفع', badge: '', color: 0xFF1A3C6E, logo: 'assets/pay/cards.png'),
    DonationMethod(title: 'PayPal', badge: '', color: 0xFF0070BA, logo: 'assets/pay/paypal.png'),
  ];
}

class DonationMethod {
  final String title;
  final String details;
  final String badge;
  final int color;
  final String? logo;
  final String? holder; // اسم صاحب الحساب
  final String? qr; // صورة رمز QR للمسح
  const DonationMethod({
    required this.title,
    this.details = '',
    required this.badge,
    required this.color,
    this.logo,
    this.holder,
    this.qr,
  });
}
