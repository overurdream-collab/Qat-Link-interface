# مصفوفة الثيمات

| النطاق | أزرق نهاري | أزرق ليلي | وردي نهاري | وردي ليلي |
|---|---|---|---|---|
| الدخول: 320/360/390/430/600/800dp | PASS تخطيط | PASS تخطيط | PASS تخطيط | PASS تخطيط |
| الدخول: 640dp ارتفاع، لوحة 260dp، خط 160%، تحقق حقول فارغة | PASS | PASS | PASS | PASS |
| Golden الدخول: ارتفاع 900dp، Cairo وأيقونات فعلية | 6 صور | 6 صور | 6 صور | 6 صور |
| مطابقة الصور المرجعية للمالك | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| هوية PNG في الرئيسية | PASS Widget | PASS Widget | PASS Widget | PASS Widget |
| النص الأساسي والثانوي على الأسطح المحددة | PASS | PASS | PASS | PASS |
| جميع المكونات وجميع الشاشات | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |
| Android فعلي/محاكي | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED | NOT VERIFIED |

الاختبار: `test/ui_audit/login_matrix_test.dart`، 56 اختباراً (48 تخطيطاً + 4 هوية + 4 مجموعات تباين).
RTL فعلي عبر localizations العربية في المصفوفة؛ الوصول بالتمرير إلى زر الدخول والدعم مثبت. لا تدعي المصفوفة اختبار كل أسماء المستخدمين الطويلة والعملات والقوائم في باقي الشاشات.
الصور: `test/ui_audit/goldens/`. هذه baselines مولّدة من التنفيذ، وليست صور موافقة من المالك. CI يقارن بها دون `--update-goldens`.
