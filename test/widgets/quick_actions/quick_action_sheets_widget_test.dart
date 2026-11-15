import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/app_state.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/quick_actions/quick_actions_sheet.dart';

void main() {
  late AppState state;
  final now = DateTime(2026, 11, 15);

  setUp(() {
    state = AppState();
    state.addCustomer(CustomerModel(
      id: 'c1', name: 'محمد أحمد',
      phone: '777 123 456', primaryCurrency: CurrencyCode.yer,
      createdAt: now, updatedAt: now,
    ));
    state.addCustomer(CustomerModel(
      id: 'c2', name: 'عميل معلق',
      phone: '733 111 222', primaryCurrency: CurrencyCode.sar,
      createdAt: now, updatedAt: now,
    ));
    state.requestRelationship(
      id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant,
      createdAt: now,
    );
    state.decideRelationship(
      relationshipId: 'r1', actorId: 'c1',
      actorRole: ParticipantRole.customer,
      decision: ApprovalDecision.approved,
      decidedAt: now.add(const Duration(minutes: 1)),
    );
    state.requestRelationship(
      id: 'r2', merchantId: 'm1', customerId: 'c2',
      actorId: 'm1', actorRole: ParticipantRole.merchant,
      createdAt: now,
    );
  });
  tearDown(() => state.dispose());

  Future<void> pumpSheet(
    WidgetTester tester,
    MovementType type, {
    String? merchantId = 'm1',
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => MovementEntrySheet(
                state: state, type: type, merchantId: merchantId,
              ),
            ),
            child: const Text('فتح النموذج'),
          ),
        ),
      )),
    ));
    await tester.tap(find.text('فتح النموذج'));
    await tester.pumpAndSettle();
  }

  testWidgets('the quick action menu has exactly three configured options',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(
        builder: (context) => FilledButton(
          child: const Text('فتح الإضافة'),
          onPressed: () => showModalBottomSheet<QuickActionKind>(
            context: context, builder: (_) => const QuickActionsSheet(),
          ),
        ),
      )),
    ));
    await tester.tap(find.text('فتح الإضافة'));
    await tester.pumpAndSettle();
    expect(find.text('الإضافة السريعة'), findsOneWidget);
    expect(find.text('إضافة عميل'), findsOneWidget);
    expect(find.text('إضافة دين'), findsOneWidget);
    expect(find.text('إضافة مبلغ'), findsOneWidget);
  });

  testWidgets('new debt requires selecting approved customer from the list',
      (tester) async {
    await pumpSheet(tester, MovementType.debt);
    expect(find.text('تسجيل دين جديد (آجل)'), findsOneWidget);
    expect(find.byKey(const Key('movement_select_customer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('movement_select_customer')));
    await tester.pumpAndSettle();
    expect(find.text('محمد أحمد'), findsOneWidget);
    expect(find.text('عميل معلق'), findsNothing);
    await tester.tap(find.byKey(const Key('picker_customer_c1')));
    await tester.pumpAndSettle();
    expect(find.text('محمد أحمد'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('movement_amount')), '1500');
    await tester.ensureVisible(find.byKey(const Key('movement_save')));
    await tester.tap(find.byKey(const Key('movement_save')));
    await tester.pump();
    expect(state.movements.value, isEmpty);
    expect(find.textContaining('لم تُحفظ العملية'), findsWidgets);
  });

  testWidgets('payment uses the same approved-customer picker and workflow',
      (tester) async {
    await pumpSheet(tester, MovementType.payment);
    expect(find.text('إضافة مبلغ (تسديد)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('movement_select_customer')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customer_picker_search')), '777123456');
    await tester.pump();
    expect(find.text('محمد أحمد'), findsOneWidget);
    expect(find.text('عميل معلق'), findsNothing);
    await tester.tap(find.byKey(const Key('picker_customer_c1')));
    await tester.pumpAndSettle();
    expect(find.text('محمد أحمد'), findsOneWidget);
    expect(state.movements.value, isEmpty);
  });

  testWidgets('without merchant identity, no customers are exposed',
      (tester) async {
    await pumpSheet(tester, MovementType.debt, merchantId: null);
    await tester.tap(find.byKey(const Key('movement_select_customer')));
    await tester.pumpAndSettle();
    expect(find.textContaining('لا يوجد عملاء مرتبطون'), findsOneWidget);
    expect(find.text('محمد أحمد'), findsNothing);
  });
  testWidgets('ambiguous comma decimal input is rejected rather than reinterpreted',
      (tester) async {
    await pumpSheet(tester, MovementType.payment);
    await tester.tap(find.byKey(const Key('movement_select_customer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker_customer_c1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('movement_amount')), '1,5');
    await tester.ensureVisible(find.byKey(const Key('movement_save')));
    await tester.tap(find.byKey(const Key('movement_save')));
    await tester.pump();
    expect(find.textContaining('بمنزلتين عشريتين'), findsOneWidget);
    expect(state.movements.value, isEmpty);
  });


}
