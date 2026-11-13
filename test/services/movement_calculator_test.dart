import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/movement_calculator.dart';

void main() {
  const customerId = 'customer-1';
  final movements = <MovementModel>[
    _movement(
      id: 'debt-approved',
      amount: 1000,
      type: MovementType.debt,
      status: MovementStatus.approved,
    ),
    _movement(
      id: 'payment-approved',
      amount: 250,
      type: MovementType.payment,
      status: MovementStatus.approved,
    ),
    _movement(
      id: 'debt-pending',
      amount: 400,
      type: MovementType.debt,
      status: MovementStatus.pending,
    ),
    _movement(
      id: 'payment-pending',
      amount: 100,
      type: MovementType.payment,
      status: MovementStatus.pending,
    ),
    _movement(
      id: 'debt-rejected',
      amount: 900,
      type: MovementType.debt,
      status: MovementStatus.rejected,
    ),
  ];

  group('ApprovalState', () {
    test('new requests default to pending approval from both parties', () {
      const approval = ApprovalState();
      expect(approval.merchant, ApprovalStatus.pending);
      expect(approval.customer, ApprovalStatus.pending);
      expect(approval.status, ApprovalStatus.pending);
    });

    test('one approval is not enough to approve a request', () {
      const approval = ApprovalState(merchant: ApprovalStatus.approved);
      expect(approval.status, ApprovalStatus.pending);
    });

    test('both approvals are required for approval', () {
      const approval = ApprovalState(
        merchant: ApprovalStatus.approved,
        customer: ApprovalStatus.approved,
      );
      expect(approval.status, ApprovalStatus.approved);
      expect(approval.isApproved, isTrue);
    });

    test('rejection by either party rejects the request', () {
      const approval = ApprovalState(
        merchant: ApprovalStatus.approved,
        customer: ApprovalStatus.rejected,
      );
      expect(approval.status, ApprovalStatus.rejected);
    });

    test('customer registration is pending until both parties approve', () {
      const customer = CustomerModel(
        id: 'new-customer',
        name: 'Test Customer',
        phone: '700000000',
        primaryCurrency: CurrencyCode.yer,
      );
      expect(customer.status, ApprovalStatus.pending);
      expect(customer.isApproved, isFalse);

      final approvedCustomer = CustomerModel(
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        primaryCurrency: customer.primaryCurrency,
        approval: const ApprovalState(
          merchant: ApprovalStatus.approved,
          customer: ApprovalStatus.approved,
        ),
      );
      expect(approvedCustomer.isApproved, isTrue);
    });
  });

  group('MovementCalculator.customerBalance', () {
    test('counts only movements approved by both parties', () {
      expect(
        MovementCalculator.customerBalance(
          movements,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        750,
      );
    });

    test('one party approval does not affect the approved balance', () {
      final oneApproval = _movement(
        id: 'one-approval',
        amount: 7000,
        type: MovementType.debt,
        status: MovementStatus.pending,
        approval: const ApprovalState(merchant: ApprovalStatus.approved),
      );

      expect(
        MovementCalculator.customerBalance(
          [...movements, oneApproval],
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        750,
      );
    });

    test('pending and rejected movements do not change approved balance', () {
      final baseline = movements.take(2).toList();
      expect(
        MovementCalculator.customerBalance(
          movements,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        MovementCalculator.customerBalance(
          baseline,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
      );
    });

    test('a payment greater than debt produces a customer credit balance', () {
      final credit = [
        _movement(
          id: 'debt',
          amount: 200,
          type: MovementType.debt,
          status: MovementStatus.approved,
        ),
        _movement(
          id: 'payment',
          amount: 350,
          type: MovementType.payment,
          status: MovementStatus.approved,
        ),
      ];

      expect(
        MovementCalculator.customerBalance(
          credit,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        -150,
      );
    });

    test('keeps currencies separate', () {
      final mixed = [
        _movement(
          id: 'yer',
          amount: 1000,
          type: MovementType.debt,
          status: MovementStatus.approved,
        ),
        _movement(
          id: 'sar',
          amount: 20,
          currency: CurrencyCode.sar,
          type: MovementType.debt,
          status: MovementStatus.approved,
        ),
      ];

      expect(
        MovementCalculator.customerBalance(
          mixed,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        1000,
      );
      expect(
        MovementCalculator.customerBalance(
          mixed,
          customerId: customerId,
          currency: CurrencyCode.sar,
        ),
        20,
      );
    });

    test('does not include another customer movements', () {
      final otherCustomer = _movement(
        id: 'other',
        amount: 5000,
        customerId: 'customer-2',
        type: MovementType.debt,
        status: MovementStatus.approved,
      );

      expect(
        MovementCalculator.customerBalance(
          [...movements, otherCustomer],
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        750,
      );
    });
  });

  group('MovementCalculator totals', () {
    test('returns approved debt and payment totals independently', () {
      expect(
        MovementCalculator.approvedDebts(
          movements,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        1000,
      );
      expect(
        MovementCalculator.approvedPayments(
          movements,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        250,
      );
    });

    test('pending total includes requests missing either approval', () {
      expect(
        MovementCalculator.pendingTotal(
          movements,
          customerId: customerId,
          currency: CurrencyCode.yer,
        ),
        500,
      );
    });

    test('balancesByCurrency returns a separate balance per currency', () {
      final mixed = [
        ...movements,
        _movement(
          id: 'sar-debt',
          amount: 30,
          currency: CurrencyCode.sar,
          type: MovementType.debt,
          status: MovementStatus.approved,
        ),
      ];

      final balances = MovementCalculator.balancesByCurrency(
        mixed,
        customerId: customerId,
      );

      expect(balances[CurrencyCode.yer], 750);
      expect(balances[CurrencyCode.sar], 30);
      expect(balances[CurrencyCode.usd], 0);
    });
  });
}

MovementModel _movement({
  required String id,
  required double amount,
  String customerId = 'customer-1',
  CurrencyCode currency = CurrencyCode.yer,
  required MovementType type,
  required MovementStatus status,
  ApprovalState? approval,
}) {
  final resolvedApproval = approval ??
      switch (status) {
        MovementStatus.pending => const ApprovalState(),
        MovementStatus.approved => const ApprovalState(
            merchant: ApprovalStatus.approved,
            customer: ApprovalStatus.approved,
          ),
        MovementStatus.rejected => const ApprovalState(
            merchant: ApprovalStatus.rejected,
          ),
      };

  return MovementModel(
    id: id,
    customerId: customerId,
    amount: amount,
    currency: currency,
    type: type,
    approval: resolvedApproval,
    date: DateTime.utc(2026, 1, 1),
  );
}
