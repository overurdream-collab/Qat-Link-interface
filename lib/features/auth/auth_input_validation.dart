/// Frontend input hygiene only. Does not replace server authentication.
abstract final class AuthInputValidation {
  // Keep ASCII input unchanged; Arabic/Persian digits are not accepted.
  static String normalizeDigits(String source) => source;

  static String normalizePhone(String value) => value
      .replaceAll(RegExp(r'[\s\-\(\)]'), '');

  static String? phone(String? raw) {
    final phone = normalizePhone(raw ?? '');
    if (phone.isEmpty) return 'أدخل رقم الجوال';
    if (!RegExp(r'^(?:\+967|967)?7(?:0|1|3|7|8)[0-9]{7}
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
).hasMatch(phone)) {
      return 'أدخل رقم جوال يمني فقط (70/71/73/77/78) بالأرقام الإنجليزية 0-9';
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
