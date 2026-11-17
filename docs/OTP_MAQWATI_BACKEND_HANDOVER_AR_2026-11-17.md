# تسليم تكامل OTP — مقتني لينك / SMS Gateway
**مسؤولية هذا المستودع:** إصدار طلب OTP، إدارة تحديات التحقق، استقبال نتائج الهاتف، إثبات ملكية الرقم، وتكامل جلسات المستخدمين.
**مسؤولية مستودع smsgateway:** التسجيل الآمن للجهاز، سحب مهام الإرسال، SMS sent callbacks، تشغيل الخلفية، SIM1/SIM2، منع التكرار.

## حالة التنفيذ 2026-11-17
- API transport موجود في `server/src/otp_gateway_transport.mjs`، غير موصول بعد بمسار `server/src/index.mjs`؛ يعمل كخدمة مستقلة عند تشغيله صراحة.
- PostgreSQL migration `server/sql/007_otp_android_gateway.sql` مطلوب قبل تشغيل الخدمة.
- Flutter API transport نموذج في `integrations/flutter/otp_api_client.dart`، غير مربوط بشاشة تسجيل الدخول.
- `OTP_ENABLED=false` افتراضياً. لا تفعّل في الإنتاج قبل اختبار CI والبيئة الفعلية.
- `POST /v1/auth/otp/verify` يرجع `proofToken` صالحاً 120 ثانية؛ **ليس JWT ولا يجيز دخول التطبيق**.
- خدمة هوية موثوقة فقط تستبدل الإثبات مرة واحدة عبر `POST /v1/internal/otp/proof` مع `X-Internal-Api-Key`، وتستلم الرقم الموثق. يجب أن تتحقق من المستخدم والدور ثم تصدر JWT RS256 مطابقاً لقيود `server/src/auth.mjs`.
- لا تعتمد علاقة أو ديناً تلقائياً بمجرد نجاح OTP.
- `sms_gateway_jobs` لا يعيد المهمة المؤجرة عند انقضاء lease تلقائياً، تفادياً لتكرار SMS؛ يلزم مسار reconciliation قبل الإنتاج.

## حاجز الأمان
- ما زال P0 سلامة الدفتر في PR #43 غير مثبت باختبارات PostgreSQL مستقلة.
- لم تنفذ اختبارات نهاية-إلى-نهاية أو اختبارات Android حقيقية، ولم تصدر جلسات JWT من OTP بعد.
- لا تنشر مسار OTP عبر HTTP عام: الخدمة تستمع على 127.0.0.1 وتحتاج reverse proxy HTTPS وrate limits على IP.
- لا تستخدم مفتاح الهوية الداخلي نفسه لمفاتيح الهاتف؛ ولا تحفظ أسراراً في GitHub.
- يجب تنفيذ إدارة التسجيل الآمن للهاتف، سياسة إعادة المحاولة، cleanup للرموز وnonces، وإدارة الإبطال والـrefresh tokens قبل الإطلاق.

## واجهات التوافق مع المبرمج الآخر
- `POST /v1/gateway/poll` body `{}` -> `{job:null}` أو `{job:{id,recipient,text}}`.
- `POST /v1/gateway/result` body `{jobId,status,simSlot}`.
- `POST /v1/gateway/heartbeat` body `{}`.
- ترويسات التوقيع: X-Device-Id / X-Timestamp (milliseconds) / X-Nonce / X-Signature (base64 RSA SHA256).
- نص التوقيع: `POST\\n/path\\n<timestamp>\\n<nonce>\\n<raw JSON body>`.
- الجهاز المسجل والمفعّل فقط يحق له سحب المهام. لا تتبادل مفاتيح خاصة.

## الاختبارات المطلوبة قبل الدمج
1. `node --check server/src/otp_gateway_transport.mjs`.
2. تطبيق 001–007 على PostgreSQL 16 معزولة، وفحص request/verify/proof/expiry/replay/failed-attempts.
3. اختبار 100 طلب متزامن على رقم واحد، وحدود IP والرقم، وتحقق OTP بعد الإرسال.
4. اختبار Android sent/failed/unknown result والـduplicate lease.
5. إصدار JWT والتحقق منه عبر FIN08 backend وFlutter.
6. تشغيل CI كامل والتحقق من عدم تداخل PR #43 وPR #44.
