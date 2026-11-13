enum CurrencyCode { yer, sar, usd }

enum MovementType { debt, payment }

/// Overall movement status. It is derived from both parties' decisions.
enum MovementStatus { pending, approved, rejected }

/// Decision made independently by either party.
enum ApprovalStatus { pending, approved, rejected }

/// Holds the two mandatory decisions for any customer-created record or
/// financial movement. A record is approved only after BOTH parties approve.
class ApprovalState {
  const ApprovalState({
    this.merchant = ApprovalStatus.pending,
    this.customer = ApprovalStatus.pending,
  });

  final ApprovalStatus merchant;
  final ApprovalStatus customer;

  /// Rejection by either party rejects the request.
  /// Approval requires both decisions to be approved.
  ApprovalStatus get status {
    if (merchant == ApprovalStatus.rejected ||
        customer == ApprovalStatus.rejected) {
      return ApprovalStatus.rejected;
    }
    if (merchant == ApprovalStatus.approved &&
        customer == ApprovalStatus.approved) {
      return ApprovalStatus.approved;
    }
    return ApprovalStatus.pending;
  }

  bool get isApproved => status == ApprovalStatus.approved;
  bool get isRejected => status == ApprovalStatus.rejected;
  bool get isPending => status == ApprovalStatus.pending;

  ApprovalState copyWith({
    ApprovalStatus? merchant,
    ApprovalStatus? customer,
  }) {
    return ApprovalState(
      merchant: merchant ?? this.merchant,
      customer: customer ?? this.customer,
    );
  }
}

class MovementModel {
  const MovementModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.date,
    this.approval = const ApprovalState(),
    this.description,
  }) : assert(amount > 0, 'Movement amount must be greater than zero.');

  final String id;
  final String customerId;
  final double amount;
  final CurrencyCode currency;
  final MovementType type;
  final DateTime date;
  final ApprovalState approval;
  final String? description;

  /// Compatibility-friendly accounting status, always derived from the
  /// two independent approvals (never manually assigned).
  MovementStatus get status => switch (approval.status) {
        ApprovalStatus.pending => MovementStatus.pending,
        ApprovalStatus.approved => MovementStatus.approved,
        ApprovalStatus.rejected => MovementStatus.rejected,
      };
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.primaryCurrency,
    this.approval = const ApprovalState(),
  });

  final String id;
  final String name;
  final String phone;
  final CurrencyCode primaryCurrency;

  /// A newly registered customer remains pending until merchant AND customer
  /// approval have both been recorded.
  final ApprovalState approval;

  ApprovalStatus get status => approval.status;
  bool get isApproved => approval.isApproved;
}
