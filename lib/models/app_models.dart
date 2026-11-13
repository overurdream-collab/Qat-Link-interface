import 'package:decimal/decimal.dart';

enum CurrencyCode { yer, sar, usd }

enum AccountStatus { active, suspended, closed }

enum ParticipantRole { merchant, customer }

enum ApprovalDecision { declared, approved, rejected }

enum RelationshipStatus {
  pending,
  approved,
  rejected,
  cancelled,
  suspended,
}

enum MovementType { debt, payment }

enum MovementStatus { pending, approved, rejected }

/// One immutable, attributable event in the approval history.
class ApprovalRecord {
  const ApprovalRecord({
    required this.actorId,
    required this.role,
    required this.decision,
    required this.decidedAt,
    this.reason,
  });

  final String actorId;
  final ParticipantRole role;
  final ApprovalDecision decision;
  final DateTime decidedAt;
  final String? reason;
}

/// Approval is derived from append-only decision events:
/// the creator declares the record, and the other participant approves it.
abstract final class ApprovalPolicy {
  static bool isApproved(
    Iterable<ApprovalRecord> records, {
    required String creatorId,
    required ParticipantRole creatorRole,
  }) {
    final creatorDeclared = records.any(
      (r) =>
          r.actorId == creatorId &&
          r.role == creatorRole &&
          r.decision == ApprovalDecision.declared,
    );
    final otherRole = creatorRole == ParticipantRole.merchant
        ? ParticipantRole.customer
        : ParticipantRole.merchant;
    final otherApproved = records.any(
      (r) =>
          r.role == otherRole &&
          r.decision == ApprovalDecision.approved,
    );
    final rejected = records.any((r) => r.decision == ApprovalDecision.rejected);
    return creatorDeclared && otherApproved && !rejected;
  }

  static bool isRejected(Iterable<ApprovalRecord> records) =>
      records.any((r) => r.decision == ApprovalDecision.rejected);

  static bool isPending(
    Iterable<ApprovalRecord> records, {
    required String creatorId,
    required ParticipantRole creatorRole,
  }) =>
      !isApproved(
        records,
        creatorId: creatorId,
        creatorRole: creatorRole,
      ) &&
      !isRejected(records);
}

/// Customer identity/profile is independent from every merchant relationship.
class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.primaryCurrency,
    required this.createdAt,
    required this.updatedAt,
    this.accountStatus = AccountStatus.active,
    this.profileData = const {},
  });

  final String id;
  final String name;
  final String phone;
  final CurrencyCode primaryCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AccountStatus accountStatus;
  final Map<String, Object?> profileData;

  CustomerModel copyWith({
    String? name,
    String? phone,
    CurrencyCode? primaryCurrency,
    DateTime? updatedAt,
    AccountStatus? accountStatus,
    Map<String, Object?>? profileData,
  }) =>
      CustomerModel(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        primaryCurrency: primaryCurrency ?? this.primaryCurrency,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        accountStatus: accountStatus ?? this.accountStatus,
        profileData: profileData ?? this.profileData,
      );
}

class RelationshipModel {
  RelationshipModel({
    required this.id,
    required this.merchantId,
    required this.customerId,
    required this.createdBy,
    required this.createdByRole,
    required this.createdAt,
    required List<ApprovalRecord> approvals,
    this.statusOverride,
    this.rejectedReason,
    this.updatedAt,
  }) : approvals = List.unmodifiable(approvals);

  final String id;
  final String merchantId;
  final String customerId;
  final String createdBy;
  final ParticipantRole createdByRole;
  final DateTime createdAt;
  final List<ApprovalRecord> approvals;
  final RelationshipStatus? statusOverride;
  final String? rejectedReason;
  final DateTime? updatedAt;

  RelationshipStatus get status {
    if (statusOverride != null) return statusOverride!;
    if (ApprovalPolicy.isRejected(approvals)) return RelationshipStatus.rejected;
    if (ApprovalPolicy.isApproved(
      approvals,
      creatorId: createdBy,
      creatorRole: createdByRole,
    )) {
      return RelationshipStatus.approved;
    }
    return RelationshipStatus.pending;
  }

  RelationshipModel copyWith({
    List<ApprovalRecord>? approvals,
    RelationshipStatus? statusOverride,
    String? rejectedReason,
    DateTime? updatedAt,
  }) =>
      RelationshipModel(
        id: id,
        merchantId: merchantId,
        customerId: customerId,
        createdBy: createdBy,
        createdByRole: createdByRole,
        createdAt: createdAt,
        approvals: approvals ?? this.approvals,
        statusOverride: statusOverride ?? this.statusOverride,
        rejectedReason: rejectedReason ?? this.rejectedReason,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class MovementModel {
  MovementModel({
    required this.id,
    required this.relationshipId,
    required this.customerId,
    required this.merchantId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.createdBy,
    required this.createdByRole,
    required this.createdAt,
    required List<ApprovalRecord> approvals,
    this.description,
    this.rejectedReason,
    this.referenceMovementId,
    this.updatedAt,
  }) : approvals = List.unmodifiable(approvals) {
    if (amount <= Decimal.zero) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive.');
    }
  }

  final String id;
  final String relationshipId;
  final String customerId;
  final String merchantId;
  final Decimal amount;
  final CurrencyCode currency;
  final MovementType type;
  final String createdBy;
  final ParticipantRole createdByRole;
  final DateTime createdAt;
  final List<ApprovalRecord> approvals;
  final String? description;
  final String? rejectedReason;
  final String? referenceMovementId;
  final DateTime? updatedAt;

  MovementStatus get status {
    if (ApprovalPolicy.isRejected(approvals)) return MovementStatus.rejected;
    if (ApprovalPolicy.isApproved(
      approvals,
      creatorId: createdBy,
      creatorRole: createdByRole,
    )) {
      return MovementStatus.approved;
    }
    return MovementStatus.pending;
  }

  MovementModel copyWith({
    List<ApprovalRecord>? approvals,
    String? rejectedReason,
    String? referenceMovementId,
    DateTime? updatedAt,
  }) =>
      MovementModel(
        id: id,
        relationshipId: relationshipId,
        customerId: customerId,
        merchantId: merchantId,
        amount: amount,
        currency: currency,
        type: type,
        createdBy: createdBy,
        createdByRole: createdByRole,
        createdAt: createdAt,
        approvals: approvals ?? this.approvals,
        description: description,
        rejectedReason: rejectedReason ?? this.rejectedReason,
        referenceMovementId: referenceMovementId ?? this.referenceMovementId,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
