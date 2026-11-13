import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/app_state.dart';

void main() {
  late AppState state;
  final now = DateTime.utc(2026, 1, 1);
  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  CustomerModel customer({String id = 'c1', String phone = '700000000'}) =>
    CustomerModel(id: id, name: 'محمد علي', phone: phone,
      primaryCurrency: CurrencyCode.yer, createdAt: now, updatedAt: now);

  void addCustomer() => state.addCustomer(customer());

  void approvedRelationship() {
    addCustomer();
    state.requestRelationship(id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant, createdAt: now);
    state.decideRelationship(relationshipId: 'r1', actorId: 'c1',
      actorRole: ParticipantRole.customer, decision: ApprovalDecision.approved,
      decidedAt: now.add(const Duration(minutes: 1)));
  }

  MovementModel debt() => MovementModel(id: 'd1', relationshipId: 'r1',
    customerId: 'c1', merchantId: 'm1', amount: Decimal.parse('12.50'),
    currency: CurrencyCode.yer, type: MovementType.debt, createdBy: 'm1',
    createdByRole: ParticipantRole.merchant, createdAt: now, approvals: [
      ApprovalRecord(actorId: 'm1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: now),
    ]);

  test('customer account exists independently of merchant relationships', () {
    addCustomer();
    expect(state.customers.value.single.accountStatus, AccountStatus.active);
    expect(state.relationships.value, isEmpty);
  });

  test('relationship requires creator declaration and other party approval', () {
    addCustomer();
    state.requestRelationship(id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant, createdAt: now);
    expect(state.relationships.value.single.status, RelationshipStatus.pending);
    state.decideRelationship(relationshipId: 'r1', actorId: 'c1',
      actorRole: ParticipantRole.customer, decision: ApprovalDecision.approved,
      decidedAt: now);
    expect(state.relationships.value.single.status, RelationshipStatus.approved);
  });

  test('creator cannot approve their own relationship request a second time', () {
    addCustomer();
    state.requestRelationship(id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant, createdAt: now);
    expect(() => state.decideRelationship(relationshipId: 'r1', actorId: 'm1',
      actorRole: ParticipantRole.merchant, decision: ApprovalDecision.approved,
      decidedAt: now), throwsStateError);
  });

  test('movement cannot be created before relationship approval', () {
    addCustomer();
    state.requestRelationship(id: 'r1', merchantId: 'm1', customerId: 'c1',
      actorId: 'm1', actorRole: ParticipantRole.merchant, createdAt: now);
    expect(() => state.addMovement(debt()), throwsStateError);
  });

  test('creator declaration plus other party approval finalizes movement', () {
    approvedRelationship();
    state.addMovement(debt());
    expect(state.pendingMovements, hasLength(1));
    state.decideMovement(movementId: 'd1', actorId: 'c1',
      actorRole: ParticipantRole.customer, decision: ApprovalDecision.approved,
      decidedAt: now.add(const Duration(minutes: 2)));
    expect(state.movements.value.single.status, MovementStatus.approved);
    expect(state.movements.value.single.approvals, hasLength(2));
  });

  test('movement rejection is terminal and records its reason', () {
    approvedRelationship();
    state.addMovement(debt());
    state.decideMovement(movementId: 'd1', actorId: 'c1',
      actorRole: ParticipantRole.customer, decision: ApprovalDecision.rejected,
      decidedAt: now, reason: 'Amount disputed');
    expect(state.movements.value.single.status, MovementStatus.rejected);
    expect(state.movements.value.single.rejectedReason, 'Amount disputed');
    expect(() => state.decideMovement(movementId: 'd1', actorId: 'c1',
      actorRole: ParticipantRole.customer, decision: ApprovalDecision.approved,
      decidedAt: now), throwsStateError);
  });

  test('duplicate customer phone is rejected', () {
    addCustomer();
    expect(() => state.addCustomer(customer(id: 'c2', phone: '700 000 000')),
      throwsStateError);
  });
}
