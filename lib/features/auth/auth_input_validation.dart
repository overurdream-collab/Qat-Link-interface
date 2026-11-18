/// Frontend input hygiene only. Does not replace server authentication.
abstract final class AuthInputValidation {
  /// Arabic and Persian numeral characters are rejected, not converted.
  static String normalizeDigits(String source) => source;

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  /// Local input is exactly 9 ASCII digits; +967 is fixed in the UI.
  static String? phone(String? raw) {
    final value = normalizePhone(raw ?? '');
    if (value.isEmpty) return 'أدخل رقم الجوال';
    if (!RegExp(r'^[0-9]{9}) {
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
).hasMatch(value)) {
      return 'أدخل رقم جوال يمني فقط (70/71/72/73/77/78) بالأرقام الإنجليزية 0-9';
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
