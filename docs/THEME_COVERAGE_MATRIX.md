# مصفوفة الثيمات النهائية للجولة — 2026-11-23

المصدر المختبر3464f45؛ [Actions45110231725](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/45110231725) **SUCCESS بجميع المهام الست**. PASS يخص نطاق الاختبار، وليس اعتماد الإنتاج. 18 ملف شاشة/غلاف + ملف تصدير؛34 حالة مرئية، وليست34 شاشة مستقلة.

| النطاق | أزرق نهاري | أزرق ليلي | وردي نهاري | وردي ليلي |
|---|---|---|---|---|
| 34 حالة ×عروض320/360/390/430/600/800dp | Widget/Golden PASS | PASS | PASS | PASS |
| 33 نهاية تمرير عند390dp | Golden PASS | PASS | PASS | PASS |
| 160% وارتفاعات600/640dp، وبناء المحتوى الكسول | Layout PASS | PASS | PASS | PASS |
| دخول640dp ولوحة محاكاة260dp والتحقق من الحقول | PASS | PASS | PASS | PASS |
| YER/SAR/USD ومبالغ طويلة ببطاقات220/320dp وخط100/160% | PASS | PASS | PASS | PASS |
| دلالات تنقل واحدة وassistive tap، رمز البلدLTR، تذكرني | PASS | PASS | PASS | PASS |
| اختيار الشخصية في الواجهة وPDF | رجل PASS | رجل PASS | أنثى PASS | أنثى PASS |
| Android: دخول6عروض لكل ثيم | PASS 6صور | PASS 6صور | PASS 6صور | PASS 6صور |
| Android:13 حالة تبويب/نافذة عند390dp | PASS 13صور | PASS 13صور | PASS 13صور | PASS 13صور |
| Android:رئيسيتا التاجر/العميل،5عروض أخرى | PASS 10صور | PASS 10صور | PASS 10صور | PASS 10صور |
| Android:IME وتحقق وتذكرني ومنع الدخول دون مصادقة | PASS 3صور | NOT VERIFIED فعلياً | NOT VERIFIED فعلياً | NOT VERIFIED فعلياً |
| جودة الأصول HD داخل APK/Android | PASS رجل1086×1448 | PASS رجل1086×1448 | PASS امرأة1024×1536 | PASS امرأة1024×1536 |
| تطابق فني دقيق مع مرجع المالك | NOT VERIFIED | لا مرجع ليلي | لا مرجع أنثوي | لا مرجع أنثوي |
| جميع الأنماط المحلية وأهداف اللمس/TalkBack | FAIL/NOT VERIFIED | FAIL/NOT VERIFIED | FAIL/NOT VERIFIED | FAIL/NOT VERIFIED |

## الاختبارات

| ملف test/ui_audit | الحالات |
|---|---:|
| role_layout_matrix_test:13 تبويباً/نافذة |416|
| screen_catalog_matrix_test:13 شاشة تفصيلية |364|
| populated_financial_matrix_test:7 حالات مالية ممتلئة |196|
| login_matrix_test |56|
| currency_accessibility_test |48|
| pdf_identity_test |2|
| reference_controls_test |4|
| navigation_accessibility_test |8|
| المجموعUI |**1094**|

المجموعة الكاملة **1368 PASS**، وbackend/PostgreSQL **24 PASS بلا SKIP**. **950 Golden**:816 بداية +132 نهاية تمرير +2 لشخصياتPDF. CI يقارن دون update-goldens. الصور مثبتة من التنفيذ ولا تمثل موافقة المالك.

**119 صورة Android**:27 للدخول و92 للمطورين، وفق result.json لكل حزمة في ui_evidence/android_hd_3464f45. روجعت مصفوفة الدخول وصور13 حالة لكل ثيم؛ فُكت الصور الإضافية كلها، ولا ادعاء مراجعة كل بكسل. التطبيقات مثبّتة فعلياً على محاكيAPI35، دون حسابات موثقة أو بوابات حقيقية. لا مالية أو مصادقةE2E، ولا بيانات test في runtime.

RTL وCairo وMaterialIcons فعلية. بيانات الاختبار المالي داخل test فقط تمر عبر AppState وقرارات الموافقة الحقيقية؛ العملات مستقلة، والرصيد1,000,000 لكل عملة، والمعلق منفصل. ورقPDF فاتح في الليل للطباعة. البانرات التسويقية وحدها مستثناة بموافقة المالك من شرط الجنس.

## حدود الأدلة الحالية

مصدر التطبيق3464f459672f941c311fc9e03f0bf167597f1c1b. الشعار1254×1254 هو نفسه في الأربعة؛ له سطح فاتح مساعد في الليل لحفظ قراءة العبارة. لا تغيير لألوان الهوية الأساسية. الملفات الثلاثة RGBA، فُكّت داخل Flutter ومن APK، وبايتاتها تطابق المصدر. الاشتقاق التوليدي تم بتوجيه المالك، ولا يمثل تطابق بكسلات مع المراجع الأصلية.

اختبار HD الجديد خارج مجلد ui_audit؛ لذلك زاد المجموع العام إلى1368 بينما بقيت اختبارات المصفوفة1094. PDF الآن يقارن PNG bytes فعلياً. CI يقارن950 Golden دون تحديث؛ اعتماد418 صورة متغيرة بعد مراجعتها موثق في [HD_ARTWORK_BASELINE_REVIEW.md](HD_ARTWORK_BASELINE_REVIEW.md).

[دليل Android الحالي](ui_evidence/android_hd_3464f45/visual-review.json)، [بصمات APK والتحقق من الأصول](ui_evidence/android_hd_3464f45/apk-and-native-verification.json)، [سجل CI بجميع المهام](ui_evidence/ci_45110231725_result.json). حالات Android الإضافية للتاجر/العميل لا تغطي الشاشات التفصيلية الـ13 أو البيانات المالية الممتلئة؛ هذه لها Widget/Golden فقط. لا نخلط ذلك بتحقق إنتاجي.
