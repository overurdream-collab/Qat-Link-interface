import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/widgets/customers/customer_statement_calculator.dart';
import 'package:qat_link/widgets/customers/customer_statement_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline Arabic statement renderer outputs a real PDF document',
      () async {
    final date = DateTime(2026, 11, 15);
    final customer = CustomerModel(
      id: 'client-one',
      name: 'محمد عبدالله',
      phone: '771234567',
      primaryCurrency: CurrencyCode.yer,
      createdAt: date,
      updatedAt: date,
    );
    final relationship = RelationshipModel(
      id: 'r1', merchantId: 'm1', customerId: 'client-one',
      createdBy: 'm1', createdByRole: ParticipantRole.merchant,
      createdAt: date,
      approvals: [
        ApprovalRecord(
          actorId: 'm1', role: ParticipantRole.merchant,
          decision: ApprovalDecision.declared, decidedAt: date),
        ApprovalRecord(
          actorId: 'client-one', role: ParticipantRole.customer,
          decision: ApprovalDecision.approved, decidedAt: date),
      ],
    );
    final statement = CustomerStatementCalculator.calculate(
      customerId: 'client-one',
      merchantId: 'm1',
      currency: CurrencyCode.yer,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
      relationships: [relationship],
      movements: [],
    );
    final pdf = await CustomerStatementPdf.create(
      customer: customer, statement: statement);
    expect(pdf.length, greaterThan(1500));
    expect(ascii.decode(pdf.sublist(0, 4)), '%PDF');
    expect(statement.openingBalance.toString(), '0');
    expect(statement.closingBalance.toString(), '0');
  });
}
