import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/widgets/customers/merchant_pending_statement_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('off-app statement PDF is real and contains synthetic test activity',
      () async {
    final state = AppState();
    addTearDown(state.dispose);
    final contact = MerchantPendingContact(
      id: 'pdf-contact',
      merchantId: 'pdf-merchant',
      name: 'عميل اختبار اصطناعي',
      phone: '777123456',
      createdAt: DateTime(2026, 11, 1),
    );
    state.addMerchantContact(contact);
    state.addMerchantPendingDebt(MerchantPendingDebt(
      id: 'pdf-debt',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('1250.50'),
      currency: CurrencyCode.yer,
      createdAt: DateTime(2026, 11, 15),
      description: 'حركة اصطناعية للاختبار',
    ));
    state.addMerchantPendingPayment(MerchantPendingPayment(
      id: 'pdf-payment',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('250'),
      currency: CurrencyCode.yer,
      createdAt: DateTime(2026, 11, 16),
    ));
    final statement = state.merchantPendingStatement(
      merchantId: contact.merchantId,
      contactId: contact.id,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 17),
    );

    final bytes = await MerchantPendingStatementPdf.create(statement);
    expect(bytes.length, greaterThan(1500));
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(statement.operationalNetByCurrency[CurrencyCode.yer],
        Decimal.parse('1000.50'));
    expect(state.movements.value, isEmpty,
        reason: 'Creating a unilateral PDF must not create approved ledger data.');
  });
}
