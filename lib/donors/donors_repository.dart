/// متبرع يظهر في صفحة المتبرعين. إن كان [name] فارغًا يُعرض «فاعل خير».
class Donor {
  final String? name;
  final DateTime date;
  const Donor({this.name, required this.date});

  String get displayName => (name == null || name!.trim().isEmpty) ? 'فاعل خير' : name!.trim();
}

/// مصدر بيانات المتبرعين. التطبيق يحتاج تنفيذًا يتصل بقاعدة بيانات مشتركة
/// (مثل Firebase أو Supabase) ليرى الجميع القائمة نفسها.
abstract class DonorsRepository {
  Future<List<Donor>> approvedDonors();

  /// [reference] رمز يكتبه المتبرع في ملاحظة التحويل ليطابقه المسؤول مع كشف الحساب.
  /// يرسل طلب ظهور في القائمة. لا يظهر الاسم إلا بعد موافقة إدارة المسجد.
  Future<void> submit({String? name, required String reference});
}

/// تنفيذ مؤقت داخل الذاكرة للتجربة فقط: لا يحفظ ولا يشارك البيانات بين الأجهزة.
class InMemoryDonorsRepository implements DonorsRepository {
  final _approved = <Donor>[];

  @override
  Future<List<Donor>> approvedDonors() async => List.unmodifiable(_approved);

  @override
  Future<void> submit({String? name, required String reference}) async {}
}

DonorsRepository donorsRepository = InMemoryDonorsRepository();
