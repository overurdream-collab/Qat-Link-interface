# تسجيل Samsung SMS Gateway يدوياً — بيئة الاختبار فقط

1. ثبّت APK التجريبي على Samsung Note 10، واضغط «إنشاء مفتاح الجهاز الآمن».
2. اضغط «نسخ المفتاح العام ومعرّف الجهاز للمسؤول». المفتاح الخاص لا يغادر Android Keystore.
3. افتح اتصالاً إدارياً آمناً بقاعدة PostgreSQL التجريبية؛ لا تنفذ SQL من التطبيق ولا تشارك المفتاح عبر قناة عامة.
4. بعد التحقق من بصمة SHA-256 الظاهرة على الهاتف، نفّذ SQL التالي باستخدام معرّف الجهاز والمفتاح العام المنسوخين. استبدل القيم المثالـية فقط:

```sql
INSERT INTO sms_gateway_devices (id, public_key_pem, enabled)
VALUES ('DEVICE-UUID-FROM-PHONE', '-----BEGIN PUBLIC KEY-----
PASTE_PUBLIC_KEY_BASE64_HERE
-----END PUBLIC KEY-----', false);
```

5. طابق بصمة المفتاح العام مرة أخرى مع شاشة الهاتف، ثم وافق على الجهاز:

```sql
UPDATE sms_gateway_devices SET enabled = true
WHERE id = 'DEVICE-UUID-FROM-PHONE' AND enabled = false;
```

6. ضع عنوان HTTPS موثوقاً لخدمة OTP في التطبيق، ثم اضغط «حفظ العنوان وفحص اعتماد الجهاز». نجاح heartbeat يثبت الاتصال والمصادقة، **ولا** يثبت إرسال SMS.
7. للإلغاء الفوري: `UPDATE sms_gateway_devices SET enabled=false WHERE id='DEVICE-UUID-FROM-PHONE';`

## شروط الأمان
- لا تفتح PostgreSQL للإنترنت. استخدم Docker مع ربط قاعدة البيانات بـ 127.0.0.1 فقط.
- الخادم الحالي يستمع محلياً على 127.0.0.1:8081؛ للوصول من الهاتف يلزم HTTPS reverse proxy/tunnel موثوق. عنوان localhost على الهاتف لا يشير إلى اللابتوب.
- لا تنشر مفتاح HMAC أو مفتاح AES أو مفتاح API الداخلي في المستودع أو الهاتف.
- لا تفعّل OTP_ENABLED قبل اختبارات التوقيع وnonce وrate limits وJWT وSMS الحقيقي.
- نسخة Android الحالية تتضمن إنشاء الهوية وفحص heartbeat فقط؛ لا يوجد تشغيل آلي للخلفية أو تفعيل إرسال SMS.
