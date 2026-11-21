import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/screens/customers_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  late AppState state;
  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  Future<void> pumpCustomers(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(body: MerchantCustomersTab(
        state: state, merchantId: 'm1')),
    ),
  );

  testWidgets('customers page has required CTA, search, metrics and filters',
      (tester) async {
    await pumpCustomers(tester);
    expect(find.text('إضافة عميل جديد'), findsOneWidget);
    expect(find.byKey(const Key('customers_search')), findsOneWidget);
    expect(find.text('إجمالي العملاء'), findsOneWidget);
    expect(find.text('عملاء بمديونية'), findsOneWidget);
    expect(find.text('عمليات عالقة'), findsOneWidget);
    expect(find.text('لا يوجد عملاء مطابقون للبحث أو الفلتر'), findsOneWidget);
    expect(find.byKey(const Key('customers_sort')), findsOneWidget);
    expect(find.byKey(const Key('customers_currency_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('customers_status_dropdown')), findsOneWidget);
    expect(find.byKey(const Key('customers_compact_filters')), findsOneWidget);
  });

  testWidgets('compact currency and status dropdowns preserve their selections',
      (tester) async {
    await pumpCustomers(tester);
    await tester.ensureVisible(find.byKey(const Key('customers_currency_dropdown')));
    await tester.tap(find.byKey(const Key('customers_currency_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('دولار أمريكي').last);
    await tester.pumpAndSettle();
    expect(find.text('دولار أمريكي'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customers_status_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المعلق').last);
    await tester.pumpAndSettle();
    expect(find.text('المعلق'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing,
        reason: 'Merchant customer filters are dropdowns, not cramped chips.');
  });

  testWidgets('a customer without approved relationship stays off the list',
      (tester) async {
    final now = DateTime(2026, 11, 15);
    state.addCustomer(CustomerModel(
      id: 'c1', name: 'أحمد علي', phone: '777111222',
      primaryCurrency: CurrencyCode.yer,
      createdAt: now, updatedAt: now,
    ));
    await pumpCustomers(tester);
    expect(find.text('أحمد علي'), findsNothing);

    state.requestRelationship(
      id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant,
      createdAt: now);
    await tester.pump();
    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('طلبات ارتباط معلقة'), findsOneWidget);

    state.decideRelationship(
      relationshipId: 'r1', actorId: 'c1',
      actorRole: ParticipantRole.customer,
      decision: ApprovalDecision.approved,
      decidedAt: now.add(const Duration(minutes: 1)),
    );
    await tester.pump();
    expect(find.text('طلبات ارتباط معلقة'), findsNothing);
    expect(find.byKey(const Key('customer_c1_yer')), findsOneWidget);
  });

  testWidgets('merchant can add an unregistered contact without approved relationship',
      (tester) async {
    await pumpCustomers(tester);
    await tester.tap(find.byKey(const Key('customers_add')));
    await tester.pumpAndSettle();
    expect(find.text('إضافة عميل إلى سجلي'), findsOneWidget);
    expect(find.text('إضافة العميل إلى سجلي'), findsOneWidget);
    expect(find.textContaining('بعد إضافة العميل'), findsOneWidget);
    expect(find.text('المديونية الأولية'), findsNothing);
    await tester.enterText(find.byKey(const Key('new_customer_name')), 'صالح أحمد');
    await tester.enterText(find.byKey(const Key('new_customer_phone')), '770123456');
    await tester.ensureVisible(find.byKey(const Key('request_customer_link')));
    await tester.tap(find.byKey(const Key('request_customer_link')));
    await tester.pump();
    expect(state.customers.value, isEmpty);
    expect(state.relationships.value, isEmpty);
    expect(state.movements.value, isEmpty);
    expect(state.merchantContacts.value, hasLength(1));
    expect(state.merchantContacts.value.single.name, 'صالح أحمد');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_download_qr_Android')), findsOneWidget);
    expect(find.byKey(const Key('customer_download_qr_iPhone')), findsOneWidget);
    expect(find.text('إرسال عبر واتساب'), findsOneWidget);
    expect(find.textContaining('لا تعني موافقته'), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer_invite_close')));
    await tester.pumpAndSettle();
    expect(find.text('عملاء غير منضمين إلى التطبيق'), findsOneWidget);
    expect(find.byKey(
      Key('merchant_pending_contact_${state.merchantContacts.value.single.id}')),
      findsOneWidget);
    expect(find.text('بانتظار الانضمام'), findsOneWidget);
  });

  testWidgets('a privately recorded pending debt stays separate from approved balances',
      (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final date = DateTime.now();
    state.addMerchantContact(MerchantPendingContact(
      id: 'p1', merchantId: 'm1', name: 'عميل لا يستخدم التطبيق',
      phone: '777123456', createdAt: date));
    state.addMerchantPendingDebt(MerchantPendingDebt(
      id: 'd1', merchantId: 'm1', contactId: 'p1',
      amount: Decimal.parse('40000'), currency: CurrencyCode.yer,
      createdAt: date));
    await pumpCustomers(tester);
    expect(find.text('عميل لا يستخدم التطبيق'), findsOneWidget);
    expect(find.text('ديون مسجلة: 1 • دفعات مسجلة: 0'), findsOneWidget);
    expect(find.byKey(const Key('pending_copy_statement_p1')),
      findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('customers_metric_total')),
      matching: find.text('1'),
    ), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('customers_metric_debtors')),
      matching: find.text('1'),
    ), findsOneWidget);
    expect(find.descendant(
      of: find.byKey(const Key('customers_metric_pending')),
      matching: find.text('1'),
    ), findsOneWidget);
    expect(state.movements.value, isEmpty);
    expect(find.text('عملاء بمديونية'), findsOneWidget);
    expect(find.byKey(const Key('customer_p1_yer')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('pending_open_profile_p1')));
    await tester.tap(find.byKey(const Key('pending_open_profile_p1')));
    await tester.pumpAndSettle();
    expect(find.text('ملف عميل خارج التطبيق'), findsOneWidget);
    expect(find.textContaining('لا تدخل الرصيد المشترك المعتمد'), findsOneWidget);
  });
}
