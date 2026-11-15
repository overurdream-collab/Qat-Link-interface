import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/customer_details_screen.dart';
import 'package:qat_link/screens/customers_screen.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';

void main() {
  late AppState state;
  final today = DateTime.now();
  final client = CustomerModel(
    id: 'c1', name: 'محمد أحمد', phone: '777 123 456',
    primaryCurrency: CurrencyCode.yer,
    createdAt: DateTime(today.year, 1, 2),
    updatedAt: DateTime(today.year, 1, 3),
    profileData: const {'address': 'صنعاء'},
  );

  setUp(() {
    state = AppState();
    state.addCustomer(client);
    state.requestRelationship(
      id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant,
      createdAt: today,
    );
    state.decideRelationship(
      relationshipId: 'r1', actorId: 'c1',
      actorRole: ParticipantRole.customer,
      decision: ApprovalDecision.approved,
      decidedAt: today,
    );
  });

  tearDown(() => state.dispose());

  testWidgets('customer card opens full details instead of old mini sheet',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MerchantCustomersTab(
          state: state, merchantId: 'm1',
          onCustomerTap: (customer, currency) {
            opened = true;
          },
        ),
      ),
    ));
    await tester.ensureVisible(find.byKey(const Key('customer_c1_yer')));
    await tester.tap(find.byKey(const Key('customer_c1_yer')));
    await tester.pump();
    expect(opened, true);
  });

  testWidgets('detail view shows profile, period, currencies and statement',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CustomerDetailsScreen(
          state: state,
          merchantId: 'm1',
          customer: client,
          onBack: () {},
        ),
      ),
    ));
    expect(find.text('بيانات العميل وحركته'), findsOneWidget);
    expect(find.text('محمد أحمد'), findsOneWidget);
    expect(find.text('صنعاء'), findsOneWidget);
    expect(find.text('فترة كشف الحساب'), findsOneWidget);
    expect(find.byKey(const Key('statement_currency_yer')), findsOneWidget);
    expect(find.byKey(const Key('customer_avatar_picker')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('الملخص المالي'), 170,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الرصيد الختامي المعتمد'), findsOneWidget);
    expect(state.movements.value, isEmpty);
  });

  testWidgets('a relationship that loses approval hides all private data',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CustomerDetailsScreen(
          state: state, merchantId: 'wrong-merchant',
          customer: client, onBack: () {},
        ),
      ),
    ));
    expect(find.textContaining('غير متاحة لعدم وجود علاقة'), findsOneWidget);
    expect(find.text('محمد أحمد'), findsNothing);
    expect(find.text('الملخص المالي'), findsNothing);
  });

  testWidgets('detail page back button invokes navigation callback',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: CustomerDetailsScreen(
          state: state, merchantId: 'm1',
          customer: client, onBack: () => pressed = true,
        ),
      ),
    ));
    await tester.tap(find.byKey(const Key('customer_details_back')));
    expect(pressed, true);
  });
}
