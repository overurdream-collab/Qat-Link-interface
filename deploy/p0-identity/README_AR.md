# تشغيل خدمة هوية مقوتي لينك P0 في بيئة اختبار مستقلة
**الحالة: دليل جاهزية تشغيل، ليس تقرير نشر فعلي.** آخر تحديث: 2026-11-19.
المستودع: `overurdream-collab/Qat-Link-interface`، الفرع `feat/p0-auth-identity-integration-20261118`، PR #61.

## الهدف وقاعدة عدم الإضرار
الهدف إصدار جلسة مستخدم موثوقة بعد OTP عبر بوابة FIN25 العاملة، وتهيئة الحساب في FIN08 دون اعتماد علاقات أو قيود مالية. **هذه الملفات لا تعدّل Compose الحالي لـ FIN25 ولا خدمة SMS ولا تعرض مفاتيح خاصة.**
لا تُنفذ خطوات الكتابة في الحاويات على جهاز Windows قبل مقارنة نتائج فحص القراءة فقط وحفظ موافقة تشغيلية منفصلة. تشغيل `docker compose up` أو تطبيق SQL أو إرسال OTP تغيرات تشغيلية لا تدخل ضمن فحوص القراءة.

## ما تحقق في GitHub
1. `server/sql/008_p0_identity_accounts.sql` أصلح النسخة المكررة والمكسورة، ويتضمن قيد `^[+]967[0-9]{9}$`.
2. `server/test/p0_identity_schema_checks.sql` و`identity-postgres-schema` يختبران ترحيل القاعدة في PostgreSQL 16 مؤقتة، والأرقام الصحيحة والخاطئة وتكرار الهوية، دون لمس قاعدة مستخدم.
3. `server/src/identity_server.mjs`: `GET /healthz` لا يعيد ready إلا إذا استطاع الوصول إلى جدول `identity_accounts`.
4. `deploy/p0-identity/compose.yml`: قاعدة جديدة في Volume مستقل، خدمة Node مستقلة، منفذ المضيف **مقيد بـ127.0.0.1** لتوجيهه بواسطة وكيل HTTPS موثوق، وشبكتان خارجيتان *موجودتان مسبقاً* تحددهما نتائج الفحص.
5. `server/Dockerfile.identity`: صورة هوية مستقلة مستخدم Node غير root، وملف البيئة المحلي محجوب بـ `.gitignore`.

## المرحلة 0 — فحص قراءة فقط، دون إرسال رسائل
في نسخة حديثة من **Qat-Link-interface** على Windows:
```powershell
.\scripts\fin25_identity_readonly_preflight.ps1
docker network ls --format "{{.Name}}"
```
افحص أسماء شبكات `fin25-test` وFIN08 والحاويات والصور، وهل توجد متغيرات `JWT_PUBLIC_KEY_PEM` و`JWT_ISSUER` و`JWT_AUDIENCE` و`OTP_INTERNAL_API_KEY` (حالة الحضور فقط، لا القيم). لا تشارك `.env` أو مفاتيح JWT أو رمز OTP مع أي شخص أو في GitHub.

## المرحلة 1 — تجهيز *ملف خاص* على جهاز الخادم (بعد الموافقة)
- انسخ `deploy/p0-identity/identity.runtime.env.example` إلى `identity.runtime.env` محلياً فقط؛ `.gitignore` يمنع رفعه. اجعل صلاحيات الوصول إليه مقتصرة على المسؤول.
- حدد أسماء شبكات Docker الحقيقية بدلاً من placeholders، ولا تنشئ شبكة جديدة داخل FIN25 لمجرد نجاح Compose.
- `POSTGRES_USER=identity_owner` هو دور مالك منفصل؛ واجهة Node تستخدم `identity_app` عبر `IDENTITY_DATABASE_URL`، وهو دور مستقل **غير مالك وغير superuser**. أنشئه بكلمة مرور خاصة منفصلة ثم امنحه فقط `CONNECT/USAGE/SELECT/INSERT/UPDATE` للجدول المطلوب. لا تمنحه `CREATE` أو `ALTER` أو `DROP`.
- جهّز مفتاح RSA مخصصاً للهوية واحفظ الخاص في الخادم وحده؛ تأكد من تطابق العام وissuer/audience مع FIN25 وFIN08 دون نشر قيم مفاتيح.
- حدد `FIN25_INTERNAL_PROOF_URL` لشبكة خدمة OTP الفعلية ومسار `/v1/internal/otp/proof`. لا تستخدم عنوان `trycloudflare` لهذا الاتصال الداخلي.
- حدد `FIN08_INTERNAL_BASE_URL` لخادم مالي فعلي يستطيع رؤية خدمة الهوية عبر شبكة مصرح بها. إذا لم توجد شبكة FIN08 أو خدمة FIN08 عاملة، **توقف هنا ولا تكمل إعداد تشغيل شكلي**.
- تحقق من الصيغة قبل التشغيل. `docker compose config --quiet` لا ينشئ أي حاوية:
```powershell
docker compose -f .\deploy\p0-identity\compose.yml --env-file .\deploy\p0-identity\identity.runtime.env config --quiet
```

## المرحلة 2 — ترحيل القاعدة وتفعيل الهوية (كتابة، تتطلب موافقة تشغيل)
في نافذة صيانة وبخطوات منفصلة:
1. تشغيل **identity-db فقط**، بحجم منفصل عن FIN25 وFIN08. تحقق من اسم المشروع واسم Volume قبل الخطوة.
2. تطبيق `server/sql/008_p0_identity_accounts.sql` باستخدام مستخدم ترحيل مسؤول `identity_owner` على **قاعدة الهوية الجديدة فقط**. تأكد من عدم وجود جدول `identity_accounts` مسبقاً بمخطط مختلف؛ `CREATE IF NOT EXISTS` ليس أداة ترقية لمخططات قديمة.
3. إنشاء `identity_app` وتخصيص كلمة مرور عشوائية، مع `GRANT CONNECT/USAGE` ثم `GRANT SELECT,INSERT,UPDATE ON identity_accounts`. لا تضع كلمة المرور في أوامر محفوظة في history.
4. تشغيل خدمة `identity` وحدها على المنفذ المحلي 8090؛ اختبار `GET http://127.0.0.1:8090/healthz` يجب أن يعيد `{"status":"ready"}`، وبدون جدول يجب أن يعيد 503. هذا الفحص وحده لا يثبت صحة SMS أو FIN08.
5. نشر *نطاق هوية HTTPS موثوق ومستقر* يوجّه إلى منفذ الهوية المحلي. لا تعتمد Quick Tunnel متغيراً لهوية الحساب، ولا تعرّض المسارات الداخلية أو منفذ قاعدة البيانات للإنترنت.

## المرحلة 3 — قبول هاتفين قبل دمج PR أو ادعاء جاهزية
1. ابنِ APK مع `--dart-define=IDENTITY_API_BASE_URL=https://<identity-host>/` باستخدام نطاق حقيقي تم اعتماده؛ لا تكتب العنوان الافتراضي المثال في نسخة القبول.
2. تحقق من URL الـOTP الفعلي الذي يعرضه هاتف Samsung من دون تبديل إعدادات بوابة SMS.
3. هاتف تاجر جديد: OTP صحيح → إثبات مستهلك مرة واحدة → تهيئة `merchant_profile` → JWT بدور merchant → تأكيد `/v1/identity/me`.
4. هاتف عميل جديد: تحقق OTP → إثبات `customer_phone_evidence` → جلسة customer، وظهور العلاقات **معلقة** لا معتمدة تلقائياً.
5. جرّب الرمز الخاطئ/المنتهي/المستهلك، تضارب رقم الهاتف، تغيير الدور، انقطاع FIN08، إعادة محاولة برمز جديد وعدم إنشاء حساب أو قيد مكرر.
6. لا تعتبر واجهة `IdentityAccountScreen` دخولاً مالياً كاملاً؛ صفحات الدفتر المالي الحقيقي تحتاج ربط API وتخويلاً مستقلاً قبل إطلاقها.

## التسليم والإيقاف الآمن
- حدد commit, image digest, تاريخ الترحيل, اسم Volume, أسماء الشبكات, رابط HTTPS, نتائج اختبار القبول ووقت النسخ الاحتياطي في وثيقة تشغيل خاصة **دون الأسرار**.
- عند فشل الهوية أوقف حاوية `identity` الخاصة فقط، ولا توقف `fin25-test-otp` ولا `smsgateway`.
- PR #61 يظل Draft وغير مدمج إلى أن تكتمل الاختبارات الحقيقية والجاهزية الأمنية؛ لا تصف نجاح CI بأنه دخول ناجح على الهاتف.
