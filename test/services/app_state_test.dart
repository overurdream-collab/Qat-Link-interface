import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/app_state.dart';

void main() {
  late AppState state;

  setUp(() => state = AppState());
  tearDown(() => state.dispose());

  CustomerModel customer({
    String id = 'customer-1',
    ApprovalState approval = const ApprovalState(),
  }) {
    return CustomerModel(
      id: id,
      name: '  محمد علي  ',
      phone: ' 700000000 ',
      primaryCurrency: CurrencyCode.yer,
      approval: approval,
    );
  }

  MovementModel movement({
    String id = 'movement-1',
    String customerId = 'customer-1',
    ApprovalState approval = const ApprovalState(),
  }) {
    return MovementModel(
      id: id,
      customerId: customerId,
      amount: 500,
      currency: CurrencyCode.yer,
      type: MovementType.debt,
      date: DateTime.utc(2026, 1, 1),
      approval: approval,
    );
  }

  void addApprovedCustomer() {
    state.addCustomer(customer());
    state.approveCustomer('customer-1', ApprovalParty.merchant);
    state.approveCustomer('customer-1', ApprovalParty.customer);
  }

  group('Customer approval workflow', () {
    test('new customer is pending even if pre-approved model is supplied', () {
      state.addCustomer(customer(
        approval: const ApprovalState(
          merchant: ApprovalStatus.approved,
          customer: ApprovalStatus.approved,
        ),
      ));

      expect(state.customers.value.single.approval.isPending, isTrue);
      expect(state.customers.value.single.name, 'محمد علي');
      expect(state.customers.value.single.phone, '700000000');
    });

    test('one approval does not activate a customer', () {
      state.addCustomer(customer());

      expect(
        state.approveCustomer('customer-1', ApprovalParty.merchant),
        isTrue,
      );
      expect(state.customers.value.single.isApproved, isFalse);
      expect(state.pendingCustomers, hasLength(1));
    });

    test('customer becomes active only after both parties approve', () {
      state.addCustomer(customer());
      state.approveCustomer('customer-1', ApprovalParty.merchant);
      state.approveCustomer('customer-1', ApprovalParty.customer);

      expect(state.customers.value.single.isApproved, isTrue);
      expect(state.approvedCustomers, hasLength(1));
    });

    test('rejection prevents approval and a second decision', () {
      state.addCustomer(customer());
      expect(
        state.rejectCustomer('customer-1', ApprovalParty.customer),
        isTrue,
      );
      expect(
        state.approveCustomer('customer-1', ApprovalParty.merchant),
        isFalse,
      );
      expect(state.customers.value.single.status, ApprovalStatus.rejected);
    });

    test('unknown IDs and duplicate IDs are rejected safely', () {
      expect(
        state.approveCustomer('missing', ApprovalParty.merchant),
        isFalse,
      );
      state.addCustomer(customer());
      expect(() => state.addCustomer(customer()), throwsStateError);
    });
  });

  group('Movement approval workflow', () {
    test('movement cannot be added for a pending or unknown customer', () {
      state.addCustomer(customer());
      expect(() => state.addMovement(movement()), throwsStateError);
      expect(state.movements.value, isEmpty);
    });

    test('new movement starts pending even if supplied as approved', () {
      addApprovedCustomer();
      state.addMovement(movement(
        approval: const ApprovalState(
          merchant: ApprovalStatus.approved,
          customer: ApprovalStatus.approved,
        ),
      ));

      expect(state.movements.value.single.approval.isPending, isTrue);
    });

    test('one approval is not enough to approve a movement', () {
      addApprovedCustomer();
      state.addMovement(movement());

      state.approveMovement('movement-1', ApprovalParty.merchant);
      expect(state.movements.value.single.status, MovementStatus.pending);
      expect(state.pendingMovements, hasLength(1));
    });

    test('both parties must approve the movement', () {
      addApprovedCustomer();
      state.addMovement(movement());

      state.approveMovement('movement-1', ApprovalParty.merchant);
      state.approveMovement('movement-1', ApprovalParty.customer);

      expect(state.movements.value.single.status, MovementStatus.approved);
      expect(state.pendingMovements, isEmpty);
    });

    test('either party can reject and a rejected request is terminal', () {
      addApprovedCustomer();
      state.addMovement(movement());

      state.rejectMovement('movement-1', ApprovalParty.customer);
      expect(
        state.approveMovement('movement-1', ApprovalParty.merchant),
        isFalse,
      );
      expect(state.movements.value.single.status, MovementStatus.rejected);
    });

    test('a party cannot submit a second decision', () {
      addApprovedCustomer();
      state.addMovement(movement());

      expect(
        state.approveMovement('movement-1', ApprovalParty.merchant),
        isTrue,
      );
      expect(
        state.rejectMovement('movement-1', ApprovalParty.merchant),
        isFalse,
      );
    });
  });
}
