import 'package:clock/clock.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/screens/customer_details_screen.dart';
import 'package:qat_link/screens/merchant_approval_center_screen.dart';
import 'package:qat_link/screens/merchant_pending_contact_details_screen.dart';
import 'scroll_audit.dart';

// Test-only records enter through the real declaration and approval methods.
// No runtime preview fixture or authenticated production session is added.
(AppState, CustomerModel, MerchantPendingContact) fixture() {
  final state = AppState(), date = DateTime(2026, 11, 20);
  final customer = CustomerModel(
      id: 'audit-c',
      name: 'عميل اختباري ذو اسم عربي طويل للتحقق من التفاصيل المالية',
      phone: '771234567',
      primaryCurrency: CurrencyCode.yer,
      createdAt: date,
      updatedAt: date,
      profileData: const {
        'address': 'عنوان اختباري طويل في السوق للتحقق من التفاف النص'
      });
  final contact = MerchantPendingContact(
      id: 'audit-contact',
      merchantId: 'audit-m',
      name: customer.name,
      phone: customer.phone,
      createdAt: date);
  state.addCustomer(customer);
  state.addMerchantContact(contact);
  state.requestRelationship(
      id: 'audit-r',
      merchantId: 'audit-m',
      customerId: 'audit-c',
      actorId: 'audit-m',
      actorRole: ParticipantRole.merchant,
      createdAt: date);
  state.decideRelationship(
      relationshipId: 'audit-r',
      actorId: 'audit-c',
      actorRole: ParticipantRole.customer,
      decision: ApprovalDecision.approved,
      decidedAt: date);
  for (final currency in CurrencyCode.values) {
    for (final kind in ['debt', 'payment', 'pending', 'incoming']) {
      final byCustomer = kind == 'incoming';
      final id = '${currency.name}-$kind';
      state.addMovement(MovementModel(
          id: id,
          relationshipId: 'audit-r',
          merchantId: 'audit-m',
          customerId: 'audit-c',
          amount: Decimal.parse(kind == 'payment'
              ? '234567.8901'
              : kind == 'debt'
                  ? '1234567.8901'
                  : '999999.9999'),
          currency: currency,
          type: kind == 'payment' ? MovementType.payment : MovementType.debt,
          createdBy: byCustomer ? 'audit-c' : 'audit-m',
          createdByRole:
              byCustomer ? ParticipantRole.customer : ParticipantRole.merchant,
          createdAt: date,
          description:
              'وصف اختباري طويل للعملية المالية مع الحفاظ على فصل العملة ودقة المبلغ',
          approvals: [
            ApprovalRecord(
                actorId: byCustomer ? 'audit-c' : 'audit-m',
                role: byCustomer
                    ? ParticipantRole.customer
                    : ParticipantRole.merchant,
                decision: ApprovalDecision.declared,
                decidedAt: date)
          ]));
      if (kind == 'payment' || kind == 'debt') {
        state.decideMovement(
            movementId: id,
            actorId: 'audit-c',
            actorRole: ParticipantRole.customer,
            decision: ApprovalDecision.approved,
            decidedAt: date);
      }
    }
    state.addMerchantPendingDebt(MerchantPendingDebt(
        id: 'private-${currency.name}',
        merchantId: 'audit-m',
        contactId: contact.id,
        amount: Decimal.parse('1234567.8901'),
        currency: currency,
        createdAt: date,
        description: 'مطالبة محلية معلقة وليست ضمن الرصيد المعتمد'));
  }
  return (state, customer, contact);
}

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in <double>[320, 360, 390, 430, 600, 800]) {
        for (final scale in <double>[1, if (width == 320) 1.6]) {
          for (final name in [
            'details_approved',
            'linked_account',
            'customer_assistant',
            'pending_contact_filled',
            'customer_movements_filled',
            'customer_merchants_filled',
            'approvals_filled'
          ]) {
            final id =
                '${name}_${pink ? 'pink' : 'blue'}_${dark ? 'night' : 'day'}_${width.toInt()}_$scale';
            testWidgets(
                'populated financial $id',
                (tester) => withClock(Clock.fixed(DateTime(2026, 11, 22, 10)),
                        () async {
                      tester.view.physicalSize =
                          Size(width, scale > 1 ? 640 : 900);
                      tester.view.devicePixelRatio = 1;
                      addTearDown(tester.view.resetPhysicalSize);
                      addTearDown(tester.view.resetDevicePixelRatio);
                      final (state, customer, contact) = fixture();
                      addTearDown(state.dispose);
                      final Widget screen = switch (name) {
                        'details_approved' => CustomerDetailsScreen(
                            customer: customer,
                            state: state,
                            merchantId: 'audit-m',
                            onBack: () {}),
                        'linked_account' => CustomerMerchantAccountScreen(
                            state: state,
                            customerId: 'audit-c',
                            merchantId: 'audit-m',
                            merchantName: 'متجر اختباري ذو اسم طويل'),
                        'customer_assistant' => CustomerAppShell(
                            isDark: dark,
                            onToggleTheme: () {},
                            customerId: 'audit-c',
                            verifiedSession: true,
                            state: state,
                            customerName: customer.name,
                            merchantNames: const {'audit-m': 'متجر اختباري'}),
                        'pending_contact_filled' =>
                          MerchantPendingContactDetailsScreen(
                              state: state,
                              contact: contact,
                              merchantId: 'audit-m'),
                        'customer_movements_filled' => CustomerMovementsScreen(
                            state: state,
                            customerId: 'audit-c',
                            merchantNames: const {
                              'audit-m': 'متجر اختباري ذو اسم طويل'
                            },
                            onReviewClaims: () {},
                            onOpenLedger: (_) {}),
                        'customer_merchants_filled' => CustomerMerchantsScreen(
                            state: state,
                            customerId: 'audit-c',
                            merchantNames: const {
                              'audit-m': 'متجر اختباري ذو اسم طويل'
                            },
                            onReviewClaims: () {},
                            onReviewRelationships: () {},
                            onOpenMerchant: (_) {}),
                        _ => MerchantApprovalCenterScreen(state: state),
                      };
                      final handler = FlutterError.onError!;
                      FlutterError.onError = (details) {
                        debugPrint(details.toString());
                        handler(details);
                      };
                      addTearDown(() => FlutterError.onError = handler);
                      await tester.pumpWidget(MaterialApp(
                          theme: AppTheme.build(dark: dark, pink: pink),
                          locale: const Locale('ar'),
                          supportedLocales: const [Locale('ar')],
                          localizationsDelegates:
                              GlobalMaterialLocalizations.delegates,
                          builder: (context, child) => RepaintBoundary(
                              key: const Key('populated_capture'),
                              child: MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                      textScaler: TextScaler.linear(scale)),
                                  child: child!)),
                          home: Scaffold(body: screen)));
                      await tester.pumpAndSettle();
                      if (name == 'customer_assistant') {
                        await tester.scrollUntilVisible(
                            find.byKey(const Key('customer_home_assistant')),
                            250,
                            scrollable: find
                                .byWidgetPredicate((w) =>
                                    w is Scrollable &&
                                    w.axisDirection == AxisDirection.down)
                                .hitTestable()
                                .first);
                        await tester.tap(
                            find.byKey(const Key('customer_home_assistant')));
                        await tester.pumpAndSettle();
                      }
                      expect(tester.takeException(), isNull, reason: id);
                      if (scale == 1)
                        await expectLater(
                            find.byKey(const Key('populated_capture')),
                            matchesGoldenFile('goldens/populated/$id.png'));
                      await auditVerticalContent(tester);
                      if (scale == 1 && width == 390)
                        await expectLater(
                            find.byKey(const Key('populated_capture')),
                            matchesGoldenFile('goldens/scroll_end/$id.png'));
                      await tester.pumpWidget(const SizedBox.shrink());
                      await tester.pump();
                    }));
          }
        }
      }
    }
  }
}
