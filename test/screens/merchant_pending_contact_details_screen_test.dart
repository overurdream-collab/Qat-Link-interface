import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/screens/merchant_pending_contact_details_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('off-app payment lowers operational net but not approved ledger',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    final date = DateTime(2026, 11, 17);
    final contact = MerchantPendingContact(
      id: 'contact-1',
      merchantId: 'merchant-1',
      name: 'عميل اختباري',
      phone: '777123456',
      createdAt: DateTime(2026, 11, 1),
    );
    state.addMerchantContact(contact);
    state.addMerchantPendingDebt(MerchantPendingDebt(
      id: 'debt-1',
      merchantId: contact.merchantId,
      contactId: contact.id,
      amount: Decimal.parse('1000'),
      currency: CurrencyCode.yer,
      createdAt: date,
    ));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MerchantPendingContactDetailsScreen(
          state: state,
          contact: contact,
          merchantId: contact.merchantId,
        ),
      ),
    ));
    await tester.scrollUntilVisible(
      find.byKey(const Key('off_app_export_pdf')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('off_app_export_pdf')), findsOneWidget);
    expect(find.byKey(const Key('off_app_share_pdf')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('off_app_add_payment')));
    await tester.tap(find.byKey(const Key('off_app_add_payment')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('off_app_entry_amount')), '250');
    await tester.tap(find.byKey(const Key('off_app_entry_save')));
    await tester.pumpAndSettle();

    expect(state.merchantPendingPayments.value, hasLength(1));
    final statement = state.merchantPendingStatement(
      merchantId: contact.merchantId,
      contactId: contact.id,
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 17),
    );
    expect(statement.operationalNetByCurrency[CurrencyCode.yer],
        Decimal.parse('750'));
    expect(state.movements.value, isEmpty);
    expect(find.textContaining('لم تغيّر الرصيد المشترك المعتمد'),
        findsOneWidget);
  });
}
