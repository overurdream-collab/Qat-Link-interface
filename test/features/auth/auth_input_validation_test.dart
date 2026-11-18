import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/features/auth/auth_input_validation.dart';
import 'package:qat_link/features/auth/registration_role.dart';

void main() {
  test('the three registration categories are exactly the approved choices', () {
    expect(RegistrationRole.values, [
      RegistrationRole.customer,
      RegistrationRole.merchant,
      RegistrationRole.supplier,
    ]);
    expect(RegistrationRole.customer.title, 'عميل');
    expect(RegistrationRole.merchant.title, 'تاجر');
    expect(RegistrationRole.supplier.title, 'مورد');
  });

  test('Yemeni phone and international phone formats are accepted', () {
    expect(AuthInputValidation.phone('771234567'), isNull);
    expect(AuthInputValidation.phone('+967 771 234 567'), isNull);
    expect(AuthInputValidation.phone('٧٧١٢٣٤٥٦٧'), isNotNull);
    expect(AuthInputValidation.phone('+۹۶۷۷۷۱۲۳۴۵۶۷'), isNotNull);
    expect(AuthInputValidation.phone('12'), isNotNull);
    expect(AuthInputValidation.phone('abc123456789'), isNotNull);
  });

  test('four digit PIN and confirmation are validated without saving', () {
    expect(AuthInputValidation.pin('1234'), isNull);
    expect(AuthInputValidation.pin('١٢٣٤'), isNotNull);
    expect(AuthInputValidation.pin('123'), isNotNull);
    expect(AuthInputValidation.pin('12345'), isNotNull);
    expect(AuthInputValidation.pin('abcd'), isNotNull);
    expect(AuthInputValidation.confirmPin('1234', '1234'), isNull);
    expect(AuthInputValidation.confirmPin('4321', '1234'), isNotNull);
    expect(AuthInputValidation.confirmPin('١٢٣٤', '1234'), isNotNull);
  });

  test('full name requires at least two parts', () {
    expect(AuthInputValidation.fullName('أحمد محمد'), isNull);
    expect(AuthInputValidation.fullName('أحمد'), isNotNull);
    expect(AuthInputValidation.fullName(' '), isNotNull);
  });
}
