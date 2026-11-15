import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/merchant_space/booking_intake_policy.dart';
import 'package:qat_link/widgets/merchant_space/night_reminder_campaign.dart';
import 'package:qat_link/widgets/merchant_space/reminder_quick_booking_sheet.dart';

void main() {
  final now = DateTime(2026, 11, 15);
  final customer = CustomerModel(
    id: 'client1', name: 'علي صالح', phone: '771234567',
    primaryCurrency: CurrencyCode.yer,
    createdAt: now, updatedAt: now,
  );
  final relation = RelationshipModel(
    id: 'rel1', merchantId: 'merchant1', customerId: 'client1',
    createdBy: 'merchant1',
    createdByRole: ParticipantRole.merchant,
    createdAt: now,
    approvals: [
      ApprovalRecord(
        actorId: 'merchant1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: now,
      ),
      ApprovalRecord(
        actorId: 'client1', role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: now,
      ),
    ],
  );

  NightReminderCampaignDraft campaign() {
    final local = BookingIntakePolicy.sanaaTime(DateTime.now());
    return NightReminderCampaignDraft(
      id: 'trusted-reminder', merchantId: 'merchant1',
      merchantDisplayName: 'متجر الجبل',
      day: DateTime(local.year, local.month, local.day + 1),
      audience: NightReminderAudience.yesterdayConfirmed,
      offeredItem: 'قات حاشدي', pickupTime: '11:00',
    );
  }

  Future<void> launch(WidgetTester tester, {
    String? clientId = 'client1',
    Set<String> delivered = const {'client1'},
    Future<bool> Function(ReminderQuickBookingRequest)? onConfirm,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: ReminderQuickBookingSheet(
        campaign: campaign(),
        authenticatedCustomerId: clientId,
        verifiedDeliveredCustomerIds: delivered,
        intakeSettings: const BookingIntakeSettings(
          enabled: true, allDay: true,
        ),
        customers: [customer],
        relationships: [relation],
        onServerConfirm: onConfirm,
      )),
    ));
  }

  testWidgets('merchant name, quantity and ONE confirm action show immediately',
      (tester) async {
    await launch(tester);
    expect(find.text('حجز الغد من متجر الجبل'), findsOneWidget);
    expect(find.text('المتجر: متجر الجبل'), findsOneWidget);
    expect(find.text('قات حاشدي'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('كم ربطة تريد؟'), findsOneWidget);
    expect(find.byKey(const Key('reminder_quantity_plus')), findsOneWidget);
    expect(find.byKey(const Key('reminder_quantity_minus')), findsOneWidget);
    expect(find.byKey(const Key('reminder_ignore')), findsOneWidget);
    expect(find.byKey(const Key('reminder_confirm_booking')), findsOneWidget);
    expect(find.byKey(const Key('reminder_start_booking')), findsNothing);
    expect(find.byKey(const Key('reminder_back_to_invitation')), findsNothing);

    await tester.tap(find.byKey(const Key('reminder_quantity_plus')));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder_quantity_minus')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('reminder_confirm_booking')),
    );
    expect(button.onPressed, isNull); // No server connection.
  });

  testWidgets('unverified recipient cannot confirm booking',
      (tester) async {
    await launch(tester, delivered: {}, onConfirm: (_) async => true);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('reminder_confirm_booking')),
    );
    expect(button.onPressed, isNull);
    expect(find.textContaining('لا يوجد تذكير موثّق'), findsOneWidget);
    expect(find.byKey(const Key('reminder_ignore')), findsOneWidget);
  });

  testWidgets('one press sends fixed campaign and chosen quantity, no fake success',
      (tester) async {
    ReminderQuickBookingRequest? received;
    var calls = 0;
    await launch(tester, onConfirm: (request) async {
      received = request;
      calls++;
      return false; // No persisted confirmation.
    });
    await tester.tap(find.byKey(const Key('reminder_quantity_plus')));
    await tester.pump();
    expect(calls, 0);
    await tester.tap(find.byKey(const Key('reminder_confirm_booking')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(received!.quantity, 2);
    expect(received!.merchantId, 'merchant1');
    expect(received!.customerId, 'client1');
    expect(received!.campaignId, 'trusted-reminder');
    expect(received!.item, 'قات حاشدي');
    expect(received!.pickupTime, '11:00');
    expect(find.textContaining('لم يؤكد الخادم الحجز'), findsOneWidget);
    expect(find.byKey(const Key('reminder_confirm_booking')), findsOneWidget);
  });

  testWidgets('one submission stays single while backend request is pending',
      (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await launch(tester, onConfirm: (request) {
      calls++;
      return pending.future;
    });
    await tester.tap(find.byKey(const Key('reminder_confirm_booking')));
    await tester.pump();
    expect(calls, 1);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('reminder_confirm_booking')),
    );
    expect(button.onPressed, isNull);
    final ignoreButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('reminder_ignore')),
    );
    expect(ignoreButton.onPressed, isNull);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('ignore is visible immediately and does not submit',
      (tester) async {
    var calls = 0;
    await launch(tester, onConfirm: (_) async {
      calls++;
      return true;
    });
    expect(find.byKey(const Key('reminder_ignore')), findsOneWidget);
    expect(find.byKey(const Key('reminder_quantity_plus')), findsOneWidget);
    expect(calls, 0);
  });
}
