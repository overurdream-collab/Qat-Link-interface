# مقوتي لينك — تسليم الهوية البصرية وحركة التنبيهات والحجوزات
التاريخ: 19 نوفمبر 2026. الفرع: `feat/p0-auth-identity-integration-20261118`. PR #61 (Draft).

## قرار الهوية البصرية
- **الاسم الرسمي:** «مقوتي لينك»، بالياء، في كل عرض جديد.
- **الصور التي سلّمها المستخدم:** خلفية شخصية يمنية `864×1536` وشعار أفقي `1536×512`. الصور الأصلية محفوظة في ملف ZIP الذي تم تسليمه للمستخدم في المحادثة، وليست مخزّنة بأعلى دقة في GitHub حتى الآن.
- GitHub يحتوي حالياً صورة خلفية `assets/images/maqwati_login_background.jpg` (7955 بايت) وشعاراً `assets/images/maqwati_horizontal_logo.jpg` (6867 بايت): **نسختان صغيرتان للمراجعة فقط**، وليستا نسخة عالية الدقة مناسبة للإنتاج. على المبرمج القادم استبدالهما بالملفين الأصليين من الحزمة `maqwati_brand_full_resolution.zip` مع المحافظة على المسارين نفسيهما، ثم اختبار Flutter/PDF وAPK. لا تُزعم الجودة العالية قبل ذلك.
- لوحة الهوية الجديدة: `#07575B` تركواز داكن، `#168E94` تركواز، `#DAF2F2` خلفية فاتحة، `#D4A13E` ذهبي. تُطبق بالهوية/الرسومات. **أبْقِ** ألوان الحالات المالية والأرصدة والتنبيهات الخطرة في `lib/theme/app_colors.dart` دون تبديل دلالاتها أو كسر اختبارات `approved_ui_test.dart`.
- الإعداد `pubspec.yaml` يضم `assets/images/` مسبقاً؛ لا حاجة إلى تحميل صور عبر الإنترنت عند تشغيل التطبيق.

## ما نُفّذ
| المكان | العمل | التحقق |
|---|---|---|
| الدخول/التسجيل | `AuthBrandHero` يستخدم الشعار الأصلي دون شخصية بديلة | `lib/widgets/auth/auth_brand_hero.dart` |
| شاشة الدخول | صورة الخلفية الجديدة مع طبقة شفافة لقراءة النماذج | `lib/screens/login_screen.dart` |
| شريط التاجر المشترك (كل الشاشات الأساسية) | شخصية الشعار الصغيرة واسم التطبيق الأفقي مع بقاء اسم الحساب والأزرار | `lib/widgets/app_chrome.dart` |
| إعداد OTP والتحقق | `MaqwatiBrandMark` أعلى حقول التحقق | `lib/screens/fin25_pilot_setup_screen.dart`, `lib/screens/fin25_otp_screen.dart` |
| شاشة الحساب الموثّق | الشعار على أعلى الشاشة | `lib/screens/identity_account_screen.dart` |
| الضبط | الشعار في لوحة الضبط | `lib/main.dart` |
| PDF كشف العميل | الشعار مرسوم على Canvas الصفحة الأولى والمتتابعة | `lib/widgets/customers/customer_statement_pdf.dart` |
| PDF حجوزات اليوم | الشعار على كل صفحة A4 | `lib/widgets/merchant_space/reservation_daily_pdf.dart` |
| PDF تجهيز العمال | الشعار على كل صفحة A4 | `lib/widgets/merchant_space/worker_preparation_pdf.dart` |
| شاشة الحجوزات | شخصية في العنوان + ظهور متحرك للعناصر الجديدة التي تضيف ID جديداً | `lib/screens/merchant_bookings_screen.dart` |
| شاشة التنبيهات | شاشة جديدة تتمتع بعرض الشخصية، حالات فراغ صادقة ومعاينة دون إرسال مزيف | `lib/widgets/notifications/maqwati_notifications_sheet.dart` |
| بطاقة الإعلان/الحجز | رأس الشخصية يطل بحركة `elasticOut` قصيرة (حوالي 960ms)، مرة واحدة للعنصر الجديد | `lib/widgets/notifications/maqwati_peeking_mascot.dart` |
| تنبيه داخل التطبيق أثناء التشغيل | شريط علوي يظهر عند وصول `incomingNotification` بحدث ID مختلف ويختفي بعد 5 ثوانٍ | `lib/widgets/notifications/maqwati_incoming_notification_host.dart` و`lib/main.dart` |

## شرط الحقيقة التقنية: إشعار الهاتف مقابل حركة التطبيق
- **عندما يكون التطبيق مفتوحاً:** يمكن إظهار حركة الرأس في Flutter بمجرد وصول حدث موثوق من خدمة الإشعارات؛ مكوّن `MaqwatiIncomingNotificationHost` جاهز ويقبل `MaqwatiNotificationEvent`، لكن لا توجد خدمة إشعارات موصلة به بعد. لا تقل إنه يصدر إشعارات حقيقية.
- **عندما التطبيق في الخلفية أو مغلق:** لا تتيح واجهة Android / iOS القياسية تشغيل AnimationController من Flutter داخل إشعار النظام نفسه. الاستراتيجية المدعومة: صورة ثابتة لشخصية الشعار في إشعار النظام (large icon/expanded image إن كانت مدعومة)، مع نص واضح و`deep link` إلى شاشة الحجوزات/التنبيهات، ثم **تبدأ حركة إطلالة الرأس داخل التطبيق عند فتحه من الإشعار** بعد التحقق من هوية المستخدم. لا تطلب draw-over-other-apps ولا تنشئ خدمة عائمة فوق شاشة القفل.
- يحتاج الإرسال الحقيقي: خدمة أحداث موثوقة مع تخصيص المستخدم، أذونات الإشعارات عند اللزوم، قنوات Android 13+، جهاز token آمن وخدمة دفع مثل FCM أو بديل مناسب لبيئة اليمن، معرف حدث فريد، منع التكرار، صلاحية وصول، احترام تعطيل الإشعارات الاختيارية، واختبار على الجهاز الفعلي. **لا يتوفر أي من ذلك بمجرد تنفيذ الأنيميشن**.
- المعاينة المرئية داخل شاشة التنبيهات موسومة «لم يتم إرسال أي إشعار». لا تؤثر على حالة الحجز أو الموافقات أو المالية.
- لا ترسل أي مبلغ أو دين غير معتمد في نصوص الإشعارات، ولا تُظهر اسم العميل على شاشة القفل دون سياسة خصوصية.

## اختبارات القبول
- الاختبار `test/widgets/maqwati_notifications_animation_test.dart` يغطي التفعيل المعتمَد على حدث، الحالة الفارغة، المعاينة الصادقة، واحترام تقليل الحركة؛ `test/widgets/maqwati_incoming_notification_host_test.dart` يغطي شريط وصول فعلي داخل التطبيق.
- `test/theme/maqwati_brand_assets_test.dart` يفحص توفر الصورتين محلياً والهوية البصرية. اختبارات PDF موجودة في `test/widgets/customer_statement_pdf_test.dart`, `test/widgets/merchant_space_daily_pdf_test.dart`, `test/widgets/worker_preparation_pdf_test.dart`.
- **لا تعلن النجاح حتى إتمام CI للـSHA النهائي**. يلزم اختبار صوت/أيقونة/حركة Android على هاتفين قبل قبول تجربة العملاء.
- لا نشر أو دمج أو تعديل `fin25-test` / SMS Gateway / Docker أو مفاتيح الجهاز من مهام الواجهة.

## إضافة واجهة العميل — سجل آخر تغييرات
- commit `21dfb4de94bc1669faa5d2e04a3ebdf10b928564`: واجهة عميل مستقلة `lib/screens/customer_updates_screen.dart` بتبويبين «التنبيهات» و«حجوزاتي»، شعار موحد، حركة للشخصية أمام البيانات الجديدة **الموثقة فقط**، ورسالة صادقة عند عدم وجود أحداث. للحجز حقل حالة يورّده الخادم؛ لا يتم استنتاجه من النص ولا تحويل الحجز إلى دين.
- commit `599312168515af257a38a8eb1a0a34f30b147f1e`: اختبارات تبويبي عميل وغياب الحجوزات الوهمية `test/screens/customer_updates_screen_test.dart`.
- commit `be4bc5c25cadba8c33d5f3fa1b05e8f037dfd2d1`: تصحيح اسم التطبيق إلى «مقوتي لينك» في بطاقة الرئيسية.
- commit `0f3331b42be5e58294787efe62ff89f16f287dc9`: اختبار وصول إشعار موثّق إلى Overlay داخل Flutter.
- **تنبيه قبول:** واجهة العميل جاهزة كمكوّن مستقل **لكنها غير مربوطة حالياً بجلسة عميل حقيقية أو خدمة إشعارات**. لا تسجل استلام حجوزات فعلية، ولا تُقدّم تحريك رأس الشخصية في إشعارات Android النظامية على أنه متاح. الربط الفعلي يتطلب تطوير خدمة إشعارات وخطأ صلاحيات وتوجيه Android/iOS إلى شاشة العميل، وإعادة فحص CI بعد آخر Commit.


- commit `bc1c3d6bc911c7dc78dec7b37dff02d8d7fbe9b1`: زر «تنبيهاتي وحجوزاتي» في `IdentityAccountScreen` لحساب العميل الموثّق فقط، يفتح واجهة العميل بدون اصطناع بيانات من خادم غير متصل؛ الماليات تبقى محجوبة حتى المصادقة والتخويل الفعلي.
- commit `7f01495e828b82f1e7d2d3e5dd6f47ab3a1d3346`: اختبار تنقل عميل اصطناعي من واجهة الهوية إلى التحديثات وإثبات خلو الصفحة وعدم وجود موافقة ديون وهمية.

## CI / إصلاح تخطيط الشاشات الصغيرة — 19 نوفمبر 2026
- تشغيل CI للـSHA `5a21975eb3c3cf10e091cd4cb77335d8b459c7e1`: [#44422007908](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/44422007908). نجح تحليل Flutter واختبار هوية Node، لكن `flutter test` أبلغ `205 passed / 2 failed`. الفشلان داخل اختبارات التمرير بسبب ظهور عناصر أسفل شاشة محاكاة ارتفاعها 600px بعد إضافة الشعار، وليس إثباتاً لعطل مالي أو OTP.
- `d4f4dc2d5557dbbed467447a42b8a9e686ce91b9`: تعديل `test/screens/fin25_pilot_test.dart` لتمرير الشاشة حتى زر المتابعة قبل اختباره.
- `22c23ac6862d2651814e745f91f9a9bb52afde02`: تعديل `test/screens/merchant_reminder_campaign_widget_test.dart` لوضع قائمة اختيار الجمهور داخل مجال اللمس قبل التفاعل معها.
- لا تعلن الاختبارات الكاملة ناجحة حتى انتهاء فحص CI على **رأس هذه التغييرات**. نفّذ Android على هاتف صغير وتحقق من ارتفاع الشعار والأزرار فعلياً.


## استكمال الأصول عالية الدقة وفحص منع إصدار الصور المصغرة — 19 نوفمبر 2026
- تم فتح الملف الأصلي `maqwati_brand_full_resolution.zip` في بيئة معالجة الملفات، وتحقق وجود صورتين فعليتين بالمقاسات:
  - `assets/images/maqwati_login_background.jpg`: ‏864×1536، ‏314834 بايت، SHA256 `5164ee3d142c7b62bdab6312faf290ceff75852ec8f6260cba82fe434084c748`.
  - `assets/images/maqwati_horizontal_logo.jpg`: ‏1536×512، ‏163866 بايت، SHA256 `2765b0d88d3f352f589dac789f1c8dd847293dbfed08fcda9eb665140bf5c12b`.
- **الأصول الأصلية لم تُرفع بعد إلى GitHub**؛ نسخ المستودع صغيرة (العلامة التجريبية فقط)، لأن GitHub content connector للملفات النصية لا يقبل JPEG بصورته الثنائية. لم نغيّر الصور المصغرة دون تكامل آمن لنقل البايتات.
- أُضيف `scripts/install_maqwati_brand_assets.ps1` لفحص ZIP الأصلي باستخدام SHA256 وأبعاد JPEG قبل إجراء أي كتابة. وضعه الافتراضي **قراءة فقط**؛ الخيار `-Apply` يستبدل هذين الملفين فقط وينشئ نسخاً احتياطية محلية. لا يعدل SMS Gateway/FIN25/Docker:
  ```powershell
  .\\scripts\\install_maqwati_brand_assets.ps1 -ZipPath "C:\\path\\maqwati_brand_full_resolution.zip"
  .\\scripts\\install_maqwati_brand_assets.ps1 -ZipPath "C:\\path\\maqwati_brand_full_resolution.zip" -Apply
  ```
- أُضيف `scripts/check_maqwati_brand_assets.py` ويجب تشغيل `python scripts/check_maqwati_brand_assets.py --mode release` **قبل أي بناء إطلاق فعلي**؛ هذا يمنع اعتماد الصور المصغرة إلى أن تصبح الملفات مطابقة تماماً لـSHA الأصلي. وضع `--mode preview` لا يمنع APK المعاينة.
- تحديث CI يختبر وجود الأصول داخل معاينة Flutter ويتحقق من صلاحية سكربت PowerShell؛ **لا يزعم أن ملفات GitHub الأصلية أصبحت عالية الدقة**.
- ثبت نجاح وظائف `flutter-auth` و`identity-logic` و`android-compile` في [تشغيل P0 رقم 44422665231](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/44422665231) عند commit `562be691d11495ed6df0d37527ef62df3097e85e`. نتج artifact `maqwati-branded-login-preview-apk` رقم `14482752935`؛ انتهاؤه مبدئياً في 25 نوفمبر. هذا APK DEBUG تجريبي **ويحتوي نسختي الصور المصغّرتين**، وليس تسليم إنتاجياً ولا تنفيذ إشعارات النظام عند إغلاق التطبيق.


## معاينة العميل دون تسجيل الدخول — 19 نوفمبر 2026
- تم اكتشاف قيد مهم: النسخة التجريبية لا تصل إلى شاشة حساب موثق قبل نشر خدمة P0، وبالتالي كان اختبار الإطلالة مقتصراً على Flutter Widget Tests.
- `061a9fc22f58b054e60ed711869efd89a3062900`: `lib/screens/notification_design_preview_screen.dart` يعرض شاشة **محاكاة تصميمية فقط** لظهور الحجز أو التنبيه، ويستخدم نفس `MaqwatiIncomingNotificationHost` الذي سيستقبل الأحداث الحقيقية مستقبلاً.
- `530e52194307a50852f4c2b5c10e2f55e67d3e75`: زر جديد في `lib/screens/login_screen.dart` باسم «معاينة حركة التنبيهات والحجوزات» يظهر **فقط في Debug** عند `kDebugMode`. الوصول إليه لا يصدر JWT، ولا يستدعي SMS، ولا ينشئ حساباً أو حجزاً أو ديناً.
- `1d6d425251586470e2b6e226eaab599d2700647d`: اختبار `test/screens/notification_design_preview_screen_test.dart` لفتح شاشة المعاينة من تسجيل الدخول، ثم محاكاة وصول الحجز والتنبيه وعرض البطاقة، مع التأكد من غياب جلسة مالية.
- المعاينة لا تمثل وصول إشعار Android أصلي، ولا تظهر عند إغلاق التطبيق؛ الخدمة الحقيقية غير متصلة. أي نسخة APK سابقة على هذه الـCommits لا تضم زر المعاينة.


## بناء APK عالي الدقة من Windows دون تغيير الخوادم
- `9803568c9499950aaa75e5b038abc2f71055e3d9`: `scripts/build_maqwati_branded_preview.ps1` هو أمر محلي واحد يستدعي مثبّت الأصول الموثوقة، ويفرض SHA256 الأصلي في `check_maqwati_brand_assets.py --mode release`، ثم `flutter pub get`، و`flutter analyze`، واختبارات Flutter، وأخيراً `flutter build apk --debug`. لا يلمس Docker ولا SMS ولا قاعدة البيانات.
- `8e63a33df2a9a8bf47217495798ac63d7f546ead`: فحص PowerShell syntax للسكريبتين داخل CI (بجانب فحوص Flutter وNode).
- الأمر المقصود تشغيله **داخل نسخة مستودع Qat-Link-interface الحديثة على جهاز Windows** وليس بالضرورة مجلد `F:\\maqwatilink-fin25` الخاص بالخادم:
  ```powershell
  .\\scripts\\build_maqwati_branded_preview.ps1 -ZipPath "C:\\path\\maqwati_brand_full_resolution.zip"
  ```
  عند نجاحه يوجد APK عند `build/app/outputs/flutter-apk/app-debug.apk`. لا ترفع المفتاح الخاص للهوية أو عناوين تشغيل حساسة. يظل هذا إصدار Debug لمعاينة الشكل والحركة.
- اختبار حركة الإشعارات من الشاشة الرئيسية متاح الآن في Debug عبر زر «معاينة حركة التنبيهات والحجوزات»؛ لا يحاكي إصدار JWT ولا وصول إشعار من الخادم.


- `36d649d77fb63c7cdf02334bba6e2b6dca8e2db0`: إصلاح مسار النسخ الاحتياطية للملفات المصغرة السابقة: تحفظ خارج مجلد `assets/images/` عند `%LOCALAPPDATA%\\Maqwati\\BrandBackups` كي لا تُضمّن `.bak` في APK عبر `pubspec.yaml`.
- **قيد شهادة البناء:** ملف APK المرتبط بتشغيل #44422665231 بُني قبل إضافة زر معاينة Debug وسكربتات التحقق، لذلك لا يحتوي زر المحاكاة الجديد. لا تُظهر ملف APK القديم على أنه أحدث بناء حتى تنجح دورة GitHub Actions على أحدث SHA ويتولد artifact جديد.
