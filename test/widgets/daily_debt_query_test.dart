import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/merchant_space/daily_debt_query.dart';

final day = DateTime.utc(2026, 11, 15);
RelationshipModel relation(String merchantId, String customerId) =>
    RelationshipModel(
      id: 'r-$merchantId-$customerId',
      merchantId: merchantId, customerId: customerId,
      createdBy: merchantId,
      createdByRole: ParticipantRole.merchant,
      createdAt: day,
      approvals: [
        ApprovalRecord(actorId: merchantId,
          role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared, decidedAt: day),
        ApprovalRecord(actorId: customerId,
          role: ParticipantRole.customer,
          decision: ApprovalDecision.approved, decidedAt: day),
      ],
    );

MovementModel movement({
  required String id,
  String merchantId = 'm1',
  String customerId = 'c1',
  CurrencyCode currency = CurrencyCode.yer,
  String amount = '100',
  required MovementStatus status,
  MovementType type = MovementType.debt,
  DateTime? approvedAt,
  DateTime? initiatedAt,
}) {
  final created = initiatedAt ?? (status == MovementStatus.pending
      ? DateTime.utc(2026,11,15,10) : DateTime.utc(2026,11,14,18));
  return MovementModel(
    id:id, relationshipId:'r-$merchantId-$customerId',
    merchantId:merchantId, customerId:customerId,
    amount:Decimal.parse(amount), currency:currency,
    type:type, createdBy:merchantId,
    createdByRole:ParticipantRole.merchant,
    createdAt:created,
    approvals:[
      ApprovalRecord(actorId:merchantId, role:ParticipantRole.merchant,
          decision:ApprovalDecision.declared, decidedAt:created),
      if(status != MovementStatus.pending)
        ApprovalRecord(actorId:customerId, role:ParticipantRole.customer,
          decision:status == MovementStatus.approved
              ? ApprovalDecision.approved : ApprovalDecision.rejected,
          decidedAt:approvedAt ?? DateTime.utc(2026,11,15,10)),
    ],
  );
}

void main() {
  final links=[relation('m1','c1'),relation('m2','c2')];

  DailyDebtSnapshot query(List<MovementModel> moves,
      {String? merchant='m1'}) => DailyDebtQuery.calculate(
    merchantId:merchant, day:day,
    movements:moves, relationships:links,
  );

  test('debt counted only after customer approval, by consent day and currency', () {
    final r=query([
      movement(id:'debt-y',status:MovementStatus.approved,
        amount:'150.75'),
      movement(id:'debt-sar',status:MovementStatus.approved,
        currency:CurrencyCode.sar,amount:'20'),
      movement(id:'pending',status:MovementStatus.pending,
        amount:'50'),
      movement(id:'rejected',status:MovementStatus.rejected,
        amount:'10000'),
      movement(id:'payment',status:MovementStatus.approved,
        type:MovementType.payment,amount:'200'),
      movement(id:'other',merchantId:'m2',customerId:'c2',
        status:MovementStatus.approved,amount:'99999'),
      movement(id:'yesterday',status:MovementStatus.approved,
        amount:'30',approvedAt:DateTime.utc(2026,11,14,6)),
    ]);
    expect(r.approved[CurrencyCode.yer],Decimal.parse('150.75'));
    expect(r.approved[CurrencyCode.sar],Decimal.parse('20'));
    expect(r.approvedCount,2);
    expect(r.pendingCount,1);
    expect(r.pending[CurrencyCode.yer],Decimal.parse('50'));
    expect(r.approved.containsKey(CurrencyCode.usd),false);
    expect(query([movement(id:'one',status:MovementStatus.approved)],
      merchant:null).approvedCount,0);
  });

  test('pending approval from yesterday remains excluded from today total', () {
    final r=query([movement(id:'waiting',status:MovementStatus.pending,
        initiatedAt:DateTime.utc(2026,11,14,18))]);
    expect(r.approvedCount,0);
    expect(r.approved,isEmpty);
    expect(r.pendingCount,0);
  });
}
