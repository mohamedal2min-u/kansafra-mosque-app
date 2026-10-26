import 'package:flutter/services.dart' show appFlavor;

import 'config.dart';

/// نسختان من الكود نفسه (--flavor): «kansafra» تطبيق مسجد كنصفرة، و«rafiq» تطبيق
/// «رفيق المسلم» العام لكل المسلمين: مواقيت مكان المستخدم بلا عمود كنصفرة ولا تنبيه السفر.
class AppFlavor {
  AppFlavor._();

  // --dart-define=APP=rafiq: لنسخة الويب (لقطات المتجر)، إذ لا تدعم --flavor.
  static const general =
      appFlavor == 'rafiq' || String.fromEnvironment('APP') == 'rafiq';
  static const appName = general ? 'رفيق المسلم' : MosqueConfig.name;
}
