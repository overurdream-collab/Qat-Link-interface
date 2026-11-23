# تنزيل APK — روابط عامة مختبرة

آخر تحقق:2026-11-23. نُزّل الملفان كاملاً عبر طلب GET دون ترويسة Authorization أو تسجيل دخول، وكانت النتيجة HTTP200 لكل منهما. فُحص حجم كل APK وSHA256 مقابل digest المنشور في GitHub، وسلامة ZIP وصور الهوية الثلاثة وصلاحيات Android.

| النسخة | رابط APK المباشر | اسم التطبيق عند التثبيت | الحجم |
|---|---|---|---:|
| الدخول | [maqwati-test-login.apk](https://github.com/overurdream-collab/Qat-Link-interface/releases/download/maqwati-test-45116030353/maqwati-test-login.apk) | Maqwati اختبار |68884583 بايت|
| تصفح التاجر والعميل | [maqwati-test-browse.apk](https://github.com/overurdream-collab/Qat-Link-interface/releases/download/maqwati-test-45116030353/maqwati-test-browse.apk) | Maqwati تصفح |68884767 بايت|

[صفحة الإصدار التجريبي](https://github.com/overurdream-collab/Qat-Link-interface/releases/tag/maqwati-test-45116030353) تعرض الملفين أيضاً. الروابط لملفات APK مباشرة ولا تحتاج فك ZIP. بخلاف Artifacts، لا ترتبط بفترة احتفاظ7أيام؛ تستمر ما دام الإصدار وأصوله منشورين. المسارات `/workspace/artifacts/...` في المحادثة السابقة لم تكن طريقة تنزيل مناسبة للعميل المستخدم.

## مصدر النسختين

نُشرت النسختان مسبقاً من commit80636f8d2738f5b4e92517b8ce695b0a26488aa7، وليس commit3464f45 نفسه. مقارنة المصدر تثبت أن lib وassets وtest والاعتماديات متطابقة؛ الفروق الوحيدة workflow جديد وتكييف سكربتي تجربة Android لاختيار اسم الحزمة من البيئة. يولد workflow هويتين واسمي تطبيق مستقلين؛ لذلك تختلف بايتات APK وبصماتهما عن حزم3464f45 الواردة في تقرير القبول. لم تُستبدل تلك البصمات أو يُنسب بناء جديد للمصدر القديم.

[Actions45116030353](https://github.com/overurdream-collab/Qat-Link-interface/actions/runs/45116030353): جميع المهام السبع ناجحة، ومنها الاختبارات وبناء وتجربة النسختين ونشرهما. [دليل فحص التنزيل والمقارنة والأصول](ui_evidence/apk_public_download_verification_20261123.json).

- الدخول: `com.maqwatilink.testing.login20261123`؛ SHA256: `fcba366cff84ce3b581f79ac06249fdd595dfe9415c4e73615f8b1036ca9d6ac`.
- التصفح: `com.maqwatilink.testing.browse20261123`؛ SHA256: `7efe8196c120f5ca054bbd41588c2e3e01df8a3a7aaf4c26f90afb5b1fd8d16d`.

صور الرجل1086×1448، المرأة1024×1536، والشعار1254×1254 داخل كل APK تطابق بايتات الأصول المعتمدة للاستخدام بتوجيه المالك. النسختان معاينة دون اتصال، release بتوقيع debug، ولا صلاحية INTERNET أو مصادقة/عمليات مالية إنتاجية. لا يغير توفير التنزيل العام نتيجة البوابات غير المكتملة في [تقرير القبول](UI_RELEASE_ACCEPTANCE.md).
