# تفعيل قائمة المتبرعين المشتركة (بحساب Google الموجود، بدون حسابات جديدة)

1. افتح https://sheets.new وسمِّ الجدول «متبرعو المسجد». اكتب في الصف الأول: `التاريخ` | `الاسم` | `المبلغ`.
2. من القائمة: الامتدادات (Extensions) ثم Apps Script. احذف ما فيه والصق محتوى `donors_apps_script.gs` ثم احفظ.
3. اضغط Deploy ثم New deployment. النوع: Web app. Execute as: Me. Who has access: Anyone. اضغط Deploy ووافق على الأذونات.
4. انسخ رابط Web app (ينتهي بـ `/exec`) وأرسله لي، أو ضعه في `lib/config.dart` في `donorsUrl`.

لحذف اسم غير مرغوب: احذف صفه من الجدول.
