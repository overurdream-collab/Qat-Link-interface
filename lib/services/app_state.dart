import 'package:flutter/foundation.dart';
import '../models/app_models.dart';

/// In-memory prototype only. Production authorization must derive identity
/// and role from a verified server-side session.
class AppState {
  final ValueNotifier<List<CustomerModel>> customers = ValueNotifier(const []);
  final ValueNotifier<List<RelationshipModel>> relationships = ValueNotifier(const []);
  final ValueNotifier<List<MovementModel>> movements = ValueNotifier(const []);

  List<RelationshipModel> get pendingRelationships => relationships.value
      .where((r) => r.status == RelationshipStatus.pending).toList(growable: false);
  List<MovementModel> get pendingMovements => movements.value
      .where((m) => m.status == MovementStatus.pending).toList(growable: false);

  void addCustomer(CustomerModel customer) {
    _unique(customers.value.map((c) => c.id), customer.id, 'customer');
    if (customer.name.trim().isEmpty || customer.phone.trim().isEmpty) {
      throw ArgumentError('Customer name and phone are required.');
    }
    if (customers.value.any((c) => _phone(c.phone) == _phone(customer.phone))) {
      throw StateError('A customer with this phone already exists.');
    }
    customers.value = List.unmodifiable([...customers.value,
      customer.copyWith(name: customer.name.trim(), phone: customer.phone.trim())]);
  }

  void requestRelationship({required String id, required String merchantId,
    required String customerId, required String actorId,
    required ParticipantRole actorRole, required DateTime createdAt}) {
    _unique(relationships.value.map((r) => r.id), id, 'relationship');
    if (!customers.value.any((c) => c.id == customerId &&
        c.accountStatus == AccountStatus.active)) {
      throw StateError('An active customer account is required.');
    }
    if (relationships.value.any((r) => r.merchantId == merchantId &&
        r.customerId == customerId && r.status != RelationshipStatus.cancelled)) {
      throw StateError('A relationship already exists for this pair.');
    }
    _participant(actorId, actorRole, merchantId, customerId);
    relationships.value = List.unmodifiable([...relationships.value,
      RelationshipModel(id: id, merchantId: merchantId, customerId: customerId,
        createdBy: actorId, createdByRole: actorRole, createdAt: createdAt,
        approvals: [ApprovalRecord(actorId: actorId, role: actorRole,
          decision: ApprovalDecision.declared, decidedAt: createdAt)])]);
  }

  void decideRelationship({required String relationshipId, required String actorId,
    required ParticipantRole actorRole, required ApprovalDecision decision,
    required DateTime decidedAt, String? reason}) {
    if (decision == ApprovalDecision.declared) {
      throw ArgumentError('A participant cannot submit a second declaration.');
    }
    final i = relationships.value.indexWhere((r) => r.id == relationshipId);
    if (i < 0) throw StateError('Relationship not found.');
    final current = relationships.value[i];
    _validateOtherParty(creatorId: current.createdBy,
      creatorRole: current.createdByRole, merchantId: current.merchantId,
      customerId: current.customerId, actorId: actorId, actorRole: actorRole,
      records: current.approvals, isPending: current.status == RelationshipStatus.pending);
    final next = current.copyWith(approvals: [...current.approvals,
      ApprovalRecord(actorId: actorId, role: actorRole, decision: decision,
        decidedAt: decidedAt, reason: reason)],
      rejectedReason: decision == ApprovalDecision.rejected ? reason : null,
      updatedAt: decidedAt);
    final rows = [...relationships.value]..[i] = next;
    relationships.value = List.unmodifiable(rows);
  }

  void addMovement(MovementModel movement) {
    _unique(movements.value.map((m) => m.id), movement.id, 'movement');
    final matches = relationships.value.where((r) => r.id == movement.relationshipId);
    if (matches.isEmpty || matches.single.status != RelationshipStatus.approved) {
      throw StateError('A financial movement requires an approved relationship.');
    }
    final rel = matches.single;
    if (rel.customerId != movement.customerId || rel.merchantId != movement.merchantId) {
      throw StateError('Movement parties do not match the relationship.');
    }
    _participant(movement.createdBy, movement.createdByRole,
      movement.merchantId, movement.customerId);
    if (movement.approvals.length != 1 ||
        movement.approvals.single.actorId != movement.createdBy ||
        movement.approvals.single.role != movement.createdByRole ||
        movement.approvals.single.decision != ApprovalDecision.declared) {
      throw StateError('A new movement must contain only its creator declaration.');
    }
    movements.value = List.unmodifiable([...movements.value, movement]);
  }

  void decideMovement({required String movementId, required String actorId,
    required ParticipantRole actorRole, required ApprovalDecision decision,
    required DateTime decidedAt, String? reason}) {
    if (decision == ApprovalDecision.declared) {
      throw ArgumentError('A participant cannot submit a second declaration.');
    }
    final i = movements.value.indexWhere((m) => m.id == movementId);
    if (i < 0) throw StateError('Movement not found.');
    final current = movements.value[i];
    _validateOtherParty(creatorId: current.createdBy,
      creatorRole: current.createdByRole, merchantId: current.merchantId,
      customerId: current.customerId, actorId: actorId, actorRole: actorRole,
      records: current.approvals, isPending: current.status == MovementStatus.pending);
    final next = current.copyWith(approvals: [...current.approvals,
      ApprovalRecord(actorId: actorId, role: actorRole, decision: decision,
        decidedAt: decidedAt, reason: reason)],
      rejectedReason: decision == ApprovalDecision.rejected ? reason : null,
      updatedAt: decidedAt);
    final rows = [...movements.value]..[i] = next;
    movements.value = List.unmodifiable(rows);
  }

  void _validateOtherParty({required String creatorId,
    required ParticipantRole creatorRole, required String merchantId,
    required String customerId, required String actorId,
    required ParticipantRole actorRole, required List<ApprovalRecord> records,
    required bool isPending}) {
    if (!isPending) throw StateError('This request is no longer pending.');
    _participant(actorId, actorRole, merchantId, customerId);
    if (actorId == creatorId || actorRole == creatorRole) {
      throw StateError('Only the other participant may decide.');
    }
    if (records.any((r) => r.actorId == actorId)) {
      throw StateError('This participant has already submitted a decision.');
    }
  }

  static void _participant(String actorId, ParticipantRole role,
      String merchantId, String customerId) {
    final expected = role == ParticipantRole.merchant ? merchantId : customerId;
    if (actorId != expected) throw StateError('Actor identity does not match role.');
  }

  static void _unique(Iterable<String> ids, String id, String type) {
    if (ids.contains(id)) throw StateError('$type id already exists: $id');
  }

  static String _phone(String value) => value.replaceAll(RegExp(r'[^0-9+]'), '');

  void dispose() {
    customers.dispose();
    relationships.dispose();
    movements.dispose();
  }
}
