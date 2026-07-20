# WhitegramArabic

ديلب مستقل لتعريب قسم **Whitegram Features** داخل تطبيق Whitegram، من دون الاعتماد على Substrate أو ElleKit. صُمم للحقن المباشر داخل ملف IPA ثم إعادة توقيع التطبيق.

## ما الذي يعربه؟

المشروع يتعامل مع أكثر من مسار عرض للنصوص حتى لا يقتصر على `Localizable.strings` فقط:

- ناتج `NSBundle` للنصوص المحلية.
- `UILabel` و`UIButton` وحقول النص والعناوين والتنبيهات.
- `NSAttributedString` المستخدم بكثرة في واجهات Telegram/Whitegram.
- عقد النصوص والكلاسات المخصصة داخل Frameworks التطبيق عن طريق فحص Runtime.
- العناوين والخيارات والشروحات والتنبيهات الديناميكية المعروفة في نسخة Whitegram 12.8 (55).

تمت مطابقة المشروع مع ملف Whitegram المرفوع، والنتيجة المسجلة داخل `ipa-audit-report.txt` هي:

- الإصدار: `12.8 (55)`
- معرّف الحزمة: `ph.telegra.Telegraph4`
- النصوص المستخرجة والموجودة فعلياً: `698 / 698`
- تغطية القاموس: `100%`
- النصوص الموجودة وغير المترجمة: `0`

تشغّل عملية البناء فحص تغطية إلزامياً قبل إنتاج الديلب، وتتوقف تلقائياً إذا فُقد نص أو اختل رمز تنسيق مثل `%@` أو `%d`.

## البناء عبر GitHub Actions

1. ارفع محتويات المجلد إلى مستودع GitHub.
2. افتح تبويب **Actions**.
3. اختر **Build Whitegram Arabic Dylib**.
4. اضغط **Run workflow**.
5. بعد اكتمال البناء نزّل Artifact باسم:
   `WhitegramArabic-dylib`

داخله:

- `WhitegramArabic.dylib`
- `SHA256.txt`
- `coverage-report.txt`

## الحقن

احقن `WhitegramArabic.dylib` داخل:

`Payload/Telegram.app/Frameworks/`

ثم أضف أمر تحميله إلى Mach-O الرئيسي باستخدام أداة الحقن التي تستعملها، وبعدها أعد توقيع كامل التطبيق. اسم التثبيت داخل الديلب هو:

`@rpath/WhitegramArabic.dylib`

لا يحتاج الديلب إلى مكتبة خارجية أو جيلبريك، لكنه يحتاج أن تقوم أداة التوقيع أو الحقن بإضافة `LC_LOAD_DYLIB` إلى ملف `Telegram`.

## تعطيل التعريب مؤقتاً

التعريب مفعّل افتراضياً. يمكن تعطيله من UserDefaults بالمفتاح:

`WGArabicLocalizationEnabled = false`

## تحديث الترجمات

عدّل الملف:

`Resources/ar.json`

ثم شغّل:

```bash
python3 tools/verify_translations.py
python3 tools/generate_translations.py
```

يتحقق الفاحص أيضاً من بقاء رموز التنسيق مثل `%@` و`%d` متطابقة بين النص الإنجليزي والعربي.

## التوافق

- المعمارية: `arm64`
- الحد الأدنى: iOS 15
- مناسب للحقن في تطبيقات iOS الموقعة جانبياً
- لا يرتبط بـ CydiaSubstrate

## حدود التحقق

تم التحقق من وجود كل النصوص المستهدفة داخل Framework النسخة المرفوعة، ومن اكتمال قاموسها، ومن سلامة بناء ملفات Objective-C للمعمارية `arm64-apple-ios`. التشغيل النهائي داخل التطبيق نفسه يحتاج إنتاج الديلب من GitHub Actions ثم حقنه وإعادة توقيع الـIPA؛ لذلك يوجد مسار Hook متعدد الطبقات للنصوص المباشرة و`NSAttributedString` وكلاسات Telegram المخصصة، وليس مجرد استبدال ملف لغة.
