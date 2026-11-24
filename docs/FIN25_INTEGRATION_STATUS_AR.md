# FIN25 — مسار تكامل Samsung الآمن (فرع مستقل)

## حدود التغيير
- أُنشئ الفرع من main؛ لا تعديل على ترحيلات 001–008 ولا على قاعدة Docker.
- هذا التغيير يضيف وحدة تشفير مستقلة واختبارات اصطناعية؛ **ليس API تسجيل أجهزة جاهزاً**.
- مرجع مخطط FIN25 في PR #51: `server/sql/008_fin25_sms_gateway_devices.sql`، لكنه ليس في main، وقد يتعارض مع ترحيل OTP 007 في PR #44.
- **لا تنفذ 007 القديم و008 FIN25 معاً دون إعادة تصميم**؛ الأول يعرف sms_gateway_devices(id,public_key_pem,enabled)، والثاني يعرف (device_id,public_key_spki_pem,status).
- لا نعتمد جهازاً بحالة pending. يتطلب الاعتماد تحدياً مخزناً بصلاحية 120 ثانية، وتوقيعاً صحيحاً، واستهلاك التحدي مرة واحدة، ثم موافقة مسؤول منفصلة موثقة.
- توقيع HTTP المتوافق مع Android هو RSA-SHA256 على method + path + timestamp-ms + nonce + raw-json-body مفصولاً بـ LF.
- التوقيع وحده لا يمنع replay: يجب تسجيل nonce بشكل ذري في PostgreSQL، وإلزام timestamp، ورفض الأجهزة غير active.
- لا يوجد في هذا الفرع بعد HTTPS gateway server أو worker Android أو OTP/JWT bridge.
- يجب أن تصدر JWT فقط من خدمة الهوية الموثوقة، بعد استهلاك proofToken والتحقق من الحساب والدور، وفق FIN08 auth.mjs.
- اختبار SMS حقيقي يتطلب Samsung والشريحة والشبكة وإذن المستخدم الصريح؛ لا يمكن إثباته بواسطة CI.

## مسار العمل التالي
1. مراجعة مخطط PostgreSQL الفعلي من نسخة اختبار منفصلة مع سجل migrations؛ عدم لمس قاعدة المستخدم.
2. بناء ترحيل إضافي متوافق لا يغيّر 001–008 بعد معرفة المخطط الحقيقي.
3. تنفيذ enroll/challenge/prove/admin approve + signed heartbeat/poll/result في Backend مع transactions.
4. نقل Android client إلى فرع التكامل، تشغيل foreground service بعد موافقة المستخدم، وتسجيل ACK وإدارة حالات unknown.
5. اختبارات Node/Postgres/Android CI وAPK؛ لا دمج قبل النجاح.
