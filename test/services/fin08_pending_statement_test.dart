import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin08_pending_statement.dart';

void main(){
  final t=DateTime.utc(2026,11,16);
  final contact=Fin08MerchantContact(id:'c',name:'عميل خاص',phone:'+967771234567',createdAt:t);
  Fin08MerchantClaim row(String id,String amount,CurrencyCode currency,Fin08Stage stage)=>
    Fin08MerchantClaim(id:id,contactId:'c',amount:Decimal.parse(amount),
      currency:currency,createdAt:t,stage:stage);

  test('money subtotal keeps exact decimal precision without binary float or rounding',(){
    expect(Fin08PendingStatement.formatSubtotal(Decimal.parse('120')),'120.00');
    expect(Fin08PendingStatement.formatSubtotal(Decimal.parse('12.5')),'12.50');
    expect(Fin08PendingStatement.formatSubtotal(Decimal.parse('0.0001')),'0.0001');
    expect(Fin08PendingStatement.formatSubtotal(Decimal.parse('999999999999.9999')),'999999999999.9999');
  });

  test('unacknowledged ledger statement has explicit disclaimer and no currency mixing',(){
    final result=Fin08PendingStatement.compose(contact:contact,claims:[
      row('a','150.25',CurrencyCode.yer,Fin08Stage.outsideApp),
      row('b','49.75',CurrencyCode.yer,Fin08Stage.awaitingReview),
      row('c','10',CurrencyCode.usd,Fin08Stage.acceptedAwaitingRelationship),
      row('d','99',CurrencyCode.yer,Fin08Stage.approved),
      row('e','45',CurrencyCode.yer,Fin08Stage.rejected),
    ]);
    expect(result,contains('معلقة وغير معتمدة'));
    expect(result,contains('200.00'));
    expect(result,contains('10 USD'));
    expect(result,contains('مجموع المبالغ المعلقة (USD): 10'));
    expect(result,isNot(contains('99 YER')));
    expect(result,isNot(contains('45 YER')));
    expect(result,contains('لا يُعد إقراراً من العميل'));
    expect(result,contains('لا يؤثر على الرصيد المعتمد'));
    expect(result,isNot(contains('210.00')));
  });
}