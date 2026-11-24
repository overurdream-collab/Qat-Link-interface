# مقوتي لينك — اعتماد بوابة واحدة وتطبيق واحد

**المستودع:** `overurdream-collab/Qat-Link-interface`، فرع التكامل القائم `integration/fin25-identity-consolidation-20261121`، ثم `main` بعد نجاح القبول. **لا يُنشأ فرع أو Gateway جديد لهذه المهمة.**

## المعمارية الرسمية

```text
Maqwati Android -- HTTPS stable host --> FIN25 EXISTING Caddy
                                      |-- POST /v1/auth/otp/public-request -> FIN25 OTP
                                      |-- POST /v1/auth/otp/verify         -> FIN25 OTP
                                      |-- POST /v1/identity/session        -> P0 Identity
                                      |-- GET  /v1/identity/me             -> P0 Identity
                                      |-- /v1/gateway/...                  -> existing FIN25 device API
Identity (private Docker network) --------> FIN25 internal OTP proof (JWT + internal API key)
Identity (private Docker network) --------> FIN08 internal finance provisioning
```

- **تطبيق Flutter واحد:** يقرأ `MAQWATI_API_BASE_URL` من إعداد بناء واحد؛ ممنوع أن يكون عنوانًا مؤقتًا `*.trycloudflare.com` أو `http://` أو localhost. لا يطلب التطبيق إدخال URL ولا مفتاح اختباري ولا معرّف OTP يدويًا.
- **Caddy قائم بالفعل:** التعديل في `deploy/fin25/Caddyfile` الأصلي، لا بوابة أو Tunnel إضافي. يبقى مسار `/v1/internal/otp/proof` **خاصًا بالشبكة الداخلية**.
- **الهوية والحسابات:** `FIN25` يفحص OTP ويصدر إثباتًا أحادي الاستخدام؛ `Identity` يستهلكه ويُصدر JWT؛ `/me` يتحقق من الجلسة؛ تسجيل FIN08 لا يعني الموافقة على علاقة تاجر–عميل أو قيود مالية.
- **طلب الرسائل العام:** `/v1/auth/otp/public-request` منفصل عن مسار المسؤول المحلي. يحافظ على حدود الهاتف القديمة ويضيف حدًا **عالميًا ذريًا على PostgreSQL** قابلًا للضبط؛ الافتراضي 12 رسالة/ساعة. مغلق افتراضيًا `OTP_PUBLIC_REQUEST_ENABLED=false`. حظر الطلبات العامة لا يمنع عامل Android الحالي من إرسال الرسائل المحلية.

## حماية مطلوبة قبل التفعيل

1. اسم مضيف HTTPS ثابت، وشهادة موثوقة إلى تطبيق الهاتف، مع جدار حماية عند الحافة وقيود معدل حسب IP / السلوك، ومنع الإساءة الآلية. **الحد العالمي في قاعدة البيانات لا يغني عن WAF**.
2. نشر وتأكيد `FIN25` OTP service الجديدة و`Caddyfile` الأصلية بتغيير محسوب؛ لا تعدّل قاعدة البيانات أو تفصل جهاز SMS أثناء العملية.
3. فحص أن `identity:8090` قابل للوصول من Caddy القائم على شبكة Docker نفسها، وأن مفاتيح التوقيع والثقة الحية متطابقة عبر `scripts/check_identity_runtime_trust.mjs` **دون طباعة الأسرار**.
4. تحقق سلبي قبل فتح الطلب العام: `POST /v1/auth/otp/public-request` يعيد `503` عندما يكون العلم `false`؛ `/v1/internal/otp/proof` يعيد `404` من الإنترنت؛ `/v1/identity/me` يعيد `401` بلا جلسة؛ `/healthz` يعيد `200` بعد جاهزية Identity.
5. بعد موافقة المشغل على الميزانية وWAF، تفعيل `OTP_PUBLIC_REQUEST_ENABLED=true` و`OTP_PUBLIC_MAX_PER_HOUR=12` (أو ميزانية مدروسة أقل)، ثم مراقبة HTTP 202/429 ومزامنة Android، مع خطة إيقاف فوري بإعادة `OTP_PUBLIC_REQUEST_ENABLED=false`.
6. إعداد متغير GitHub Actions repository `MAQWATI_API_BASE_URL=https://your-permanent-host.example/` لتجميع **APK واحد فقط** باسم `maqwati-unified-login-apk`. لا تنشر APK بدون عنوان ثابت.
7. سيناريو قبول عملي على الهاتف: رقم موجود ← طلب واحد ← وصول SMS ← إدخال الرمز في التطبيق خلال 5 دقائق ← إصدار JWT ← تأكيد `/v1/identity/me` ← شاشة «حساب موثّق». تسجيل رقم جديد يختبر عبر مسار إنشاء الحساب ودور عميل/تاجر صريح، بدون أي علاقة أو حركة مالية تلقائية.
8. اختبارات عدم إساءة الاستخدام: تجاوز ميزانية 12 رسالة/ساعة → 429، رمز خاطئ/منتهي → 401، Proof معاد → 401، لا يمكن تجاوز دور موجود، ولا فتح الدفتر المالي دون صلاحياته.

## منع التكرار والتراجع

- **لا تنشئ Docker Compose stack جديدًا**، ولا تستخدم `Caddyfile.android-login-pilot` للتشغيل الفعلي. البوابة الموحّدة هي Caddy الحالي فقط.
- لا تُدمج التغييرات إلى `main`، ولا تُحذف الحاويات/الأحجام/الشهادات القديمة حتى نجاح اختبارات القبول. `git push` لا يغيّر الحاويات الجارية.
- للحماية السريعة عند خلل الإرسال: عطّل **فقط** `OTP_PUBLIC_REQUEST_ENABLED` واترك بوابة جهاز FIN25 فعالة.
- لا تعلن جاهزية التطبيق المالي للإطلاق بمجرد نجاح تسجيل الدخول؛ شاشة الحساب الموثق لا تعرض بيانات مالية حتى ربطها بخادم حقيقي وفق موافقة الطرفين.

## نقطة التوقف المؤكدة — بعد قبول النشر الحي (21 نوفمبر 2026)

**اكتمل نشر وتفعيل صورة OTP الجديدة على نفس الحاوية الحالية** `fin25-test-otp-1`، ومعرف الصورة الفعلية هو `sha256:310d4573e701066e6bc0c95ceefe3cac4fa5d5e2d11b889715d175b3e705797c`، وحالة الحاوية `running`. يجب الإبقاء على الملف `F:\maqwatilink-fin25\deploy\fin25\otp-unified-promotion.override.yml` مع `preserve-live.override.json` في أوامر Compose اللاحقة، منعًا للعودة غير المقصودة إلى صورة OTP السابقة.

**أثبت المستخدم 5/5 PASS فعليًا من بوابة Caddy الحالية**:

```text
/healthz                    GET  200 PASS
/v1/identity/me             GET  401 PASS (بدون جلسة)
/v1/internal/otp/proof       POST 404 PASS (غير مكشوف)
/v1/auth/otp/request         POST 403 PASS (محظور خارجيًا)
/v1/auth/otp/public-request  POST 503 PASS (معطّل عمدًا)
```

هذا اختبار لمسارات localhost فقط باستخدام شهادة الأصل المحلي؛ **لا يثبت** وصول Android من خارج الجهاز أو وجود نطاق HTTPS دائم ذي شهادة موثوقة أو WAF أو اكتمال جلسة هاتف فعلية.

**ممنوع إعادة نشر Caddy أو تشغيل سكربت `promote_existing_otp_only.ps1 -Apply` بلا داعٍ؛ العمل الباقي هو الحافة الخارجية وAndroid.** يتطلب ذلك نطاقًا ثابتًا محميًا، وقيود معدل موثوقة، والتحقق من TLS من الهاتف، وتحديد `MAQWATI_API_BASE_URL` في GitHub Actions، ثم اختبار تسجيل دخول واحد بإشراف المستخدم.

**حاجز إصدار Android الجديد:** لا يكتفي GitHub Actions بصحة صيغة `MAQWATI_API_BASE_URL`. عند تكوينه يفحص DNS/TLS والشهادة العامة (دون `-k`) ثم يتطلب استجابة المسارات الخمسة `200/401/404/403/503` قبل بناء APK المتصل أو نشره. عدم تعيين المتغير لا يجعل APK التجريبي الافتراضي صالحًا للدخول. هذا فحص HTTPS فقط ولا يغني عن حماية الحافة أو اختبار هاتف فعلي.

**للتسليم والاستكمال دون تكرار:** اقرأ [وثيقة التسليم المحدثة](HANDOVER_UNIFIED_AUTH_2026-11-21_AR.md).
