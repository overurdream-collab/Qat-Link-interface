/// Frontend input hygiene only. Does not replace server authentication.
abstract final class AuthInputValidation {
  static String normalizeDigits(String source) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final rune in source.runes) {
      final char = String.fromCharCode(rune);
      final arabicIndex = arabic.indexOf(char);
      final persianIndex = persian.indexOf(char);
      if (arabicIndex >= 0) {
        out.write(arabicIndex);
      } else if (persianIndex >= 0) {
        out.write(persianIndex);
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }

  static String normalizePhone(String value) => normalizeDigits(value)
      .replaceAll(RegExp(r'[\s\-\(\)]'), '');

  static String? phone(String? raw) {
    final phone = normalizePhone(raw ?? '');
    if (phone.isEmpty) return 'أدخل رقم الجوال';
    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
      return 'أدخل رقماً صحيحاً من 9 إلى 15 رقماً';
    }
    return null;
  }

  static String? pin(String? raw) {
    final pin = normalizeDigits(raw ?? '');
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      return 'رمز الدخول يجب أن يتكون من 4 أرقام';
    }
    return null;
  }

  static String? fullName(String? raw) {
    final name = (raw ?? '').trim();
    if (name.length < 3 || !name.contains(RegExp(r'\s'))) {
      return 'أدخل الاسم الكامل (اسمان على الأقل)';
    }
    return null;
  }

  static String? confirmPin(String? value, String initialPin) {
    final error = pin(value);
    if (error != null) return error;
    if (normalizeDigits(value ?? '') != normalizeDigits(initialPin)) {
      return 'رمزا الدخول غير متطابقين';
    }
    return null;
  }
}
