# مقوتي — حزمة اختبار Android للتصميم الجديد

**نوع التسليم:** APK تجريبي Debug للتثبيت على الهاتف وفحص الواجهات فقط.  
**الفرع المعزول:** `feat/maqwati-premium-soft-ui-20261121`  
**غير صالح للإطلاق التجاري** قبل المصادقة الحقيقية، المراجعة الأمنية، الاختبارات وبناء Release موقّع بمفتاح إنتاج معتمد.

## البناء عبر GitHub Actions

1. افتح [Premium Soft UI validation](https://github.com/overurdream-collab/Qat-Link-interface/actions/workflows/premium-soft-ui-ci.yml) واختر تشغيل workflow على الفرع المذكور بعد حل مشكلة GitHub Actions المؤسسية.
2. ينشئ Workflow ملفات Android المفقودة مؤقتاً بواسطة `flutter create --platforms=android --org com.example .`، ولا يغيّر قاعدة البيانات ولا يدمج في `main`.
3. يثبت الحزم ويشغّل `flutter analyze --no-fatal-infos` ثم `flutter test` ثم `flutter build apk --debug`.
4. عند النجاح، نزّل artifact باسم `maqwati-premium-debug-apk`. بداخله `maqwati-premium-debug.apk` و`SHA256SUMS.txt` و`BUILD_INFO.txt`.
5. لا تنشر هذا الملف عبر متجر التطبيقات. `com.example` معرف اختبار مؤقت؛ هوية الحزمة النهائية وتوقيع الإصدار قرار منفصل.

## بناء بديل على ويندوز 11

تتطلب العملية Git، Flutter 3.44 أو إصداراً متوافقاً، Android SDK/JDK مهيئين وتوفّر الإنترنت لتنزيل الاعتماديات إن لزم.

```powershell
git fetch origin
git switch feat/maqwati-premium-soft-ui-20261121
git pull --ff-only
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\premium-ui-verify.ps1
```

سيقوم السكربت بإنشاء هيكل Android عند غيابه، وإظهار اسم «مقوتي»، والتحقق بالتسلسل من الحزم وتحليل Dart واختبارات Flutter وبناء APK. **يتوقف عند أول فشل** ويحتفظ بالسجلات.

مخرجات النجاح المحلي:
- `build/premium-delivery/maqwati-premium-debug.apk`
- `build/premium-delivery/SHA256SUMS.txt`
- `build/premium-validation/build-info.txt` وسجلات كل خطوة

## اختبار قبول الهاتف
- تسجيل الدخول يطلب رقم الجوال ورمز الدخول فقط، ولا يسمح بالدخول المالي بواسطة التحقق المحلي وحده.
- خيار «معاينة واجهات التاجر» وخيار «معاينة واجهات العميل» لا يمنحان صلاحية حسابات فعلية.
- فحص التدرجات الأزرق/البنفسجي والوردي الخاص بالأنثى، والوضع الليلي وخط Cairo وRTL.
- ظهور بطاقات YER وSAR وUSD منفصلة؛ الرصيد المعتمد = الديون المعتمدة − الدفعات المعتمدة، والمعلقات لا تُحتسب.
- لا تُعتمد إضافة عميل أو عملية مالية دون موافقة الطرفين. لا تُبدّل الألوان حالة العملية المحاسبية.
- فحص الشاشة عند 320/360/390/430 dp، ولوحة المفاتيح والتباين وعدم تجاوز العناصر.
- الشخصية الحالية أصل مؤقت؛ لم يتم تضمين النسخة المعاد تلوينها الخاصة بالثيم الوردي في APK.

## العائق الحالي
[Issue #69](https://github.com/overurdream-collab/Qat-Link-interface/issues/69) يوثق فشل jobs حتى في تجربة `echo` منفصلة عن Flutter، دون خطوات أو سجلات. المثال الأحدث من هذه المرحلة: [Run #44891268339](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/44891268339). لا يجوز اعتبار فشل هذا التشغيل دليلاً على فشل تحليل Flutter أو نجاحه. لا يوجد APK موثّق النجاح حتى الآن.

## بوابة الدمج
يبقى [PR #70](https://github.com/overurdream-collab/Qat-Link-interface/pull/70) **Draft**. لا دمج أو إصدار Production قبل CI ناجح، مراجعة الصور والوظائف، المصادقة/OTP، فحوص الأمان والدفتر المالي، وتوقيع الإنتاج المعتمد.
