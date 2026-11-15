import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/theme/app_theme.dart';
import 'package:qat_link/widgets/merchant_space/booking_intake_policy.dart';
import 'package:qat_link/widgets/merchant_space/night_reminder_campaign.dart';
import 'package:qat_link/widgets/merchant_space/reminder_quick_booking_sheet.dart';

void main() {
  final now=DateTime(2026,11,15);
  final customer=CustomerModel(
    id:'client1',name:'علي صالح',phone:'771234567',
    primaryCurrency:CurrencyCode.yer,
    createdAt:now,updatedAt:now,
  );
  final relation=RelationshipModel(
    id:'rel1',merchantId:'merchant1',customerId:'client1',
    createdBy:'merchant1',createdByRole:ParticipantRole.merchant,
    createdAt:now,
    approvals:[
      ApprovalRecord(actorId:'merchant1',role:ParticipantRole.merchant,
        decision:ApprovalDecision.declared,decidedAt:now),
      ApprovalRecord(actorId:'client1',role:ParticipantRole.customer,
        decision:ApprovalDecision.approved,decidedAt:now),
    ],
  );
  final local=BookingIntakePolicy.sanaaTime(DateTime.now());
  final tomorrow=DateTime(local.year,local.month,local.day+1);
  NightReminderCampaignDraft campaign()=>NightReminderCampaignDraft(
    id:'trusted-reminder',merchantId:'merchant1',
    merchantDisplayName:'متجر الجبل',
    day:tomorrow,audience:NightReminderAudience.yesterdayConfirmed,
    offeredItem:'قات حاشدي',pickupTime:'11:00',
  );
  Future<void> launch(WidgetTester tester,{
    String? clientId='client1',
    Set<String> delivered=const {'client1'},
    bool Function(ReminderQuickBookingRequest)? onConfirm,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme:AppTheme.light,
      home:Scaffold(body:ReminderQuickBookingSheet(
        campaign:campaign(),authenticatedCustomerId:clientId,
        verifiedDeliveredCustomerIds:delivered,
        intakeSettings:const BookingIntakeSettings(enabled:true,allDay:true),
        customers:[customer],relationships:[relation],
        onServerConfirm:onConfirm==null?null:(request) async=>onConfirm(request),
      )),
    ));
  }

  testWidgets('customer changes only quantity, with no duplicate identity fields',
      (tester) async {
    await launch(tester);
    expect(find.text('قات حاشدي'),findsOneWidget);
    expect(find.text('حجز الغد من متجر الجبل'), findsOneWidget);
    expect(find.text('المتجر: متجر الجبل'), findsOneWidget);
    expect(find.byType(TextField),findsNothing);
    expect(find.byKey(const Key('reminder_start_booking')),findsOneWidget);
    expect(find.byKey(const Key('reminder_ignore')),findsOneWidget);
    expect(find.byKey(const Key('reminder_quantity_plus')),findsNothing);
    await tester.tap(find.byKey(const Key('reminder_start_booking')));
    await tester.pump();
    expect(find.text('كم ربطة تريد؟'),findsOneWidget);
    expect(find.text('1'),findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder_quantity_plus')));
    await tester.pump();
    expect(find.text('2'),findsOneWidget);
    await tester.tap(find.byKey(const Key('reminder_quantity_minus')));
    await tester.pump();
    expect(find.text('1'),findsOneWidget);
    final button=tester.widget<FilledButton>(
      find.byKey(const Key('reminder_confirm_booking')));
    expect(button.onPressed,isNull);
  });

  testWidgets('unverified delivery or customer blocks one-tap booking',
      (tester) async {
    await launch(tester, delivered:{},onConfirm:(_)=>true);
    final button=tester.widget<FilledButton>(
      find.byKey(const Key('reminder_start_booking')));
    expect(button.onPressed,isNull);
    expect(find.byKey(const Key('reminder_quantity_plus')),findsNothing);
    expect(find.textContaining('لا يوجد تذكير موثّق'),findsOneWidget);
  });

  testWidgets('authenticated callback gets the fixed campaign product and quantity',
      (tester) async {
    ReminderQuickBookingRequest? received;
    await launch(tester,onConfirm:(request){
      received=request;
      return false; // Server did not confirm: must remain open.
    });
    expect(received,isNull);
    await tester.tap(find.byKey(const Key('reminder_start_booking')));
    await tester.pump();
    expect(received,isNull);
    await tester.tap(find.byKey(const Key('reminder_quantity_plus')));
    await tester.pump();
    expect(received,isNull);
    await tester.tap(find.byKey(const Key('reminder_confirm_booking')));
    await tester.pumpAndSettle();
    expect(received,isNotNull);
    expect(received!.quantity,2);
    expect(received!.merchantId,'merchant1');
    expect(received!.customerId,'client1');
    expect(received!.item,'قات حاشدي');
    expect(received!.pickupTime,'11:00');
    expect(find.textContaining('لم يؤكد الخادم الحجز'),findsOneWidget);
  });
  testWidgets('ignore action is offered before quantity without committing a booking',
      (tester) async {
    var sent = false;
    await launch(tester,onConfirm:(request){
      sent = true;
      return true;
    });
    expect(find.byKey(const Key('reminder_ignore')),findsOneWidget);
    expect(find.byKey(const Key('reminder_confirm_booking')),findsNothing);
    expect(find.byKey(const Key('reminder_quantity_plus')),findsNothing);
    expect(sent,false);
  });


}
