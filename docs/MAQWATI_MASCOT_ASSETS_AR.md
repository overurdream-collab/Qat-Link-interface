# صور شخصية مقوتي للثيمين الأزرق والوردي

المصدر داخل المستودع: `assets/images/maqwati_approved_mascot.jpeg`.

## المسارات المستخدمة في Flutter
- `assets/images/maqwati_mascot_blue.png`
- `assets/images/maqwati_mascot_pink.png`

يختار `context.maqwatiMascotAsset` الملف المناسب بحسب لوحة الألوان، للثيم النهاري والليلي. رُبط في:
- `lib/widgets/auth/auth_brand_hero.dart`
- `lib/widgets/home/premium_home_hero.dart`

يتولد الملفان من المصدر الثابت عبر `python scripts/generate_mascot_assets.py` (Pillow + NumPy). يحافظ إصدار الأزرق على الشخصية الأصلية، ويحوّل الإصدار الوردي تشبعات اللون الأزرق والبنفسجي في لباسها فقط إلى الوردي/الأوركيد، دون تبديل الملامح أو لون البشرة أو الخنجر الذهبي.

يوجد مساران لرفع الملفات الناتجة إلى فرع التصميم: `.github/workflows/generate-maqwati-mascots.yml` وتوليد الأصول في `premium-soft-ui-ci.yml`. يتضمن المساران محاولة Commit تلقائي للصور في الفرع `feat/maqwati-premium-soft-ui-20261121`.

**بوابة التحقق:** لا تعتبر ملفات PNG موجودة في GitHub قبل التأكد من عرضها في `assets/images/`. عند غيابها يستخدم التطبيق الأصل الموجود مسبقاً بدلاً من إظهار صورة معطوبة. يجب فحص صورة هاتف فعلية لضمان المطابقة قبل الدمج إلى main.
