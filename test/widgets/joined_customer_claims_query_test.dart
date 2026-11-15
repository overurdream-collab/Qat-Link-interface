import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/widgets/customers/joined_customer_claims_query.dart';
import 'package:qat_link/widgets/customers/merchant_debt_status_summary.dart';

void main() {
  final now = DateTime.utc(2026, 11, 15);
  CustomerModel account(String id, {bool active = true}) => CustomerModel(
    id: id, name: 'عميل متحقق', phone: '771234567',
    primaryCurrency: CurrencyCode.yer,
    createdAt: now, updatedAt: now,
    accountStatus: active ? AccountStatus.active : AccountStatus.suspended,
  );
  MerchantPendingContact contact(String id, String merchant) =>
    MerchantPendingContact(
      id: id, merchantId: merchant, name: 'اسم محلي',
      phone: '771234567', createdAt: now,
    );
  MerchantPendingDebt debt(String id, String merchant, String contactId,
      String value, CurrencyCode code) => MerchantPendingDebt(
    id: id, merchantId: merchant, contactId: contactId,
    amount: Decimal.parse(value), currency: code, createdAt: now,
  );
  VerifiedCustomerContactMatch match(String merchant, String contactId,
      {String customerId = 'verified-customer'}) =>
    VerifiedCustomerContactMatch(
      merchantId: merchant, contactId: contactId,
      customerId: customerId, verifiedAt: now,
    );

  final contacts = [
    contact('local1','merchant1'),
    contact('local2','merchant2'),
    contact('unlinked','merchant3'),
  ];
  final claims = [
    debt('claim1','merchant1','local1','15000',CurrencyCode.yer),
    debt('claim2','merchant1','local1','20',CurrencyCode.usd),
    debt('claim3','merchant2','local2','35000',CurrencyCode.yer),
    debt('unrelated','merchant3','unlinked','999999',CurrencyCode.yer),
  ];
  final links = [match('merchant1','local1'),match('merchant2','local2')];

  List<JoinedCustomerClaimRow> inbox({
    String? id='verified-customer',
    Iterable<CustomerModel>? customers,
    Iterable<VerifiedCustomerContactMatch>? matches,
    Iterable<RelationshipModel> relations=const [],
    Iterable<VerifiedCustomerClaimDecision> reviews=const [],
    Iterable<MerchantPendingDebt>? debts,
  }) => JoinedCustomerClaimsQuery.forCustomer(
    authenticatedCustomerId: id,
    customers: customers ?? [account('verified-customer')],
    contacts: contacts,
    claims: debts ?? claims,
    verifiedMatches: matches ?? links,
    relationships: relations,
    verifiedDecisions: reviews,
    verifiedMerchantNames: const {
      'merchant1': 'متجر 1',
      'merchant2': 'متجر 2',
      'merchant3': 'متجر 3',
    },
  );

  test('newly verified customer receives ALL prior claims as pending', () {
    final items = inbox();
    expect(items.map((c) => c.claim.id).toSet(),
      {'claim1','claim2','claim3'});
    expect(items.length, 3);
    expect(items.every((r) => r.stage == JoinedClaimStage.awaitingReview),
      true);
    expect(items.every((r) => r.canReview), true);
    expect(items.any((r) => r.merchantName == 'متجر 3'), false);
  });

  test('no OTP-verified match means NO account history even same phone', () {
    expect(inbox(matches: const []), isEmpty);
    expect(inbox(id:null), isEmpty);
    expect(inbox(id:'other'), isEmpty);
    expect(inbox(customers:[account('verified-customer', active:false)]),
      isEmpty);
    expect(inbox(matches:[match('merchant1','local1',
      customerId:'another')]), isEmpty);
  });

  test('duplicate claims or matches never duplicate the customer inbox', () {
    final got = inbox(
      matches:[...links, links.first],
      debts:[...claims, claims.first],
    );
    expect(got.length, 3);
    expect(got.where((e) => e.claim.id == 'claim1'), hasLength(1));
  });

  test('each claim retains its own decision and no automatic approval', () {
    final decision = VerifiedCustomerClaimDecision(
      merchantId:'merchant1',claimId:'claim1',
      customerId:'verified-customer',
      decision:PreRegistrationClaimDecision.accept,decidedAt:now,
    );
    var rows = inbox(reviews:[decision]);
    expect(rows.firstWhere((r) => r.claim.id == 'claim1').stage,
      JoinedClaimStage.acceptedAwaitingRelationship);
    expect(rows.firstWhere((r) => r.claim.id == 'claim1').canReview,false);
    expect(rows.firstWhere((r) => r.claim.id == 'claim2').canReview,true);

    final relation = RelationshipModel(
      id:'approved-link',merchantId:'merchant1',
      customerId:'verified-customer',
      createdBy:'merchant1',createdByRole:ParticipantRole.merchant,
      createdAt:now,approvals:[
        ApprovalRecord(actorId:'merchant1',
          role:ParticipantRole.merchant,
          decision:ApprovalDecision.declared,decidedAt:now),
        ApprovalRecord(actorId:'verified-customer',
          role:ParticipantRole.customer,
          decision:ApprovalDecision.approved,decidedAt:now),
      ],
    );
    rows = inbox(reviews:[decision],relations:[relation]);
    expect(rows.firstWhere((r) => r.claim.id == 'claim1').stage,
      JoinedClaimStage.acceptedAwaitingLedger);
    expect(rows.firstWhere((r) => r.claim.id == 'claim2').canReview,true);

    final refused=VerifiedCustomerClaimDecision(
      merchantId:'merchant1',claimId:'claim2',
      customerId:'verified-customer',
      decision:PreRegistrationClaimDecision.reject,decidedAt:now,
    );
    rows=inbox(reviews:[decision,refused],relations:[relation]);
    expect(rows.firstWhere((r) => r.claim.id == 'claim2').stage,
      JoinedClaimStage.rejected);
  });

  test('joined claims transition to waiting-for-customer, NEVER approved', () {
    final totals = MerchantDebtStatusQuery.summarize(
      merchantId:'merchant1',
      contacts:contacts,
      privateClaims:claims,
      relationships:const [],
      movements:const [],
      verifiedCustomerMatches: links,
    );
    final y=totals[CurrencyCode.yer]!;
    final u=totals[CurrencyCode.usd]!;
    expect(y.outsideApp,Decimal.zero);
    expect(y.awaitingCustomerApproval,Decimal.parse('15000'));
    expect(y.approvedNet,Decimal.zero);
    expect(u.awaitingCustomerApproval,Decimal.parse('20'));
    expect(u.approvedNet,Decimal.zero);

    final before = MerchantDebtStatusQuery.summarize(
      merchantId:'merchant1',
      contacts:contacts,privateClaims:claims,
      relationships:const [],movements:const [],
    );
    expect(before[CurrencyCode.yer]!.outsideApp,
      Decimal.parse('15000'));
    expect(before[CurrencyCode.yer]!.awaitingCustomerApproval,Decimal.zero);
  });

  test('rejected claim disappears from both pending balances', () {
    final refused=VerifiedCustomerClaimDecision(
      merchantId:'merchant1',claimId:'claim1',
      customerId:'verified-customer',
      decision:PreRegistrationClaimDecision.reject,decidedAt:now,
    );
    final after=MerchantDebtStatusQuery.summarize(
      merchantId:'merchant1',contacts:contacts,
      privateClaims:claims,relationships:const [],movements:const [],
      verifiedCustomerMatches:links,
      verifiedClaimDecisions:[refused],
    );
    expect(after[CurrencyCode.yer]!.outsideApp,Decimal.zero);
    expect(after[CurrencyCode.yer]!.awaitingCustomerApproval,Decimal.zero);
    expect(after[CurrencyCode.usd]!.awaitingCustomerApproval,
      Decimal.parse('20'));
  });

  test('verified backend transfer never double counts the same claim', () {
    final after=MerchantDebtStatusQuery.summarize(
      merchantId:'merchant1',contacts:contacts,
      privateClaims:claims,relationships:const [],movements:const [],
      verifiedCustomerMatches:links,
      verifiedTransferredClaimIds: {'claim1'},
    );
    expect(after[CurrencyCode.yer]!.outsideApp,Decimal.zero);
    expect(after[CurrencyCode.yer]!.awaitingCustomerApproval,Decimal.zero);
    expect(after[CurrencyCode.usd]!.awaitingCustomerApproval,
      Decimal.parse('20'));
  });
}
