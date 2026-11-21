# وثيقة تسليم العمل — مقوتي لينك | FIN25 + Identity + FIN08

**تاريخ التسليم:** 21 نوفمبر 2026  
**الهدف الحالي:** إكمال تسجيل دخول فعلي من تطبيق Android عبر بوابة HTTPS واحدة قائمة، دون إنشاء بوابات أو فروع أو نسخ APK تجريبية جديدة.  
**المستودع:** `overurdream-collab/Qat-Link-interface`  
**الفرع المعتمد للعمل المتبقي:** `integration/fin25-identity-consolidation-20261121`  
**طلب الدمج:** PR #71 — مسودة (Draft) إلى `main`، لا تُدمج قبل القبول.  
**آخر تعديل معروف أثناء إعداد التسليم:** `ffb3154c251a60e65f0c7181ed6539ea438418e6` — إصلاح مُنشئ ترميز UTF-8 في سكربت إعداد OTP.

## 1. القرار الفني غير القابل للتراجع دون مبرر

- **تطبيق واحد، بوابة Caddy واحدة، مستودع واحد، وفرع التكامل الحالي**. لا تفتح بوابة Cloudflare جديدة أو Docker Stack جديدًا لعلاج هذه المشكلة.
- تُستخدم خدمة `FIN25` لنقل رسائل SMS، و`Identity` للتحقق وإصدار الجلسة، و`FIN08` لتخصيص الحساب المالي والصلاحيات. هذه خدمات خلف البوابة نفسها، **ولا تعني توحيد قواعد بياناتها**.
- نقطة النهاية المستقرة في Flutter هي `MAQWATI_API_BASE_URL` وتُضبط عند البناء، لا من شاشة دخول المستخدم. لا تستخدم `localhost` أو أنفاق `*.trycloudflare.com` المتغيرة في APK.
- يجب أن يظل إنشاء علاقة التاجر–العميل وأي قيد مالي مشروطًا بموافقة الطرفين؛ الجلسة الموثقة لا تتجاوز الصلاحيات المالية، ولا تُعرض بيانات محاكاة بوصفها حسابًا حقيقيًا.

## 2. ما تحقق بالفعل على كمبيوتر المستخدم — دليل من سجلات PowerShell

الحاويات التي ظهرت بحالة `RUNNING`:
`fin25-test-db` و`fin25-test-otp-1` و`fin25-test-https-1` و`maqwati-identity-p0-identity-1` و`maqwatilink-api-1`.

شبكة Docker المشتركة بين Caddy وIdentity: `fin25-test-net`؛ هوية Identity تتصل أيضًا بـ`maqwati-identity-p0_identity-private` و`maqwatilink_internal`.

المسار الفعلي للبوابة الحية:
`F:\maqwatilink-fin25\deploy\fin25\Caddyfile` — bind mount إلى `/etc/caddy/Caddyfile` في `fin25-test-https-1`، وملفات TLS في `F:\maqwatilink-fin25\deploy\fin25\certs`.

**أُنجز تحديث Caddy الأصلي على الحاوية الحية** بواسطة `scripts/deploy_unified_caddy_safe.ps1` ونجحت نتيجة:
```text
HEALTH=200 IDENTITY_ME=401 PRIVATE_PROOF=404 LOCAL_OTP_REQUEST=403 PUBLIC_OTP=404
UNIFIED_CADDY=PASS (does NOT authorize public SMS)
```
النسخة الاحتياطية:
`F:\maqwatilink-fin25\deploy\fin25\Caddyfile.unified-backup.20261121-223035`.

التفسير: خدمة الهوية يمكن الوصول إليها عبر Caddy القائم، و`/v1/internal/otp/proof` غير مكشوف عبره، والمسار القديم لطلب OTP العام محظور. لكن `PUBLIC_OTP=404` يدل على أن **حاوية OTP الحية ما زالت بالصورة القديمة** — لا يُعد تسجيل الدخول من الهاتف مكتملًا.

تكوين OTP الحي: خدمة `otp` ضمن مشروع Compose `fin25-test` وتستخدم الصورة:
`sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e`
ولا تحتوي على bind mounts. ملفات Compose التي استخدمت فعليًا:
```text
F:\maqwatilink-fin25\deploy\fin25\docker-compose.yml
F:\maqwatilink-secrets\identity-recovery-20261120\preserve-live.override.json
```
ملف البيئة الفعلي:
`F:\maqwatilink-fin25\deploy\fin25\.env`.

مجلد التشغيل `F:\maqwatilink-fin25` في حالة `detached HEAD` وفيه تعديلات محلية وملفات شهادات ونسخ احتياطية ومفاتيح جهاز. **لا تنفذ `git reset` أو `git clean` أو `git checkout` على المجلد الحي**. فرق SHA256 لملف `fin25_otp_transport.mjs` بين مجلد التشغيل ومجلد التكامل مثبت في السجل. لا تطلب مشاركة محتويات `.env` أو ملفات المفاتيح.

## 3. ما طُوّر في GitHub

- `lib/services/maqwati_api_config.dart`: أصل HTTPS واحد ثابت للبناء؛ منع العناوين المؤقتة.
- `lib/screens/login_screen.dart` و`registration_screen.dart` و`fin25_otp_screen.dart`: مسار موحد لطلب OTP ثم التحقق منه ثم تبادل إثبات FIN25 مع Identity والتحقق من `/me`؛ أزيل زر اختبار SMS البديل.
- `deploy/fin25/Caddyfile`: توجيه مسار الهوية و`/v1/auth/otp/public-request` و`/verify` على بوابة Caddy الأصلية مع إغلاق `/v1/internal/otp/proof` للعامة.
- `server/src/fin25_otp_transport.mjs`: `public-request` مغلق افتراضيًا بعلم `OTP_PUBLIC_REQUEST_ENABLED=false`، وميزانية إجمالية ذرية على PostgreSQL `OTP_PUBLIC_MAX_PER_HOUR=12` افتراضيًا، مع حدود لكل رقم.
- `deploy/fin25/docker-compose.yml`: إعدادات العلم والميزانية لعملية OTP.
- `.github/workflows/p0-auth-ci.yml`: اختبارات Flutter والهوية وPostgreSQL، وAPK موحد فقط عند تهيئة متغير `MAQWATI_API_BASE_URL` لنطاق HTTPS دائم. نجاح Build افتراضي بدون العنوان **ليس APK للدخول الفعلي**.
- `scripts/check_unified_auth_live.ps1`: فحص قراءة فقط؛ `scripts/deploy_unified_caddy_safe.ps1`: تحديث Caddy مع نسخ احتياطي وتراجع؛ `scripts/stage_existing_otp_update.ps1`: **تحضير وبناء صورة OTP الجديدة فقط دون إعادة إنشاء أي حاوية**.
- `docs/UNIFIED_AUTH_RELEASE_GATE_AR.md`: شروط التفعيل والقبول والتراجع.

نجحت سابقًا اختبارات Flutter والهوية، وفحص الحدود العامة لـOTP على PostgreSQL ببيانات اصطناعية في GitHub Actions. آخر تشغيل CI للتعديل `ffb3154` كان **قيد التنفيذ عند التحقق**؛ لا تدّعِ نجاح آخر تشغيل دون إعادة فحصه.

## 4. نقطة التوقف بالضبط

**الخطوة التالية مباشرة:** لم يُقدّم المستخدم بعد ناتج تنفيذ `stage_existing_otp_update.ps1`. لا تفترض تشغيله أو اكتمال تحديث OTP. الأولوية هي تحضير الصورة دون لمس الحاوية الجارية، ثم تقييم نتيجته.

الأمر الجاهز على Windows PowerShell:
```powershell
$p='F:\maqwati-integration-fin25-20261121'
git -C $p pull --ff-only origin integration/fin25-identity-consolidation-20261121
if($LASTEXITCODE -ne 0){throw 'Git pull failed'}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\stage_existing_otp_update.ps1"
```
النتيجة المتوقعة إن نجح فحص الأمان والبناء: `OTP_STAGE=PASS` مع `BACKUP=` و`OLD_RUNNING_IMAGE=`. **هذه ليست موافقة على استبدال الحاوية أو تفعيل الرسائل العامة**.

بعد نجاح التحضير: افحص الـimage المبنية، صلاحية البيئة، والفارق عن الصورة الحالية، وجهز **استبدال حاوية `otp` وحدها** بالاعتماد على ملفات Compose الأصلية والـoverride نفسه، مع صورة قديمة محددة كمرجع تراجع، ومع فحوص HTTP وسلامة العمل الحالي. لا تستخدم `docker compose down`، ولا تعِد إنشاء `enrollment` أو `https` أو PostgreSQL، ولا تمس FIN08 أو Identity. قبل أي استبدال فعلي قد يؤثر على خدمة SMS، أبلغ المستخدم بالعملية والأثر المحدود وخطة التراجع.

**مهم:** لا يزال `PUBLIC_OTP=404` على الخدمة الحية حتى يثبت العكس. بعد تحديث OTP وبقاء `OTP_PUBLIC_REQUEST_ENABLED=false`، ينبغي أن يصبح الطلب العام غير المصرح `503` بدل `404`؛ هذا إثبات تفعيل المسار المغلق، لا إثبات إرسال رسالة.

## 5. شروط قبول تسجيل دخول Android الحقيقي

1. مصدر HTTPS ثابت وشهادة موثوقة للهاتف، وليس عنوان Quick Tunnel مؤقتًا.
2. حماية حافة بمحددات معدل/WAF لمنع إهدار SMS؛ الميزانية الإجمالية في PostgreSQL حماية إضافية فقط. لا تشغّل `OTP_PUBLIC_REQUEST_ENABLED=true` دون هذه الضوابط.
3. تأكيد تطابق مفاتيح وثقة FIN25/Identity/FIN08 بدون كشف أسرار؛ وفحوص `/healthz=200` و`/identity/me=401` بلا جلسة و`/internal/otp/proof=404` عبر HTTPS العام.
4. بناء APK واحد متصل بالنطاق الثابت، ثم اختبار إرسال OTP واحد من **التطبيق نفسه**، واستلام SMS من الجهاز المعتمد، وإدخال الرمز، والحصول على JWT والتحقق من `/me`. لا تعتبر ظهور شاشة الحساب وحده نجاحًا قبل إثبات الجلسة.
5. منع فتح الدفتر المالي أو تغيير علاقات/قيود مالية من مجرد التحقق من الرقم. الموافقة الثنائية والدفاتر المعتمدة محفوظة.

## 6. ممنوعات التسليم

- ممنوع إنشاء بوابات أو فروع أو Docker stacks أو نسخ APK تجريبية جديدة لمعالجة الدخول.
- ممنوع استبدال ملفات `.env` أو المفتاحين أو `preserve-live.override.json` أو شهادات TLS.
- ممنوع نسخ مجلد GitHub كاملاً فوق `F:\maqwatilink-fin25`؛ اختلاف الملفات وحالة `detached HEAD` يجعلان ذلك خطرًا.
- ممنوع فتح إرسال الرسائل للعامة أو إعادة المحاولة تلقائيًا عند أخطاء غير مؤكدة.
- ممنوع وصف المشروع بأنه «جاهز للإطلاق» أو «تم الدخول فعليًا» قبل الاختبار على هاتف المستخدم.

## 7. ماذا يتسلمه المنفذ التالي؟

1. يبدأ من هذا الملف و`docs/UNIFIED_AUTH_RELEASE_GATE_AR.md` وPR #71.
2. يتحقق من أحدث Commit/CI قبل التعديل، مع المحافظة على الفرع الحالي وعدم إنشاء بديل.
3. يطلب أو يقرأ **فقط ناتج** سكربت تجهيز OTP، ويكمل من آخر حالة مثبتة، دون إعادة خطوات Caddy الناجحة.
4. يوثّق كل عملية فعلية مع حالة `PASS/FAIL/BLOCKED` ودليل محدد، ويفصل بين تحديث الكود وبين الحالة الحية على Windows.
5. يحفظ تحديثات التسليم في المستودع نفسه بعد كل نقطة قبول.

**حالة التسليم عند الإغلاق:** `Caddy live=PASS`، `OTP image staging=NOT YET CONFIRMED`، `OTP live swap=NOT DONE`، `Public SMS=DISABLED`، `Actual Android Identity login=NOT YET PROVEN`.
