/// Frontend input hygiene only. Does not replace server authentication.
abstract final class AuthInputValidation {
  /// Arabic and Persian numeral characters are rejected, not converted.
  static String normalizeDigits(String source) => source;

  /// UI stores the local part only; +967 is displayed separately.
  static String normalizePhone(String value) => value.trim();

  static String? phone(String? raw) {
    final value = normalizePhone(raw ?? '');
    if (value.isEmpty) return 'أدخل رقم الجوال';
    if (!RegExp(r'^[0-9]{9}$').hasMatch(value)) {
      return 'أدخل 9 أرقام إنجليزية (0-9) بعد مفتاح اليمن +967';
    }
    return null;
  }

  static String? pin(String? raw) {
    final pin = normalizeDigits(raw ?? '');
    if (!RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
      return 'رمز الدخول يجب أن يتكون من 4 أرقام إنجليزية (0-9)';
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
