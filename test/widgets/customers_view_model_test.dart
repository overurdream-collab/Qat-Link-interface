import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/customers/customers_view_model.dart';

final _day = DateTime.utc(2026, 11, 15);

CustomerModel _customer(
  String id,
  String name,
  String phone, {
  CurrencyCode primary = CurrencyCode.yer,
}) => CustomerModel(
  id: id, name: name, phone: phone, primaryCurrency: primary,
  createdAt: _day.subtract(const Duration(days: 9)),
  updatedAt: _day.subtract(const Duration(days: 8)),
);

RelationshipModel _relationship(
  String customerId, {
  RelationshipStatus status = RelationshipStatus.approved,
}) => RelationshipModel(
  id: 'r_$customerId', merchantId: 'merchant1', customerId: customerId,
  createdBy: 'merchant1',
  createdByRole: ParticipantRole.merchant,
  createdAt: _day,
  approvals: [
    ApprovalRecord(actorId: 'merchant1', role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: _day),
    if (status == RelationshipStatus.approved)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: _day),
  ],
);

MovementModel _movement({
  required String id,
  required String customerId,
  required CurrencyCode currency,
  required String amount,
  required MovementType type,
  required MovementStatus status,
  DateTime? created,
}) {
  final date = created ?? _day;
  return MovementModel(
    id: id, relationshipId: 'r_$customerId',
    customerId: customerId, merchantId: 'merchant1',
    amount: Decimal.parse(amount),
    currency: currency, type: type,
    createdBy: 'merchant1', createdByRole: ParticipantRole.merchant,
    createdAt: date,
    approvals: [
      ApprovalRecord(actorId: 'merchant1', role: ParticipantRole.merchant,
        decision: ApprovalDecision.declared, decidedAt: date),
      if (status != MovementStatus.pending)
        ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
          decision: status == MovementStatus.approved
              ? ApprovalDecision.approved : ApprovalDecision.rejected,
          decidedAt: date),
    ],
  );
}

void main() {
  final people = [
    _customer('c1', 'محمد أحمد', '777 111 222'),
    _customer('c2', 'علي عبدالله', '733 999 888', primary: CurrencyCode.sar),
    _customer('c3', 'صالح يحيى', '711 555 666'),
  ];
  final rels = [
    _relationship('c1'), _relationship('c2'),
    _relationship('c3', status: RelationshipStatus.pending),
  ];
  final items = [
    _movement(id: 'd1', customerId: 'c1', currency: CurrencyCode.yer,
      amount: '145000', type: MovementType.debt,
      status: MovementStatus.approved),
    _movement(id: 'p1', customerId: 'c1', currency: CurrencyCode.yer,
      amount: '25000', type: MovementType.payment,
      status: MovementStatus.pending),
    _movement(id: 'p2', customerId: 'c1', currency: CurrencyCode.yer,
      amount: '10000', type: MovementType.payment,
      status: MovementStatus.approved),
    _movement(id: 'd2', customerId: 'c1', currency: CurrencyCode.usd,
      amount: '250', type: MovementType.debt,
      status: MovementStatus.approved),
    _movement(id: 'd3', customerId: 'c2', currency: CurrencyCode.sar,
      amount: '500', type: MovementType.debt,
      status: MovementStatus.approved),
    _movement(id: 'rejected', customerId: 'c1', currency: CurrencyCode.yer,
      amount: '999999', type: MovementType.debt,
      status: MovementStatus.rejected),
    _movement(id: 'unauthorized', customerId: 'c3',
      currency: CurrencyCode.yer,
      amount: '800000', type: MovementType.debt,
      status: MovementStatus.approved),
  ];

  List<CustomerCurrencyRow> view({
    CurrencyCode? currency = CurrencyCode.yer,
    CustomerListFilter filter = CustomerListFilter.all,
    CustomerSort sort = CustomerSort.highestDebt,
    String search = '',
  }) => CustomersViewModel.rows(
    customers: people, relationships: rels, movements: items,
    currency: currency, filter: filter, sort: sort, search: search,
    merchantId: 'merchant1',
  );

  test('a profile without approved join never appears as a merchant customer', () {
    final rows = view();
    expect(rows.any((r) => r.customer.id == 'c3'), false);
    expect(CustomersViewModel.pendingRelationships(rels), hasLength(1));
    expect(CustomersViewModel.distinctCustomers(rows), 2);
  });

  test('approved balance excludes pending and rejected, and is not an opening debt', () {
    final row = view().firstWhere((r) => r.customer.id == 'c1');
    expect(row.balance, Decimal.parse('135000'));
    expect(row.pendingAmount, Decimal.parse('25000'));
    expect(row.pendingOperations, 1);
    expect(CustomersViewModel.pendingMovements(view()), 1);
    expect(CustomersViewModel.customersInDebt(view()), 1);
  });

  test('all currencies remain separate, and duplicate client cards are explicit', () {
    final rows = view(currency: null);
    expect(rows.map((e) => e.currency).toList(), [
      CurrencyCode.yer, CurrencyCode.sar, CurrencyCode.usd,
    ]);
    final usd = rows.singleWhere((r) => r.currency == CurrencyCode.usd);
    expect(usd.balance, Decimal.parse('250'));
    expect(CustomersViewModel.distinctCustomers(rows), 2);
    expect(CustomersViewModel.customersInDebt(rows), 2);
  });

  test('debt filters ignore pending; pending counts are movements not customers', () {
    expect(view(filter: CustomerListFilter.unpaid).map((r) => r.customer.id),
      contains('c1'));
    expect(view(filter: CustomerListFilter.pending).map((r) => r.customer.id),
      ['c1']);
    expect(view(filter: CustomerListFilter.unpaidAndPending).length, 1);
    expect(view(filter: CustomerListFilter.settled).map((r) => r.customer.id),
      ['c2']);
  });

  test('Arabic name and phone searches are normalized', () {
    expect(view(search: 'محمد').map((r) => r.customer.id), ['c1']);
    expect(view(search: '777111222').map((r) => r.customer.id), ['c1']);
    expect(view(search: 'غير موجود'), isEmpty);
  });

  test('highest debt is the default within a selected currency', () {
    final rows = view(currency: CurrencyCode.yer);
    expect(rows.first.customer.id, 'c1');
    final asc = view(currency: CurrencyCode.yer,
      sort: CustomerSort.lowestDebt);
    expect(asc.first.customer.id, 'c2');
  });

  test('negative customer credits are not converted to zero', () {
    final credit = _movement(id: 'credit', customerId: 'c1',
      currency: CurrencyCode.yer, amount: '250000',
      type: MovementType.payment, status: MovementStatus.approved);
    final rows = CustomersViewModel.rows(
      customers: people, relationships: rels,
      movements: [...items, credit],
      currency: CurrencyCode.yer,
    );
    final row = rows.singleWhere((r) => r.customer.id == 'c1');
    expect(row.balance, Decimal.parse('-115000'));
    expect(rows.where((r) => r.balance > Decimal.zero), isEmpty);
  });

  test('merchant scoping prevents showing other merchants in the same state', () {
    final rows = CustomersViewModel.rows(
      customers: people, relationships: rels,
      movements: items, currency: CurrencyCode.yer,
      merchantId: 'a_different_merchant',
    );
    expect(rows, isEmpty);
  });
}
