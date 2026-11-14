import 'package:decimal/decimal.dart';

import '../models/app_models.dart';

/// Presentation-only currency helpers. Never combines amounts across currencies.
abstract final class FinanceDisplay {
  static String currencyName(CurrencyCode code) => switch (code) {
    CurrencyCode.yer => 'الريال اليمني',
    CurrencyCode.sar => 'الريال السعودي',
    CurrencyCode.usd => 'الدولار الأمريكي',
  };

  static String currencyCode(CurrencyCode code) => code.name.toUpperCase();

  static String currencySymbol(CurrencyCode code) => switch (code) {
    CurrencyCode.yer => '﷼',
    CurrencyCode.sar => 'ر.س',
    CurrencyCode.usd => r'$',
  };

  static String amount(Decimal value) {
    final raw = value.toString();
    final negative = raw.startsWith('-');
    final text = negative ? raw.substring(1) : raw;
    final parts = text.split('.');
    final whole = parts.first;
    final output = StringBuffer();
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        output.write(',');
      }
      output.write(whole[index]);
    }
    var fractional = parts.length > 1 ? parts.last : '';
    fractional = fractional.replaceFirst(RegExp(r'0+$'), '');
    return '${negative ? '-' : ''}${output.toString()}${fractional.isEmpty ? '' : '.$fractional'}';
  }
}
