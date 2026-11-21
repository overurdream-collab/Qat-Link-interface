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

**تحديث مثبت من سجل المستخدم الساعة 22:38 تقريبًا:** شغّل المستخدم `stage_existing_otp_update.ps1` من نسخة الفرع عند Commit `ffb3154` وظهرت النتائج `BACKUP=F:\maqwatilink-fin25\deploy\fin25\otp-stage-backup.20261121-223808`، ثم `COMPOSE=PASS PUBLIC_OTP=DISABLED`، ونجاح Docker build (12/12)، وأخيرًا `OTP_STAGE=PASS`. صرّح السكربت بأن الحاويات العاملة لم تتغير. **لا تعِد تشغيل سكربت التحضير أو نسخ المصدر مجددًا دون سبب.**

الأمر الجاهز على Windows PowerShell:
```powershell
$p='F:\maqwati-integration-fin25-20261121'
git -C $p pull --ff-only origin integration/fin25-identity-consolidation-20261121
if($LASTEXITCODE -ne 0){throw 'Git pull failed'}
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\stage_existing_otp_update.ps1"
```
**هذا الأمر نُفذ بالفعل ونجح؛ محفوظ هنا للتوثيق فقط، لا يُطلب تكراره.** هو لا يثبت تشغيل الكود الجديد داخل الحاوية، ولا يجيز فتح الرسائل العامة.

**الأولوية الآن تدقيق هوية صورة Docker قبل أي استبدال**: سجل البناء يعرض `exporting config sha256:582401dd...` و`manifest list sha256:310d4573...`، لكن `naming to docker.io/library/sha256:784837db...`، وهو بالضبط النص الظاهر في `OLD_RUNNING_IMAGE=sha256:784837db...`. التسمية وحدها ليست دليلًا أن الصورة الجديدة مطابقة للصورة القديمة أو مختلفة عنها. افحص `docker image inspect` (معرّف الصورة الفعلي، الوسم، وقت الإنشاء)، و`docker compose images otp`، ومحتوى صورة OTP الجديدة بعد البناء، دون إعادة تشغيل الخدمات أو عرض أسرار. **لا تستبدل الحاوية قبل إثبات أن الصورة المرشحة جديدة ومعرفة آلية تراجع موثوقة**. بعد التحقق جهز **استبدال حاوية `otp` وحدها** بالاعتماد على ملفات Compose الأصلية والـoverride نفسه، مع صورة قديمة محددة كمرجع تراجع، ومع فحوص HTTP وسلامة العمل الحالي. لا تستخدم `docker compose down`، ولا تعِد إنشاء `enrollment` أو `https` أو PostgreSQL، ولا تمس FIN08 أو Identity. قبل أي استبدال فعلي قد يؤثر على خدمة SMS، أبلغ المستخدم بالعملية والأثر المحدود وخطة التراجع.

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
3. يعد نتيجة `OTP_STAGE=PASS` مثبتة من سجل المستخدم، ثم يتحقق من هوية الصورة المبنية وتعارض وسمها مع معرّف الصورة القديمة، ويكمل من هنا دون إعادة خطوات Caddy أو التحضير.
4. يوثّق كل عملية فعلية مع حالة `PASS/FAIL/BLOCKED` ودليل محدد، ويفصل بين تحديث الكود وبين الحالة الحية على Windows.
5. يحفظ تحديثات التسليم في المستودع نفسه بعد كل نقطة قبول.

**حالة التسليم المحدثة:** `Caddy live=PASS`، `OTP source/Compose staged=PASS`، `OTP Docker build=PASS`، `New vs old image identity=NEEDS VERIFICATION`، `OTP live swap=NOT DONE`، `Public SMS=DISABLED`، `Actual Android Identity login=NOT YET PROVEN`.


## 8. سجل الحالة بعد تسليم المستخدم (2026-11-21، بعد 22:38)

```text
BACKUP=F:\maqwatilink-fin25\deploy\fin25\otp-stage-backup.20261121-223808
COMPOSE=PASS PUBLIC_OTP=DISABLED
Docker build: FINISHED 12/12
Export config: sha256:582401dd3b7b8408d15a815a1af2f0e0c929f8fe5cf59448e4010af6fc079b6b34
Export manifest list: sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c
Naming: docker.io/library/sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e
OTP_STAGE=PASS
OLD_RUNNING_IMAGE=sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e
```

**تفسير مقيد بالأدلة:** التحضير ناجح، الحاوية العاملة لم تستبدل، ولا نستنتج هوية الصورة الجديدة من قيمة `Naming`. لا تُدخل أي بيانات أو مفاتيح من `.env` في المستودع أو المحادثة. الخطوة التالية هي فحص هوية صور Docker ومصدر تكوين البناء قراءةً فقط، قبل اتخاذ قرار التبديل.

## 9. حسم تعارض مرجع صورة OTP — دليل من Docker (2026-11-21، نحو 22:51)

أظهر فحص المستخدم اللاحق:

```text
Effective Compose otp.image = sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e
Running OTP image           = sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e
Built candidate image       = sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c
Base compose image line     = caddy:2-alpine (HTTPS service)
Preserve-live override otp  = sha256:784837db48892b78b2801fc027021c885fe9782dece551fd6ecf18719fde1a9e
```

**السبب مثبت:** `preserve-live.override.json` يثبّت صورة OTP القديمة صراحة؛ أمر البناء نجح لكن الحاوية لم تتغير. لا تعدّل ملف الحماية ولا تغيّر وسوم الصور القديمة.

أُضيف `scripts/promote_existing_otp_only.ps1` لاستخدام **ملف override إضافي لخدمة OTP وحدها** مع نفس مشروع Compose ونفس ملف الحماية. الوضع الافتراضي فحص مسبق بدون إعادة تشغيل. عند `-Apply` فقط، يُنشئ الحاوية `otp` مجددًا باستخدام صورة `310d...` و`--no-deps --no-build`؛ ويتحقق من أن الطلب العام يرجع `503` مع `OTP_PUBLIC_REQUEST_ENABLED=false`، وأن `/healthz=200` و`/me=401` و`/internal/otp/proof=404` و`/request=403`. عند فشل التحقق يُحاول الرجوع إلى الصورة القديمة بتوجيه Compose الأصلي. **الملف يحتاج إثبات نجاح فحص PowerShell CI وتشغيل الفحص المسبق محليًا، ولا توجد نتيجة نشر حي حتى الآن.**

الأمر للفحص فقط (لا يوقف خدمات):
```powershell
$p='F:\maqwati-integration-fin25-20261121'; git -C $p pull --ff-only origin integration/fin25-identity-consolidation-20261121; if($LASTEXITCODE -ne 0){throw 'Git pull failed'}; powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\promote_existing_otp_only.ps1"
```

**لا تنفذ `-Apply` قبل نجاح `OTP_PROMOTION_PREFLIGHT=PASS` وفحص نتيجة أحدث CI.** بعد النشر، يجب إدراج ملف `otp-unified-promotion.override.yml` في كل أوامر Compose المستقبلية حتى توحيد التكوين نهائيًا؛ حذفه أو نسيانه قد يعيد اختيار الصورة القديمة.

## 10. قبول تحديث OTP على الخدمة الحية — مؤكد من المستخدم (2026-11-21)

بعد نجاح التحضير، فحص المستخدم الحالة الحية وكانت:
```text
OTP overlay file: F:\maqwatilink-fin25\deploy\fin25\otp-unified-promotion.override.yml
services:
  otp:
    image: sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c

docker inspect fin25-test-otp-1 --format '{{.Image}}'
sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c
docker inspect fin25-test-otp-1 --format '{{.State.Status}}'
running
```

ثم أجرى فحص HTTP عبر Caddy الحالي `https://localhost:8443` وظهرت **جميع الحالات الخمس PASS**:
```text
PASS /healthz HTTP=200 EXPECTED=200
PASS /v1/identity/me HTTP=401 EXPECTED=401
PASS /v1/internal/otp/proof HTTP=404 EXPECTED=404
PASS /v1/auth/otp/request HTTP=403 EXPECTED=403
PASS /v1/auth/otp/public-request HTTP=503 EXPECTED=503
```

**القرار:** تم تأكيد نشر الصورة الجديدة وتشغيلها على خدمة OTP القائمة ونجاح فحوص التوجيه والحظر (5/5). لا تُعِد تشغيل `-Apply`، ولا تحذف ملف `otp-unified-promotion.override.yml`؛ ففقده عند تشغيل Compose مجددًا قد يعيد الصورة القديمة المثبتة في `preserve-live.override.json`. لا حاجة إلى بناء إضافي أو تحديث Caddy في هذه المرحلة.

**حدود الدليل:** فحوص localhost باستخدام `curl -k` لا تثبت ثقة شهادة TLS على Android أو توفر اسم مضيف عام ثابت أو حماية WAF، ولا تختبر إرسال SMS فعليًا أو إتمام جلسة Identity. `503` دليل تعطل endpoint العام عمدًا، وليس دليلًا على إرسال OTP.

**نقطة الاستئناف الجديدة:** التحقق من HTTPS الدائم والشهادة من جهاز الهاتف، وتأكيد ضوابط WAF/rate limits، وربط `MAQWATI_API_BASE_URL` بعنوان ثابت لبناء APK واحد؛ بعدها تشغيل اختبار حقيقي محدود لطلب OTP وتسلّمه والتحقق منه وإصدار Identity JWT و`/me`، دون تمكين وصول مالي غير معتمد. يحافظ المشغّل على نسخة بيانات FIN25 ومفاتيحها وخدمة الجهاز المعتمد ولا يفتح OTP العام قبل حماية الإساءة. 

## 11. استكمال العمل بعد نجاح 5/5 (21 نوفمبر 2026)

أُنجزت تعديلات إضافية على **نفس فرع PR #71** دون مساس بالحاويات الحية:

- `lib/screens/fin25_otp_screen.dart`: إخفاء معرّف طلب OTP الداخلي وعنوان «اختبار تحقق SMS» في شاشة **الدخول الحقيقي**؛ يظل مسار الاختبار اليدوي منفصلاً.
- `test/screens/unified_auth_configured_widget_test.dart`: منع عودة معرّف الطلب الداخلي إلى واجهة الدخول الحقيقية.
- `scripts/check_unified_auth_public_https.ps1`: فحص قراءة فقط لمصدر HTTPS خارجي ثابت؛ يفحص TLS **دون `-k`** ومسارات `/healthz` و`/identity/me` و`/internal/otp/proof` و`/auth/otp/request` و`/auth/otp/public-request`؛ لا يرسل SMS ولا يغير Docker، ويرفض `localhost` و`*.trycloudflare.com`.
- `.github/workflows/p0-auth-ci.yml`: إدخال فحص بنية سكربت HTTPS الجديد ضمن اختبارات PowerShell.
- `docs/UNIFIED_AUTH_RELEASE_GATE_AR.md` و`docs/IDENTITY_HTTPS_SECURITY_GATE_AR_2026-11-21.md`: إزالة التعارض التاريخي الذي كان يصف `PUBLIC_OTP=404` بعد إثبات `503`.

**المانع الخارجي ما يزال قائماً:** لا يوجد حتى هذا التسليم **اسم نطاق عام ثابت مؤكد** أو إثبات WAF ومنع إساءة الاستخدام، ولا يوجد دليل على تعيين `MAQWATI_API_BASE_URL` في إعداد GitHub Actions. لا تستخدم أي Quick Tunnel سابق أو تفترض نطاقاً جديداً.

بعد توفر نطاق HTTPS الدائم وتشغيله عبر Caddy الحالي، شغّل محليًا بعد سحب آخر تغييرات الفرع:

```powershell
$p='F:\maqwati-integration-fin25-20261121';git -C $p pull --ff-only origin integration/fin25-identity-consolidation-20261121;if($LASTEXITCODE -ne 0){throw 'Git pull failed'};powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$p\scripts\check_unified_auth_public_https.ps1" -Origin 'https://YOUR-PERMANENT-HOST/'
```

استبدل `YOUR-PERMANENT-HOST` بالعنوان **الفعلي** بعد ضبط DNS/Cloudflare، وليس بنطاق تجريبي. ظهور `EXTERNAL_HTTPS_ROUTING=PASS` يثبت الحافة والشهادة والتوجيه من جهاز Windows **فقط**، ولا يكفي وحده لإثبات WAF أو نجاح Android أو SMS.

**حالة هذه المرحلة:** اختبار المحلية `5/5 PASS`، وتصحيح واجهة الدخول `COMMITTED`، وفحص HTTPS الخارجي `COMMITTED, NOT RUN (NO CONFIRMED HOST)`، واختبار Android من خارج الشبكة `BLOCKED`، وإرسال SMS العام `DISABLED`. تحقق من أحدث نتائج GitHub Actions بعد كل تعديل قبل أي بناء للتوزيع.

## 11. حسم وضع Cloudflare الخارجي — من فحص المستخدم

```text
TUNNEL_STATUS=running
TUNNEL_MODE=QUICK_TUNNEL
NETWORKS=fin25-test-net
CONFIG_MOUNTS=
```

نفق `fin25-cloudflare-tunnel` الحالي يتيح وصولًا خارجيًا تجريبيًا فقط بعنوان `*.trycloudflare.com` مؤقت؛ لا يمكن استخدامه في `MAQWATI_API_BASE_URL` لإصدار Android متصل ثابت. **لا تغيّر حاويات FIN25 أو Caddy أو OTP أو Identity أو FIN08 لإصلاح ذلك.** الانتقال هو إلى **Named Tunnel** بنطاق مملوك ومضاف إلى Cloudflare، وتوجيه `Published application` إلى خدمة Caddy الحالية على `fin25-test-net`، مع إعداد TLS origin موثوق إن أمكن. لا تشغّل نفقًا جديدًا مؤقتًا ولا تكشف token في ChatGPT أو GitHub.

أُضيف إلى `.github/workflows/p0-auth-ci.yml` حاجز HTTPS فعلي للـAPK المتصل، يمنع نشره قبل نجاح نفس استجابات المسارات الخمسة على النطاق العام مع تحقق TLS (دون `-k`). **لا يوجد اسم نطاق معتمد أو Named Tunnel مثبت حتى الآن**. المطلوب من المالك تحديد نطاق Cloudflare الموجود أو إنشاء نطاق مناسب، ثم إعداد النفق الدائم من لوحة Cloudflare، ثم تحقق خارجي قبل تفعيل طلب SMS العام. لا تستنتج وجود WAF من استخدام Cloudflare وحده.

## 12. قرار المستخدم: Funnel مجاني بلا نطاق — 2026-11-21

**قرار معتمد:** تجربة `Tailscale Funnel` المجاني بدل شراء نطاق الآن، مع إبقاء الخدمات الحالية وعدم تفعيل إرسال OTP العام. توجيه HTTPS العام نحو Caddy الموجود على Windows `https://127.0.0.1:8443`، لا Docker/Compose جديد ولا تغيير Cloudflare الحالي. يمنح Funnel عنوانًا ثابتًا للنظام المُسجّل داخل Tailnet من نمط `https://<device>.<tailnet>.ts.net` مع شهادة TLS عامة. يجب أن يكون جهاز Windows مشغّلًا ومتصلًا إلى Tailscale، وFunnel **يفتح المسارات المعروضة للإنترنت**؛ هذا للاختبار فقط وليس بديلًا لـ WAF.

تم إنشاء `scripts/maqwati_tailscale_funnel_test.ps1`:
- الوضع الافتراضي: قراءة فقط؛ يفحص تثبيت Tailscale وحالة الاتصال وDNS وفحوص FIN25 المحلية الخمسة دون إرسال SMS.
- `-Enable`: يهيئ Funnel على 443 باتجاه `https+insecure://127.0.0.1:8443`. هذا يتجاوز ثقة شهادة Caddy الداخلية *فقط على وصل loopback المحلي*؛ الخارج يستخدم شهادة Tailscale عامة موثوقة. يتطلب تفعيل MagicDNS وHTTPS وFunnel من حساب Tailscale والموافقة على فتح الوصول العام.
- `-Disable`: إغلاق منفذ Funnel 443 دون إيقاف FIN25 أو Cloudflare. **إيقاف Funnel لا يعطّل Tailscale VPN**.
- بعد التفعيل: تشغيل `scripts/check_unified_auth_public_https.ps1 -Origin https://<device>.<tailnet>.ts.net`؛ يتأكد من TLS خارجي سليم ومسارات 200/401/404/403/503. لا تضع عنوانًا في GitHub قبل إثبات الفحص الخارجي.
- `OTP_PUBLIC_REQUEST_ENABLED` يبقى `false`. لا تنشر APK لاختبار إرسال الرمز بعد؛ سينجح الاتصال والرد 503 لكنه لن يرسل SMS، وهذا مقصود. فتح SMS يتطلب ضوابط إضافية؛ Funnel وحده ليس جدار WAF.

**ملاحظة واقعية مهمة:** لم ننفذ السكربت على Windows من هنا، ولم نتحقق أن Tailscale مُثبت أو أن الحساب مسجل؛ لا تدّعِ نجاح HTTPS العام بعد. مسار الاستئناف: تحديث مجلد GitHub المحلي وتشغيل الفحص المسبق وتوثيق نتيجته، ثم تفعيل Funnel بعد تحقق شروط الأمان.

## 13. Tailscale Funnel فعلي — نجاح التوجيه الخارجي 5/5

أثبت المستخدم بعد تثبيت Tailscale وتفعيل Funnel القائم:
```text
Funnel on: https://desktop-3jc03si.tail0e4691.ts.net
/ proxy https+insecure://127.0.0.1:8443
HEALTH_HTTP=200
PASS /healthz HTTP=200 EXPECTED=200
PASS /v1/identity/me HTTP=401 EXPECTED=401
PASS /v1/internal/otp/proof HTTP=404 EXPECTED=404
PASS /v1/auth/otp/request HTTP=403 EXPECTED=403
PASS /v1/auth/otp/public-request HTTP=503 EXPECTED=503
EXTERNAL_HTTPS_ROUTING=PASS (WAF and real SMS still NOT proven)
```

**النتيجة:** عنوان HTTPS من Tailscale مثبت أنه يعمل من جهاز Windows باستخدام شهادة عامة موثوقة، مع إغلاق OTP العام. هذا **نطاق تجريبي مرتبط بالجهاز** وليس نظامًا متاحًا 24/7؛ يجب استمرار تشغيل Windows وTailscale Funnel. لا WAF مثبت ولا إرسال SMS فعلي أو مصادقة كاملة عبر Android حتى الآن. لا تغير Docker أو Caddy أو Identity أو FIN08 أو إعدادات SSL المحلية عند استكماله.

أضيف إلى `.github/workflows/p0-auth-ci.yml` إدخال تشغيل يدوي `workflow_dispatch.inputs.api_origin` لتجميع **APK debug واحد متصل** بكتابة العنوان `https://desktop-3jc03si.tail0e4691.ts.net` فقط أثناء التشغيل؛ لا حاجة إلى وضع العنوان في إعداد دائم بالمستودع. يشترط إنشاء artifact `maqwati-unified-login-apk` اجتياز فحص TLS العام والمسارات الخمسة من GitHub Actions. **إرسال SMS العام لا يزال مغلقًا، ولذلك فإن APK المتصل لا يثبت الدخول الكامل بعد.**

بعد دمج أو سحب هذا التعديل، تشغيل العمل من صفحة GitHub Actions الخاصة بـ`P0 auth integration safety checks` → `Run workflow` → اختيار الفرع `integration/fin25-identity-consolidation-20261121` → إدخال `api_origin` المذكور → `Run workflow`. انتظر نجاح اختبار Android والمصدر الخارجي قبل تنزيل artifact. **لم يُنفذ هذا التشغيل اليدوي بعد من هذه الجلسة ولا يجوز الادعاء بأن APK موجود قبل ظهور الـartifact.**

الحالة: `LOCAL=5/5 PASS`؛ `EXTERNAL_TAILSCALE=5/5 PASS`؛ `PUBLIC_OTP=DISABLED/503`؛ `CONNECTED_APK=NOT YET BUILT VIA MANUAL ACTION`؛ `REAL_PHONE_LOGIN=NOT PROVEN`.

## 14. تم تنفيذ بناء APK المتصل بنجاح عبر GitHub (21 نوفمبر 2026)

**بناء مثبت، وليس مجرد أمر أو خطة:**
- GitHub Actions **push run #44946452032** على commit `5eafee1db72a82e04d234a8b699e23ad3faa608e`.
- مهمة `android-compile=success` وجميع مهام Workflow نفسه `success`.
- ضمن مهمة Android نجحت صراحة: `Validate configured public HTTPS origin`؛ `Check public TLS and unified routes before building a connected APK`؛ `Build the only connected login APK`؛ `Verify single-origin connected APK signature`؛ `Publish one unified Maqwati login APK`.
- artifact حقيقي موجود: `maqwati-unified-login-apk`، ID `14723263481`، أرشيف ZIP حجمه `79,569,717` بايت، المعرّف المشفّر للـZIP `sha256:60c7cc6a8a62170b47149c094cd5e441e462ff688e089468fc45640bbcde947a`، ينتهي احتفاظ GitHub به في **28 نوفمبر 2026**.
- رابط التنزيل من GitHub (يلزم صلاحية المستودع): `https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/44946452032/artifacts/14723263481`.
- عنوان `MAQWATI_API_BASE_URL` الذي استُخدم في هذا التشغيل: `https://desktop-3jc03si.tail0e4691.ts.net`، ولم يضاف إلى المصدر الثابت للتطبيق.
- تم حذف التفعيل المؤقت الخاص برسالة Commit `[build-tsnet-apk]` من Workflow بعد نجاح البناء، مع الإبقاء على خيار `workflow_dispatch.inputs.api_origin` لأي بناء مستقبلي يُشغل يدويًا. آخر Commit للرجوع إلى التكوين الاعتيادي `11ae08ab054e41034582c4d031a0f45e3c548481`.
- ملاحظة: تشغيل `pull_request` لنفس commit #44946456019 نجح لكن تخطى خطوات البناء المتصل؛ نجاح Artifact أعلاه من تشغيل **push #44946452032** ولا يجوز الخلط بينهما.

**قرار المرحلة:** تم **تسليم APK تجريبي متصل** للخادم العام بنجاح من GitHub. لم يجربه المستخدم على الهاتف بعد؛ خدمة `OTP_PUBLIC_REQUEST_ENABLED=false` متعمدة ومثبتة بـ503، لذلك لن يستطيع طلب إرسال SMS من التطبيق في الحالة الحالية. لا تعلن أن دورة الدخول الفعلية أو تفعيل حساب مالي قد نجحا.

**العمل القادم:** تثبيت APK على هاتف Android، اختبار الوصول والاستجابة fail-closed؛ قبل السماح بأي إرسال SMS عام يجب حماية الإساءة (WAF أو طبقة حماية فعلية أخرى، سياسة تكلفة وحدود عددية ومراقبة)، ثم اختبار رسالة واحدة ورمز واحد وإثبات Identity JWT و`/me` تحت رقابة المستخدم. لا تغيّر Docker أو Tailscale Funnel أو OTP image بلا دليل جديد.
