import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/merchant_space/customer_store_rating_sheet.dart';

void main() {
  final date = DateTime(2026, 11, 15);
  final customer = CustomerModel(
    id: 'c1', name: 'علي أحمد',
    phone: '771234567', primaryCurrency: CurrencyCode.yer,
    createdAt: date, updatedAt: date,
  );
  final relation = RelationshipModel(
    id: 'r1', merchantId: 'm1', customerId: 'c1',
    createdBy: 'm1', createdByRole: ParticipantRole.merchant,
    createdAt: date, approvals: [
      ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: date),
      ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: date),
    ],
  );
  final purchase = MovementModel(
    id: 'buy1', merchantId: 'm1', customerId: 'c1',
    relationshipId: 'r1', amount: Decimal.parse('100'),
    currency: CurrencyCode.yer, type: MovementType.debt,
    createdBy: 'm1', createdByRole: ParticipantRole.merchant,
    createdAt: date, approvals: [
      ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: date),
      ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: date),
    ],
  );

  testWidgets('client cannot rate without an approved purchase',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: CustomerStoreRatingSheet(
        merchantId: 'm1', customerId: 'c1',
        customers: [customer], relationships: [relation],
        movements: const [],
      )),
    ));
    expect(find.text('قيّم تجربتك مع المتجر'), findsOneWidget);
    expect(find.textContaining('متاح بعد تعامل موثق'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('rating_submit')));
    expect(button.onPressed, isNull);
  });

  testWidgets('with approved purchase ratings remain gated until backend',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: CustomerStoreRatingSheet(
        merchantId: 'm1', customerId: 'c1',
        customers: [customer], relationships: [relation],
        movements: [purchase],
      )),
    ));
    await tester.tap(find.byKey(const Key('rate_star_5')));
    await tester.pump();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('rating_submit')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('ينتظر ربط حساب العميل'), findsOneWidget);
  });
}
