import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/merchant_space/booking_intake_policy.dart';
import 'package:qat_link/widgets/merchant_space/client_store_booking_sheet.dart';

void main() {
  final now = DateTime(2026, 11, 15);
  final client = CustomerModel(
    id: 'c1', name: 'علي عبدالله',
    phone: '771234567', primaryCurrency: CurrencyCode.yer,
    createdAt: now, updatedAt: now,
  );
  final relation = RelationshipModel(
    id: 'r1', merchantId: 'm1', customerId: 'c1',
    createdBy: 'm1', createdByRole: ParticipantRole.merchant,
    createdAt: now,
    approvals: [
      ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: now),
      ApprovalRecord(actorId: 'c1', role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: now),
    ],
  );

  testWidgets('unknown or unlinked customer cannot request a booking',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ClientStoreBookingSheet(
        merchantId: 'm1', customerId: 'unknown',
        intakeSettings: const BookingIntakeSettings(
          enabled: true, allDay: true),
        customers: [client], relationships: [relation],
        onAuthenticatedSubmit: (_) async => true,
      )),
    ));
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('client_booking_submit')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('غير نشط أو غير مسجل'), findsOneWidget);
  });

  testWidgets('approved customer cannot submit when intake gate is closed',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ClientStoreBookingSheet(
        merchantId: 'm1', customerId: 'c1',
        intakeSettings: const BookingIntakeSettings(),
        customers: [client], relationships: [relation],
        onAuthenticatedSubmit: (_) async => true,
      )),
    ));
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('client_booking_submit')));
    expect(button.onPressed, isNull);
    expect(find.textContaining('باب الحجوزات مغلق'), findsOneWidget);
  });

  testWidgets('approved customer still cannot submit without a backend',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ClientStoreBookingSheet(
        merchantId: 'm1', customerId: 'c1',
        intakeSettings: const BookingIntakeSettings(
            enabled: true, allDay: true),
        customers: [client], relationships: [relation],
      )),
    ));
    expect(find.text('احجز طلبك للغد'), findsOneWidget);
    expect(find.textContaining('غير متصل بالخادم'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('client_booking_submit')));
    expect(button.onPressed, isNull);
  });
}
