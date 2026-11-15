import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/quick_actions/approved_customer_picker_model.dart';

final date = DateTime(2026, 11, 15);

CustomerModel customer(String id, {
  AccountStatus status = AccountStatus.active,
}) => CustomerModel(
  id: id, name: id == 'c1' ? 'محمد أحمد' : 'علي صالح',
  phone: id == 'c1' ? '777 123 456' : '733 987 654',
  primaryCurrency: CurrencyCode.yer,
  createdAt: date, updatedAt: date,
  accountStatus: status,
);

RelationshipModel relationship(
  String id, String customerId, String merchantId, {
  bool approved = true,
}) => RelationshipModel(
  id: id, merchantId: merchantId, customerId: customerId,
  createdBy: merchantId, createdByRole: ParticipantRole.merchant,
  createdAt: date,
  approvals: [
    ApprovalRecord(actorId: merchantId, role: ParticipantRole.merchant,
      decision: ApprovalDecision.declared, decidedAt: date),
    if (approved)
      ApprovalRecord(actorId: customerId, role: ParticipantRole.customer,
        decision: ApprovalDecision.approved, decidedAt: date),
  ],
);

void main() {
  final customers = [customer('c1'), customer('c2')];
  final relationships = [
    relationship('r1', 'c1', 'm1'),
    relationship('r2', 'c2', 'm1', approved: false),
    relationship('r3', 'c1', 'm2'),
  ];

  test('requires an authenticated merchant context', () {
    expect(ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: null,
    ), isEmpty);
    expect(ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: '',
    ), isEmpty);
  });

  test('only approved relationship and active customer can be chosen', () {
    final rows = ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: 'm1',
    );
    expect(rows.map((r) => r.customer.id), ['c1']);
    expect(rows.single.relationship.id, 'r1');
  });

  test('other merchants cannot select this merchant customers', () {
    final rows = ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: 'm2',
    );
    expect(rows.map((r) => r.relationship.id), ['r3']);
  });

  test('customer search matches name and normalized phone', () {
    for (final query in ['محمد', '777123456']) {
      final rows = ApprovedCustomerPickerModel.available(
        customers: customers, relationships: relationships,
        merchantId: 'm1', search: query,
      );
      expect(rows, hasLength(1), reason: query);
    }
    expect(ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: 'm1', search: 'غير موجود',
    ), isEmpty);
  });

  test('a formerly-approved customer cannot pass the final selection check', () {
    final selected = ApprovedCustomerPickerModel.available(
      customers: customers, relationships: relationships,
      merchantId: 'm1',
    ).single;
    expect(ApprovedCustomerPickerModel.isStillEligible(
      selection: selected, customers: customers,
      relationships: relationships, merchantId: 'm1',
    ), true);
    expect(ApprovedCustomerPickerModel.isStillEligible(
      selection: selected, customers: customers,
      relationships: [
        relationship('r1', 'c1', 'm1', approved: false),
      ],
      merchantId: 'm1',
    ), false);
  });

  test('inactive accounts do not appear', () {
    expect(ApprovedCustomerPickerModel.available(
      customers: [customer('c1', status: AccountStatus.suspended)],
      relationships: relationships, merchantId: 'm1',
    ), isEmpty);
  });
}
