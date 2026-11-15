import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/booking_intake_policy.dart';
import 'package:qat_link/widgets/merchant_space/merchant_space_models.dart';
import 'package:qat_link/widgets/merchant_space/night_reminder_campaign.dart';

final now = DateTime.utc(2026, 11, 15, 17); // 20:00 Sanaa
final yesterday = DateTime.utc(2026, 11, 14);
final sevenDaysAgo = DateTime.utc(2026, 11, 8);
final tomorrow = DateTime.utc(2026, 11, 16);
const enabled = BookingNightReminderSettings(enabled:true);

CustomerModel customer(String id, {bool active=true}) => CustomerModel(
  id:id, name:'العميل $id', phone:'771234567',
  primaryCurrency:CurrencyCode.yer,
  createdAt:now, updatedAt:now,
  accountStatus: active ? AccountStatus.active : AccountStatus.suspended,
);

RelationshipModel relationship(String id, {
  String merchant='m1', bool approved=true,
}) => RelationshipModel(
  id:'r-$merchant-$id',
  merchantId:merchant, customerId:id,
  createdBy:merchant, createdByRole:ParticipantRole.merchant,
  createdAt:now,
  approvals:[
    ApprovalRecord(actorId:merchant, role:ParticipantRole.merchant,
      decision:ApprovalDecision.declared, decidedAt:now),
    if(approved) ApprovalRecord(actorId:id, role:ParticipantRole.customer,
      decision:ApprovalDecision.approved, decidedAt:now),
  ],
);

ReservationDraft booking(String id, String customerId, DateTime day,
    ReservationStatus status, {String merchant='m1'}) => ReservationDraft(
  id:id, merchantId:merchant, customerId:customerId,
  customerName:'العميل $customerId', phone:'771234567',
  item:'حاشدي', bundles:1, day:day, pickupTime:'11:00',
  createdAt:day, status:status,
);

void main() {
  final clients=[
    customer('c1'),customer('c2'),customer('c3'),customer('c4'),
    customer('c5'), customer('c6',active:false),
  ];
  final relationships=[
    relationship('c1'),relationship('c2'),relationship('c3'),
    relationship('c4'),relationship('c5',approved:false),
    relationship('c6'),relationship('c7',merchant:'m2'),
  ];
  final bookings=[
    booking('yes1','c1',yesterday,ReservationStatus.confirmed),
    booking('yes2','c1',yesterday,ReservationStatus.ready),
    booking('week','c2',sevenDaysAgo,ReservationStatus.collected),
    booking('bad','c3',yesterday,ReservationStatus.awaitingConfirmation),
    booking('other','c4',yesterday,ReservationStatus.confirmed,merchant:'m2'),
    booking('out','c3',DateTime.utc(2026,11,7),ReservationStatus.confirmed),
  ];

  List<String> audience(NightReminderAudience a, {
    Set<String> optIns=const {'c1','c2','c3','c4','c5'},
    Set<String> favorites=const {'c2','c3','c5'},
    BookingNightReminderSettings settings=enabled,
    String? merchant='m1',
  }) => NightReminderAudienceQuery.recipients(
    audience:a, merchantId:merchant, now:now,
    customers:clients, relationships:relationships,
    bookings:bookings, consentedCustomerIds:optIns,
    merchantFavoriteCustomerIds:favorites, settings:settings,
  );

  test('yesterday audience includes distinct confirmed reservations only', () {
    expect(audience(NightReminderAudience.yesterdayConfirmed), ['c1']);
  });

  test('previous seven calendar days excludes old, unconfirmed and other merchant', () {
    expect(audience(NightReminderAudience.previousSevenDays), ['c1','c2']);
  });

  test('all approved and favorites still honor link, account and opt-in', () {
    expect(audience(NightReminderAudience.allApproved), ['c1','c2','c3','c4']);
    expect(audience(NightReminderAudience.favorites), ['c2','c3']);
    expect(audience(NightReminderAudience.allApproved,optIns:{'c1'}), ['c1']);
    expect(audience(NightReminderAudience.favorites,optIns:{}), isEmpty);
    expect(audience(NightReminderAudience.yesterdayConfirmed,merchant:'m2'),
      isEmpty);
    expect(audience(NightReminderAudience.allApproved,settings:
      const BookingNightReminderSettings()),isEmpty);
  });

  test('opened and confirmed statistics require trustworthy scoped distinct events', () {
    final at=now;
    ReminderEngagementEvent event(String merchant,String campaign,
        String customerId,ReminderEngagementType type) =>
      ReminderEngagementEvent(
        campaignId:campaign,merchantId:merchant,customerId:customerId,
        type:type,recordedAt:at);
    final events=[
      event('m1','campaign','c1',ReminderEngagementType.delivered),
      event('m1','campaign','c2',ReminderEngagementType.delivered),
      event('m1','campaign','c1',ReminderEngagementType.opened),
      event('m1','campaign','c1',ReminderEngagementType.opened),
      event('m1','campaign','c1',ReminderEngagementType.confirmedBooking),
      event('m1','campaign','c3',ReminderEngagementType.opened),
      event('m2','campaign','c2',ReminderEngagementType.opened),
      event('m1','other-campaign','c2',ReminderEngagementType.opened),
    ];
    final s=ReminderEngagementQuery.summarize(
      campaignId:'campaign',merchantId:'m1',recipientIds:['c1','c2','c3'],
      serverEvents:events);
    expect(s.recipientCount,3);
    expect(s.deliveredCount,2);
    expect(s.openedCount,1);
    expect(s.confirmedCount,1);
    expect(s.openedPercent,50);
    final unknown=ReminderEngagementQuery.summarize(
      campaignId:'untracked',merchantId:'m1',
      recipientIds:['c1'],serverEvents:const []);
    expect(unknown.openedPercent,isNull);
  });

  test('quick confirm requires delivered linked active customer and open intake', () {
    final campaign=NightReminderCampaignDraft(
      id:'c1',merchantId:'m1',day:tomorrow,
      audience:NightReminderAudience.yesterdayConfirmed,
      offeredItem:'قات حاشدي',pickupTime:'11:00');
    ReminderBookingDecision valid({
      NightReminderCampaignDraft? draft,
      String? customerId='c1',
      Set<String> deliveries=const {'c1'},
      BookingIntakeSettings intake=const BookingIntakeSettings(
        enabled:true,allDay:true),
      int quantity=2,
    }) => ReminderQuickBookingPolicy.check(
      campaign:draft??campaign, authenticatedCustomerId:customerId,
      quantity:quantity, verifiedDeliveredCustomerIds:deliveries,
      intakeSettings:intake,customers:clients,
      relationships:relationships,now:now);
    expect(valid().allowed,true);
    expect(valid(customerId:'c5').allowed,false);
    expect(valid(customerId:'c6',deliveries:{'c6'}).allowed,false);
    expect(valid(deliveries:{}).allowed,false);
    expect(valid(quantity:0).allowed,false);
    expect(valid(quantity:10001).allowed,false);
    expect(valid(intake:const BookingIntakeSettings()).allowed,false);
    expect(valid(draft:NightReminderCampaignDraft(
      id:'generic',merchantId:'m1',day:tomorrow,
      audience:NightReminderAudience.allApproved)).allowed,false);
    expect(MerchantSubscriptionFeature.values,hasLength(4));
  });
}
