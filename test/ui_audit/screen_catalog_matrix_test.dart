import 'scroll_audit.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/screens/customer_details_screen.dart';
import 'package:qat_link/screens/customer_app_shell.dart';
import 'package:qat_link/screens/registration_screen.dart';
import 'package:qat_link/screens/merchant_approval_center_screen.dart';
import 'package:qat_link/screens/merchant_financial_assistant_screen.dart';
import 'package:qat_link/screens/merchant_pending_contact_details_screen.dart';
import 'package:qat_link/screens/merchant_bookings_screen.dart';
import 'package:qat_link/screens/fin08_customer_claims_screen.dart';
import 'package:qat_link/screens/fin08_customer_relationships_screen.dart';
import 'package:qat_link/screens/fin08_merchant_book_screen.dart';
import 'package:qat_link/screens/fin13_relationship_ledger_screen.dart';
import 'package:qat_link/screens/fin15_amendments_screen.dart';
import 'package:qat_link/screens/fin16_credit_limits_screen.dart';
// Reuse isolated test doubles, never application/runtime demo data.
import '../screens/fin08_customer_claims_screen_test.dart'
    show FakeFin08Gateway;
import '../screens/fin08_customer_relationships_screen_test.dart'
    show RelationshipGatewayFake;
import '../screens/fin08_merchant_book_screen_test.dart'
    show MerchantGatewayFake;
import '../screens/fin13_relationship_ledger_screen_test.dart' show FakeLedger;
import '../screens/fin15_amendments_screen_test.dart' show FakeAmendmentGateway;
import '../screens/fin16_credit_limits_screen_test.dart' show FakeCreditGateway;

void main() {
  setUpAll(() async {
    await (FontLoader('Cairo')
          ..addFont(rootBundle.load('assets/fonts/Cairo-Variable.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  const names = [
    'registration',
    'details',
    'pending_contact',
    'assistant',
    'approvals',
    'bookings',
    'claims',
    'relationships',
    'merchant_book',
    'ledger',
    'amendments',
    'credit',
    'public_store'
  ];
  for (final pink in [false, true]) {
    for (final dark in [false, true]) {
      for (final width in <double>[320, 360, 390, 430, 600, 800]) {
        for (final scale in <double>[1, if (width == 320) 1.6]) {
          for (final name in names) {
            final id =
                '${name}_${pink ? 'pink' : 'blue'}_${dark ? 'night' : 'day'}_${width.toInt()}_$scale';
            testWidgets(
                'screen catalog $id',
                (tester) => withClock(Clock.fixed(DateTime(2026, 11, 22, 10)),
                        () async {
                      tester.view.devicePixelRatio = 1;
                      tester.view.physicalSize =
                          Size(width, scale > 1 ? 640 : 900);
                      addTearDown(tester.view.resetDevicePixelRatio);
                      addTearDown(tester.view.resetPhysicalSize);
                      final state = AppState();
                      addTearDown(state.dispose);
                      final customer = CustomerModel(
                          id: 'audit-c',
                          name:
                              'عميل اختباري ذو اسم عربي طويل للتحقق من عرض التفاصيل',
                          phone: '771234567',
                          primaryCurrency: CurrencyCode.yer,
                          createdAt: DateTime(2026, 11, 1),
                          updatedAt: DateTime(2026, 11, 1));
                      final contact = MerchantPendingContact(
                          id: 'audit-contact',
                          merchantId: 'audit-m',
                          name: customer.name,
                          phone: customer.phone,
                          createdAt: DateTime(2026, 11, 1));
                      state.addCustomer(customer);
                      state.addMerchantContact(contact);
                      final Widget screen = switch (name) {
                        'registration' => RegistrationScreen(
                            isDark: dark,
                            onToggleTheme: () {},
                            onGenderChanged: (_) {}),
                        'details' => CustomerDetailsScreen(
                            customer: customer, state: state, onBack: () {}),
                        'pending_contact' =>
                          MerchantPendingContactDetailsScreen(
                              state: state,
                              contact: contact,
                              merchantId: 'audit-m'),
                        'assistant' =>
                          MerchantFinancialAssistantScreen(state: state),
                        'approvals' =>
                          MerchantApprovalCenterScreen(state: state),
                        'bookings' => MerchantBookingsScreen(
                            bookings: const [],
                            day: DateTime(2026, 11, 22),
                            onDayChanged: (_) {},
                            onAddBooking: () {},
                            onUpdateBooking: (_, __) {},
                            onBack: () {},
                            state: state,
                            storeName: 'متجر اختباري ذو اسم طويل'),
                        'claims' => Fin08CustomerClaimsScreen(
                            gateway: FakeFin08Gateway()),
                        'relationships' => Fin08CustomerRelationshipsScreen(
                            gateway: RelationshipGatewayFake()),
                        'merchant_book' => Fin08MerchantBookScreen(
                            gateway: MerchantGatewayFake()),
                        'ledger' => Fin13RelationshipLedgerScreen(
                            gateway: FakeLedger(),
                            relationshipId: 'audit-r',
                            actorId: 'audit-c',
                            role: ParticipantRole.customer),
                        'amendments' => Fin15AmendmentsScreen(
                            gateway: FakeAmendmentGateway(), forMerchant: true),
                        'credit' => Fin16CreditLimitsScreen(
                            gateway: FakeCreditGateway(),
                            relationshipId: 'audit-r',
                            merchantCanEdit: true),
                        _ => CustomerPublicStoreDetailsScreen(
                            store: const CustomerPublicStore(
                                merchantId: 'audit-m',
                                name: 'متجر اختباري ذو اسم عربي طويل جداً',
                                governorate: 'أمانة العاصمة',
                                market: 'سوق اختباري',
                                isOpen: true,
                                acceptsBookings: false),
                            state: state,
                            customerId: null),
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
                        builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(textScaler: TextScaler.linear(scale)),
                            child: child!),
                        home: RepaintBoundary(
                            key: const Key('catalog_capture'),
                            child: Scaffold(body: screen)),
                      ));
                      await tester.pumpAndSettle();
                      expect(tester.takeException(), isNull, reason: id);
                      if (scale == 1) {
                        await expectLater(
                            find.byKey(const Key('catalog_capture')),
                            matchesGoldenFile('goldens/catalog/$id.png'));
                      }
                      await auditVerticalContent(tester);
                      if (scale == 1 && width == 390) {
                        await expectLater(
                            find.byKey(const Key('catalog_capture')),
                            matchesGoldenFile('goldens/scroll_end/$id.png'));
                      }
                      await tester.pumpWidget(const SizedBox.shrink());
                      await tester.pump();
                    }));
          }
        }
      }
    }
  }
}
