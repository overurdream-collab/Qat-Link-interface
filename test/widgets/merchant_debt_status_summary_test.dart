import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/widgets/customers/merchant_debt_status_summary.dart';

void main() {
  final date = DateTime.utc(2026, 11, 15);
  final contacts = <MerchantPendingContact>[
    MerchantPendingContact(id: 'local1', merchantId: 'm1',
      name: 'غير مشترك', phone: '771111111', createdAt: date),
    MerchantPendingContact(id: 'foreign', merchantId: 'm2',
      name: 'خاص بتاجر آخر', phone: '772222222', createdAt: date),
  ];
  final claims = <MerchantPendingDebt>[
    MerchantPendingDebt(id: 'outside1', merchantId: 'm1',
      contactId: 'local1', amount: Decimal.parse('50000'),
      currency: CurrencyCode.yer, createdAt: date),
    MerchantPendingDebt(id: 'outside2', merchantId: 'm1',
      contactId: 'local1', amount: Decimal.parse('125'),
      currency: CurrencyCode.usd, createdAt: date),
    MerchantPendingDebt(id: 'foreignDebt', merchantId: 'm2',
      contactId: 'foreign', amount: Decimal.parse('999999'),
      currency: CurrencyCode.yer, createdAt: date),
  ];

  RelationshipModel relationship(String merchant, String customer,
    {bool approved = true}) => RelationshipModel(
      id: 'relation-$merchant-$customer', merchantId: merchant,
      customerId: customer, createdBy: merchant,
      createdByRole: ParticipantRole.merchant, createdAt: date,
      approvals: [
        ApprovalRecord(actorId: merchant, role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared, decidedAt: date),
        if (approved)
          ApprovalRecord(actorId: customer, role: ParticipantRole.customer,
            decision: ApprovalDecision.approved, decidedAt: date),
      ],
    );

  MovementModel movement(String id, String merchant, String customer,
    String amount, CurrencyCode currency, MovementType type,
    {bool approved = false, bool rejected = false}) => MovementModel(
      id: id, relationshipId: 'relation-$merchant-$customer',
      merchantId: merchant, customerId: customer,
      amount: Decimal.parse(amount), currency: currency,
      type: type, createdBy: merchant, createdByRole: ParticipantRole.merchant,
      createdAt: date,
      approvals: [
        ApprovalRecord(actorId: merchant, role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared, decidedAt: date),
        if (approved || rejected)
          ApprovalRecord(actorId: customer, role: ParticipantRole.customer,
            decision: rejected ? ApprovalDecision.rejected
              : ApprovalDecision.approved, decidedAt: date),
      ],
    );

  test('three stages remain independent; USD and YER never combined', () {
    final totals = MerchantDebtStatusQuery.summarize(
      merchantId: 'm1', contacts: contacts,
      privateClaims: claims,
      relationships: [relationship('m1','c1')],
      movements: [
        movement('waiting', 'm1', 'c1', '30000',
          CurrencyCode.yer, MovementType.debt),
        movement('approved', 'm1', 'c1', '20000',
          CurrencyCode.yer, MovementType.debt, approved: true),
        movement('paid', 'm1', 'c1', '3000',
          CurrencyCode.yer, MovementType.payment, approved: true),
        movement('pendingPayment', 'm1', 'c1', '4000',
          CurrencyCode.yer, MovementType.payment),
        movement('rejected', 'm1', 'c1', '900000',
          CurrencyCode.yer, MovementType.debt, rejected: true),
        movement('usd', 'm1', 'c1', '40',
          CurrencyCode.usd, MovementType.debt, approved: true),
        movement('anotherMerchant', 'm2', 'c1', '800000',
          CurrencyCode.yer, MovementType.debt, approved: true),
      ],
    );
    final yer = totals[CurrencyCode.yer]!;
    expect(yer.outsideApp, Decimal.parse('50000'));
    expect(yer.awaitingCustomerApproval, Decimal.parse('30000'));
    expect(yer.approvedNet, Decimal.parse('17000'));
    expect(yer.outsideCount, 1);
    expect(yer.awaitingCount, 1);
    expect(yer.approvedCount, 2);
    final usd = totals[CurrencyCode.usd]!;
    expect(usd.outsideApp, Decimal.parse('125'));
    expect(usd.awaitingCustomerApproval, Decimal.zero);
    expect(usd.approvedNet, Decimal.parse('40'));
    expect(totals[CurrencyCode.sar]!.outsideApp, Decimal.zero);
  });

  test('unapproved relationship never grants recognized or waiting consent', () {
    final totals = MerchantDebtStatusQuery.summarize(
      merchantId:'m1',contacts:contacts,privateClaims:claims,
      relationships:[relationship('m1','c1',approved:false)],
      movements:[
        movement('fake', 'm1','c1','5000',
          CurrencyCode.yer,MovementType.debt,approved:true),
        movement('unverified', 'm1','c1','250',
          CurrencyCode.yer,MovementType.debt),
      ],
    );
    expect(totals[CurrencyCode.yer]!.outsideApp, Decimal.parse('50000'));
    expect(totals[CurrencyCode.yer]!.approvedNet, Decimal.zero);
    expect(totals[CurrencyCode.yer]!.awaitingCustomerApproval, Decimal.zero);
  });

  test('verified transfer removes private claim from outside-app bucket', () {
    final totals=MerchantDebtStatusQuery.summarize(
      merchantId:'m1',contacts:contacts,privateClaims:claims,
      relationships:[relationship('m1','c1')],
      movements:[movement('linked','m1','c1','50000',
        CurrencyCode.yer,MovementType.debt)],
      verifiedTransferredClaimIds: {'outside1'},
    );
    expect(totals[CurrencyCode.yer]!.outsideApp,Decimal.zero);
    expect(totals[CurrencyCode.yer]!.awaitingCustomerApproval,
      Decimal.parse('50000'));
    expect(totals[CurrencyCode.yer]!.approvedNet,Decimal.zero);
  });

  test('approved net is signed; lack of merchant identity shows no figures', () {
    final totals=MerchantDebtStatusQuery.summarize(
      merchantId:'m1',contacts:contacts,privateClaims:claims,
      relationships:[relationship('m1','c1')],
      movements:[
        movement('credit','m1','c1','35000',
          CurrencyCode.yer,MovementType.payment,approved:true),
      ],
    );
    expect(totals[CurrencyCode.yer]!.approvedNet,
      Decimal.parse('-35000'));
    expect(MerchantDebtStatusQuery.summarize(
      merchantId:null,contacts:contacts,privateClaims:claims,
      relationships:const [],movements:const []),isEmpty);
  });
}
