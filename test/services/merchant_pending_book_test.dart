import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/models/merchant_pending_models.dart';
import 'package:qat_link/services/app_state.dart';

void main() {
  final day = DateTime.utc(2026, 11, 15);

  MerchantPendingContact contact(String id, String merchant,
      {String phone = '777123456'}) => MerchantPendingContact(
    id: id, merchantId: merchant, name: 'عميل بدون تطبيق',
    phone: phone, createdAt: day,
  );

  MerchantPendingDebt debt(String id, String contactId,
      String merchant, String amount, CurrencyCode currency,
      {DateTime? when}) => MerchantPendingDebt(
    id: id, contactId: contactId, merchantId: merchant,
    amount: Decimal.parse(amount), currency: currency,
    createdAt: when ?? day, description: 'مشتريات لدى التاجر',
  );

  test('merchant records unregistered contact and debt without app account', () {
    final state = AppState();
    addTearDown(state.dispose);
    state.addMerchantContact(contact('local-1', 'm1'));
    state.addMerchantPendingDebt(
      debt('claim-1', 'local-1', 'm1', '50000', CurrencyCode.yer));
    expect(state.customers.value, isEmpty);
    expect(state.relationships.value, isEmpty);
    expect(state.movements.value, isEmpty);
    expect(state.merchantContacts.value, hasLength(1));
    expect(state.merchantPendingDebts.value.single.amount,
      Decimal.parse('50000'));
    final statement=state.merchantPendingStatement(
      merchantId:'m1', contactId:'local-1',
      from:DateTime.utc(2026,11,1),to:day);
    expect(statement.byCurrency[CurrencyCode.yer],Decimal.parse('50000'));
    final shared=MerchantPendingDebtQuery.shareText(statement);
    expect(shared, contains('غير معتمدة من العميل'));
    expect(shared, contains('لم يوافق العميل'));
    expect(shared, contains('50000 YER'));
    expect(shared, isNot(contains('تم اعتماد')));
  });

  test('local tenant isolation blocks foreign contacts and statements', () {
    final state=AppState();
    addTearDown(state.dispose);
    state.addMerchantContact(contact('c-a','m1'));
    state.addMerchantContact(contact('c-b','m2'));
    expect(() => state.addMerchantPendingDebt(
      debt('x','c-a','m2','40',CurrencyCode.yer)), throwsStateError);
    expect(() => state.merchantPendingStatement(
      merchantId:'m2',contactId:'c-a',from:day,to:day), throwsStateError);
    expect(() => state.merchantPendingStatement(
      merchantId:null,contactId:'c-a',from:day,to:day), throwsStateError);
    expect(state.merchantPendingDebts.value,isEmpty);
  });

  test('one merchant cannot create duplicate phone or claim ids', () {
    final state=AppState();
    addTearDown(state.dispose);
    state.addMerchantContact(contact('c1','m1',phone:'777 123 456'));
    expect(()=>state.addMerchantContact(
      contact('c2','m1',phone:'777123456')),throwsStateError);
    // Another merchant may have the same person in its own private book.
    state.addMerchantContact(contact('c3','m2',phone:'777123456'));
    state.addMerchantPendingDebt(
      debt('p1','c1','m1','10',CurrencyCode.yer));
    expect(()=>state.addMerchantPendingDebt(
      debt('p1','c1','m1','20',CurrencyCode.yer)),throwsStateError);
    expect(state.merchantPendingDebts.value,hasLength(1));
  });

  test('invalid amount, phone, or merchant identity is rejected', () {
    final state=AppState();
    addTearDown(state.dispose);
    expect(()=>state.addMerchantContact(
      contact('x','m1',phone:'333')),throwsArgumentError);
    expect(()=>state.addMerchantContact(
      contact('x','',phone:'777123456')),throwsArgumentError);
    expect(()=>debt('x','c','m1','0',CurrencyCode.yer),throwsArgumentError);
    expect(()=>debt('x','c','m1','-1',CurrencyCode.yer),throwsArgumentError);
  });

  test('report filters period and currency without combining approved ledger', () {
    final state=AppState();
    addTearDown(state.dispose);
    state.addMerchantContact(contact('contact','m1'));
    state.addMerchantPendingDebt(
      debt('p1','contact','m1','130.50',CurrencyCode.yer));
    state.addMerchantPendingDebt(
      debt('p2','contact','m1','20',CurrencyCode.usd));
    state.addMerchantPendingDebt(
      debt('p3','contact','m1','17',CurrencyCode.yer,
        when:DateTime.utc(2026,10,10)));
    final report=state.merchantPendingStatement(
      merchantId:'m1',contactId:'contact',
      from:DateTime.utc(2026,11,1),to:day);
    expect(report.rows,hasLength(2));
    expect(report.byCurrency[CurrencyCode.yer],Decimal.parse('130.50'));
    expect(report.byCurrency[CurrencyCode.usd],Decimal.parse('20'));
    expect(report.byCurrency.containsKey(CurrencyCode.sar),false);
    expect(state.movements.value,isEmpty);
    expect(()=>state.merchantPendingStatement(
      merchantId:'m1',contactId:'contact',
      from:DateTime.utc(2026,12,1),to:day),throwsArgumentError);
  });

  test('claimed debt cannot be directly approved as a financial movement', () {
    final state=AppState();
    addTearDown(state.dispose);
    state.addMerchantContact(contact('contact','m1'));
    state.addMerchantPendingDebt(
      debt('claim','contact','m1','1200',CurrencyCode.yer));
    expect(()=>state.addMovement(MovementModel(
      id:'m',merchantId:'m1',customerId:'not-a-registered-account',
      relationshipId:'not-an-approved-relationship',
      amount:Decimal.parse('1200'),currency:CurrencyCode.yer,
      type:MovementType.debt,
      createdBy:'m1',createdByRole:ParticipantRole.merchant,
      createdAt:day,
      approvals:[ApprovalRecord(actorId:'m1',role:ParticipantRole.merchant,
        decision:ApprovalDecision.declared,decidedAt:day)],
    )),throwsStateError);
    expect(state.movements.value,isEmpty);
    expect(state.merchantPendingDebts.value,hasLength(1));
  });
}
