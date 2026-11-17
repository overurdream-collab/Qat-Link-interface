# إعداد تكامل OTP عبر هاتف Android — مقتني لينك
الحالة: عقد تكامل وإعدادات أولية؛ **لم يُنفذ إرسال SMS أو تسجيل دخول حقيقي بعد**.

## الحدود الأمنية
- تطبيق Flutter يتصل فقط بخادم الهوية HTTPS؛ لا يتصل بالهاتف ولا يحتفظ بمفاتيح الجهاز.
- خادم الهوية ينشئ رمزاً عشوائياً باستخدام CSPRNG، ويحتفظ فقط بـ HMAC/تجزئة مقاومة للتخمين مربوطة بمعرف الطلب ومدة الانتهاء، ولا يسجل الرمز نصاً.
- الهاتف يتصل **صعوداً فقط** بالخادم عبر HTTPS لجلب المهام؛ لا حاجة إلى IP عام للهاتف.
- يسجل الجهاز بمفتاح خاص غير قابل للتصدير في Android Keystore، وتتحقق الخدمة من توقيع كل طلب ومن timestamp وnonce لمنع replay.
- لا يُقبل ادعاء sent من الهاتف كإثبات ملكية الرقم. إصدار JWT فقط بعد تقديم الرمز الصحيح إلى خادم الهوية.
- يجب تخزين جلسات refresh على الخادم باستخدام hash، مع rotation/revocation وربطها بالمستخدم والجهاز.
- التاجر والعميل يحددان دورهما من سجلات الحسابات الموثوقة؛ لا يُقبل role أو merchant_id أو customer_id من طلب OTP.
- عند إثبات رقم الهاتف، استدعِ المسار الداخلي الموثوق /v1/internal/verified-phones وفق صلاحيات خدمة الهوية، دون اعتماد علاقات أو ديون تلقائياً.

## واجهات تطبيق Flutter ↔ خادم الهوية (مقترحة؛ غير منفذة)
POST /v1/auth/otp/request  {phone, purpose:"login"} → {requestId, retryAfterSeconds, expiresInSeconds}
POST /v1/auth/otp/verify   {requestId, code} → {accessToken, refreshToken, expiresInSeconds}
POST /v1/auth/token/refresh {refreshToken} → rotated tokens
POST /v1/auth/logout       {refreshToken} → 204
استخدم رسائل عامة عند الطلب لمنع كشف وجود الحسابات، وحدوداً على IP والرقم والجهاز.

## واجهات الهاتف ↔ الخادم (مقترحة؛ غير منفذة)
POST /v1/gateway/devices/register (يتطلب موافقة إدارية أولية وربط المفتاح العام)
POST /v1/gateway/poll {deviceId, capacity} → مهام قصيرة العمر مع lease
POST /v1/gateway/jobs/{id}/result {status:"sent"|"failed"|"delivered",simSlot,errorCode?}
POST /v1/gateway/heartbeat {deviceId,simStatuses}
كل طلب جهاز يحمل توقيعاً ورقماً عشوائياً وتوقيتاً، ويُرفض تكرار jobId؛ يستخدم الجهاز ACK بعد تأكيد إرسال SMS من Android sent PendingIntent، وليس بمجرد استدعاء SmsManager.

## سياسة الشريحتين
- افحص اشتراكات SIM الفعالة، واختر subscriptionId الفعلي للشريحة المختارة؛ لا تعتمد SmsManager.getDefault() في هاتف ثنائي الشريحة.
- round_robin افتراضياً؛ SIM بديلة عند الفشل، مع منع إعادة إرسال قد يكرر رمزاً سبق تسليمه.
- طابور لكل شريحة، إرسال متسلسل، فجوة 3 ثوانٍ، وإعادة محاولات بأخطاء قابلة للإعادة فقط.
- قد يلزم منح SEND_SMS وصلاحيات الهاتف بحسب إصدار Android وطريقة تثبيت APK؛ تحقق على الجهاز الفعلي.
- لا يحتفظ تطبيق الهاتف بنص OTP بعد انتهاء المهمة، ولا في logs أو crash reports. احتفظ فقط بمعرف المهمة ورقم مقنّع وحالة الإرسال.
- انتبه إلى أن Android قد يحفظ الرسالة المرسلة في مخزن SMS النظام؛ راجع سياسة الاحتفاظ على الجهاز ولا تفترض انعدام الأثر النظامي.

## بوابات الإطلاق
1. تنفيذ خادم الهوية وقاعدة بيانات OTP والجلسات ومفاتيح الأجهزة، وليس الاكتفاء بملف env.
2. تنفيذ Android APK خاص وتجربة شريحتين فعليتين وتأكيد send/delivery وoffline/retry.
3. ربط Flutter بواجهات OTP وبـ JWT RS256 الذي يقبله FIN08؛ منع الدخول التجريبي.
4. اختبارات rate-limit, replay, brute-force, duplicate delivery, SIM failover, offline, JWT refresh/revoke.
5. لا تفعل OTP_ENABLED=true إلا بعد نجاح الاختبارات. لا تضع المفاتيح الخاصة أو بيانات الشريحة في Git.
6. مسار إصلاح سلامة الدفتر P0 مستقل، ويظل حاجزاً أمام إطلاق التطبيق المالي.
