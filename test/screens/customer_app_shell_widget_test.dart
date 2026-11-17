import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  testWidgets('customer preview exposes the five customer destinations but no private account data',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: CustomerAppShell(
        isDark: false,
        onToggleTheme: () {},
        customerId: 'unverified-id',
        state: state,
      ),
    ));

    expect(find.textContaining('معاينة واجهات العميل'), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_0')), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_1')), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_2')), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_3')), findsOneWidget);
    expect(find.byKey(const Key('customer_nav_4')), findsOneWidget);
    expect(find.text('يتطلب حساباً موثقاً'), findsWidgets);

    await tester.tap(find.byKey(const Key('customer_nav_1')));
    await tester.pumpAndSettle();
    expect(find.text('سجل الحركة'), findsOneWidget);
    expect(find.text('سجل الحساب خاص'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer_nav_3')));
    await tester.pumpAndSettle();
    expect(find.text('التجار وحساباتك'), findsOneWidget);
    expect(find.text('قائمة التجار خاصة'), findsOneWidget);
  });

  testWidgets('customer balances include approved operations per currency only',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    final date = DateTime(2026, 11, 17);
    state.addCustomer(CustomerModel(
      id: 'customer-1',
      name: 'عميل اختباري',
      phone: '777123456',
      primaryCurrency: CurrencyCode.yer,
      createdAt: date,
      updatedAt: date,
    ));
    state.requestRelationship(
      id: 'relation-1',
      merchantId: 'merchant-1',
      customerId: 'customer-1',
      actorId: 'merchant-1',
      actorRole: ParticipantRole.merchant,
      createdAt: date,
    );
    state.decideRelationship(
      relationshipId: 'relation-1',
      actorId: 'customer-1',
      actorRole: ParticipantRole.customer,
      decision: ApprovalDecision.approved,
      decidedAt: date.add(const Duration(minutes: 1)),
    );
    state.requestRelationship(
      id: 'relation-pending',
      merchantId: 'merchant-2',
      customerId: 'customer-1',
      actorId: 'merchant-2',
      actorRole: ParticipantRole.merchant,
      createdAt: date,
    );

    void addMovement({
      required String id,
      String relationshipId = 'relation-1',
      String merchantId = 'merchant-1',
      required String amount,
      required CurrencyCode currency,
      required MovementType type,
      required MovementStatus status,
    }) {
      final approvals = <ApprovalRecord>[
        ApprovalRecord(
          actorId: merchantId,
          role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared,
          decidedAt: date,
        ),
        if (status != MovementStatus.pending)
          ApprovalRecord(
            actorId: 'customer-1',
            role: ParticipantRole.customer,
            decision: status == MovementStatus.approved
                ? ApprovalDecision.approved
                : ApprovalDecision.rejected,
            decidedAt: date.add(const Duration(minutes: 2)),
          ),
      ];
      state.movements.value = [...state.movements.value, MovementModel(
        id: id,
        relationshipId: relationshipId,
        customerId: 'customer-1',
        merchantId: merchantId,
        amount: Decimal.parse(amount),
        currency: currency,
        type: type,
        createdBy: merchantId,
        createdByRole: ParticipantRole.merchant,
        createdAt: date,
        approvals: approvals,
      )];
    }

    addMovement(id: 'yer-debt', amount: '1000', currency: CurrencyCode.yer,
        type: MovementType.debt, status: MovementStatus.approved);
    addMovement(id: 'yer-payment', amount: '300', currency: CurrencyCode.yer,
        type: MovementType.payment, status: MovementStatus.approved);
    addMovement(id: 'sar-debt', amount: '200', currency: CurrencyCode.sar,
        type: MovementType.debt, status: MovementStatus.approved);
    addMovement(id: 'sar-payment', amount: '50', currency: CurrencyCode.sar,
        type: MovementType.payment, status: MovementStatus.approved);
    addMovement(id: 'usd-debt', amount: '5', currency: CurrencyCode.usd,
        type: MovementType.debt, status: MovementStatus.approved);
    addMovement(id: 'yer-pending', amount: '90', currency: CurrencyCode.yer,
        type: MovementType.debt, status: MovementStatus.pending);
    addMovement(id: 'unlinked-pending', relationshipId: 'relation-pending',
        merchantId: 'merchant-2',
        amount: '40', currency: CurrencyCode.yer, type: MovementType.debt,
        status: MovementStatus.pending);
    addMovement(id: 'yer-rejected', amount: '700', currency: CurrencyCode.yer,
        type: MovementType.debt, status: MovementStatus.rejected);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: CustomerAppShell(
        isDark: false,
        onToggleTheme: () {},
        customerId: 'customer-1',
        verifiedSession: true,
        state: state,
        merchantNames: const {'merchant-1': 'تاجر اختباري'},
      ),
    ));

    expect(find.textContaining('700 ﷼'), findsOneWidget);
    expect(find.textContaining('150 ر.س'), findsOneWidget);
    expect(find.textContaining('5 \$'), findsOneWidget);
    expect(find.textContaining('130'), findsOneWidget,
        reason: 'Pending claims should remain visible before relationship approval.');
    expect(find.textContaining('700 ﷼'), findsOneWidget,
        reason: 'The rejected 700 YER debt must not change the 700 YER balance.');
  });

  testWidgets('discover keeps store opening and booking availability independent',
      (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CustomerDiscoverScreen(state: state, customerId: null, onOpenStore: (_) {}, stores: [
          CustomerPublicStore(
            merchantId: 'closed-booking',
            name: 'متجر مغلق يستقبل حجزاً',
            governorate: 'أمانة العاصمة',
            market: 'السوق الأول',
            isOpen: false,
            acceptsBookings: true,
          ),
          CustomerPublicStore(
            merchantId: 'open-no-booking',
            name: 'متجر مفتوح',
            governorate: 'أمانة العاصمة',
            market: 'السوق الأول',
            isOpen: true,
            acceptsBookings: false,
          ),
        ]),
      ),
    ));

    await tester.tap(find.widgetWithText(ChoiceChip, 'يستقبل حجوزات'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public_store_closed-booking')), findsOneWidget);
    expect(find.byKey(const Key('public_store_open-no-booking')), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'مفتوح'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('public_store_closed-booking')), findsNothing);
  });
}
