import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/screens/merchant_financial_assistant_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('assistant includes off-app debt and payments per currency',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    final now = DateTime.now();
    final contact = MerchantPendingContact(
      id: 'outside-customer',
      merchantId: 'merchant-1',
      name: 'عميل خارج التطبيق',
      phone: '777123456',
      createdAt: now,
    );
    state.addMerchantContact(contact);
    state.addMerchantPendingDebt(MerchantPendingDebt(
      id: 'outside-debt',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('1000'),
      currency: CurrencyCode.yer,
      createdAt: now,
    ));
    state.addMerchantPendingPayment(MerchantPendingPayment(
      id: 'outside-payment',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('250'),
      currency: CurrencyCode.yer,
      createdAt: now,
    ));
    state.addMerchantPendingDebt(MerchantPendingDebt(
      id: 'outside-usd-debt',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('5'),
      currency: CurrencyCode.usd,
      createdAt: now,
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: MerchantFinancialAssistantScreen(state: state),
    ));

    await tester.tap(find.byKey(const Key('assistant_currency_usd')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('معلقة — بانتظار الانضمام'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الديون المسجلة'), findsOneWidget);
    expect(find.text('معلقة — بانتظار الانضمام'), findsOneWidget);
    expect(find.textContaining(r'5 $'), findsWidgets);
    expect(find.textContaining('1,000'), findsNothing,
        reason: 'Changing currency must not aggregate YER into USD.');
    expect(find.textContaining('250'), findsNothing,
        reason: 'The YER payment must remain isolated from USD.');
  });
}
