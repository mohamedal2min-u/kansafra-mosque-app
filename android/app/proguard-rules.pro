# flutter_local_notifications يحفظ الإشعارات المجدولة بـ Gson (TypeToken). تصغير الكود (R8) في نسخة الإصدار
# يحذف معلومات النوع العام فيفشل الجدولة: "Missing type parameter". هذه القواعد تمنع ذلك.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
