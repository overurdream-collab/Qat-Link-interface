import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/fin16_credit_limits_screen.dart';
import 'package:qat_link/services/fin16_credit_gateway.dart';

class FakeCreditGateway implements Fin16CreditGateway {
  int saves=0,reads=0;
  bool active=false,fail=false;
  Decimal? amount;
  String? mode;
  CurrencyCode? lastCurrency;

  @override
  Future<Fin16CreditSnapshot> read(String relationshipId) async{
    reads++;
    return Fin16CreditSnapshot(relationshipId,[
      Fin16CreditCurrency(
        currency:CurrencyCode.yer,enabled:active,version:active?1:0,
        limitAmount:active?amount:null,mode:active?mode:null,
        approvedBalance:Decimal.parse('-100'),
        pendingDebts:Decimal.parse('20000'),
        pendingPayments:Decimal.parse('10000'),
        pendingNetEstimate:Decimal.parse('10000'),approvedExceedsLimit:false),
      Fin16CreditCurrency(
        currency:CurrencyCode.sar,enabled:false,version:0,
        limitAmount:null,mode:null,approvedBalance:Decimal.zero,
        pendingDebts:Decimal.zero,pendingPayments:Decimal.zero,
        pendingNetEstimate:Decimal.zero,approvedExceedsLimit:false),
      Fin16CreditCurrency(
        currency:CurrencyCode.usd,enabled:false,version:0,
        limitAmount:null,mode:null,approvedBalance:Decimal.zero,
        pendingDebts:Decimal.zero,pendingPayments:Decimal.zero,
        pendingNetEstimate:Decimal.zero,approvedExceedsLimit:false),
    ]);
  }

  @override
  Future<Fin16PolicyReceipt> set(String relationshipId,CurrencyCode currency,{
      required bool enabled,Decimal? limitAmount,String? mode}) async{
    saves++;
    lastCurrency=currency;
    if(fail)throw Exception('Transient server failure');
    active=enabled;amount=enabled?limitAmount:null;this.mode=enabled?mode:null;
    return Fin16PolicyReceipt(enabled,currency,this.mode,amount,saves,false);
  }
}

void main(){
  final relationship='11111111-1111-4111-8111-111111111111';
  testWidgets('customer sees approved account credit and separate pending exposure without edit',
    (tester) async{
    final gateway=FakeCreditGateway();
    await tester.pumpWidget(MaterialApp(home:Fin16CreditLimitsScreen(
      gateway:gateway,relationshipId:relationship,merchantCanEdit:false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin16_approved_balance')),findsOneWidget);
    expect(find.textContaining('-100'),findsWidgets);
    expect(find.text('رصيد دائن لصالح العميل'),findsOneWidget);
    expect(find.textContaining('ديون معلقة: 20000'),findsOneWidget);
    expect(find.textContaining('دفعات معلقة: 10000'),findsOneWidget);
    expect(find.byKey(const Key('fin16_edit_credit')),findsNothing);
    await tester.tap(find.byKey(const Key('fin16_currency_usd')));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد حد ائتماني مُفعّل لهذه العملة'),findsOneWidget);
    expect(find.textContaining('ديون معلقة: 0'),findsOneWidget);
    expect(gateway.saves,0);
  });

  testWidgets('merchant requires explicit confirmation for limit setting and disable',
    (tester) async{
    final gateway=FakeCreditGateway();
    await tester.pumpWidget(MaterialApp(home:Fin16CreditLimitsScreen(
      gateway:gateway,relationshipId:relationship,merchantCanEdit:true)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('fin16_edit_credit')));
    await tester.tap(find.byKey(const Key('fin16_edit_credit')));
    await tester.pumpAndSettle();
    expect(gateway.saves,0);
    await tester.enterText(find.byKey(const Key('fin16_limit_amount')),'500.2501');
    await tester.tap(find.byKey(const Key('fin16_limit_mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منع إنشاء دين جديد').last);
    await tester.pumpAndSettle();
    expect(gateway.saves,0);
    await tester.tap(find.byKey(const Key('fin16_confirm_limit')));
    await tester.pumpAndSettle();
    expect(gateway.saves,1);
    expect(gateway.lastCurrency,CurrencyCode.yer);
    expect(gateway.amount,Decimal.parse('500.2501'));
    expect(gateway.mode,'block');
    expect(find.textContaining('500.2501'),findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('fin16_disable_credit')));
    await tester.tap(find.byKey(const Key('fin16_disable_credit')));
    await tester.pumpAndSettle();
    expect(gateway.saves,1);
    await tester.tap(find.byKey(const Key('fin16_confirm_disable')));
    await tester.pumpAndSettle();
    expect(gateway.saves,2);
    expect(gateway.active,false);
  });

  testWidgets('server error never changes locally displayed policy', (tester) async{
    final gateway=FakeCreditGateway()..fail=true;
    await tester.pumpWidget(MaterialApp(home:Fin16CreditLimitsScreen(
      gateway:gateway,relationshipId:relationship,merchantCanEdit:true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin16_edit_credit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('fin16_limit_amount')),'10');
    await tester.tap(find.byKey(const Key('fin16_confirm_limit')));
    await tester.pumpAndSettle();
    expect(gateway.saves,1);
    expect(gateway.active,false);
    expect(find.textContaining('تعذر التحقق من بيانات الحد الائتماني'),findsWidgets);
    expect(find.byKey(const Key('fin16_confirm_limit')),findsOneWidget);
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد حد ائتماني مُفعّل لهذه العملة'),findsOneWidget);
  });
}
