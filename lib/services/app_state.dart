import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

/// Identifies which participant is submitting an approval decision.
///
/// The authenticated application layer must derive this value from the
/// signed-in identity; it must never trust a user-selectable UI value.
enum ApprovalParty { merchant, customer }

/// In-memory application state for the current development phase.
///
/// New customers and movements are always stored as pending requests. This
/// class deliberately has no persistence or authentication responsibility.
class AppState {
  final ValueNotifier<List<CustomerModel>> customers =
      ValueNotifier<List<CustomerModel>>(const []);

  final ValueNotifier<List<MovementModel>> movements =
      ValueNotifier<List<MovementModel>>(const []);

  List<CustomerModel> get pendingCustomers => customers.value
      .where((customer) => customer.approval.isPending)
      .toList(growable: false);

  List<CustomerModel> get approvedCustomers => customers.value
      .where((customer) => customer.approval.isApproved)
      .toList(growable: false);

  List<MovementModel> get pendingMovements => movements.value
      .where((movement) => movement.approval.isPending)
      .toList(growable: false);

  /// Submits a customer registration request. It is never approved on create,
  /// even if the supplied model contains approval values.
  void addCustomer(CustomerModel customer) {
    _ensureUniqueCustomerId(customer.id);
    if (customer.name.trim().isEmpty) {
      throw ArgumentError.value(customer.name, 'name', 'Name is required.');
    }
    if (customer.phone.trim().isEmpty) {
      throw ArgumentError.value(customer.phone, 'phone', 'Phone is required.');
    }

    final request = customer.copyWith(
      name: customer.name.trim(),
      phone: customer.phone.trim(),
      approval: const ApprovalState(),
    );
    customers.value = List<CustomerModel>.unmodifiable([
      ...customers.value,
      request,
    ]);
  }

  /// Submits a debt/payment request for an already approved customer.
  /// The request always starts with two pending approvals.
  void addMovement(MovementModel movement) {
    _ensureUniqueMovementId(movement.id);
    final customerExists = customers.value.any(
      (customer) =>
          customer.id == movement.customerId && customer.approval.isApproved,
    );
    if (!customerExists) {
      throw StateError(
        'A financial movement can only be submitted for an approved customer.',
      );
    }

    final request = movement.copyWith(
      approval: const ApprovalState(),
    );
    movements.value = List<MovementModel>.unmodifiable([
      ...movements.value,
      request,
    ]);
  }

  bool approveCustomer(String customerId, ApprovalParty party) {
    return _decideCustomer(customerId, party, ApprovalStatus.approved);
  }

  bool rejectCustomer(String customerId, ApprovalParty party) {
    return _decideCustomer(customerId, party, ApprovalStatus.rejected);
  }

  bool approveMovement(String movementId, ApprovalParty party) {
    return _decideMovement(movementId, party, ApprovalStatus.approved);
  }

  bool rejectMovement(String movementId, ApprovalParty party) {
    return _decideMovement(movementId, party, ApprovalStatus.rejected);
  }

  bool _decideCustomer(
    String id,
    ApprovalParty party,
    ApprovalStatus decision,
  ) {
    final index = customers.value.indexWhere((item) => item.id == id);
    if (index == -1) return false;

    final current = customers.value[index];
    final nextApproval = _nextApproval(current.approval, party, decision);
    if (nextApproval == null) return false;

    final updated = [...customers.value];
    updated[index] = current.copyWith(approval: nextApproval);
    customers.value = List<CustomerModel>.unmodifiable(updated);
    return true;
  }

  bool _decideMovement(
    String id,
    ApprovalParty party,
    ApprovalStatus decision,
  ) {
    final index = movements.value.indexWhere((item) => item.id == id);
    if (index == -1) return false;

    final current = movements.value[index];
    final nextApproval = _nextApproval(current.approval, party, decision);
    if (nextApproval == null) return false;

    final updated = [...movements.value];
    updated[index] = current.copyWith(approval: nextApproval);
    movements.value = List<MovementModel>.unmodifiable(updated);
    return true;
  }

  ApprovalState? _nextApproval(
    ApprovalState current,
    ApprovalParty party,
    ApprovalStatus decision,
  ) {
    final existingDecision = switch (party) {
      ApprovalParty.merchant => current.merchant,
      ApprovalParty.customer => current.customer,
    };

    // A participant can decide only once while the request is pending.
    if (existingDecision != ApprovalStatus.pending ||
        !current.isPending) {
      return null;
    }

    return switch (party) {
      ApprovalParty.merchant => current.copyWith(merchant: decision),
      ApprovalParty.customer => current.copyWith(customer: decision),
    };
  }

  void _ensureUniqueCustomerId(String id) {
    if (customers.value.any((customer) => customer.id == id)) {
      throw StateError('Customer id already exists: $id');
    }
  }

  void _ensureUniqueMovementId(String id) {
    if (movements.value.any((movement) => movement.id == id)) {
      throw StateError('Movement id already exists: $id');
    }
  }

  void dispose() {
    customers.dispose();
    movements.dispose();
  }
}
