import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/fin08_merchant_relationships_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class _RelationshipsFake implements Fin08MerchantRelationshipsGateway {
  _RelationshipsFake({this.status = 'pending'});
  final String status;

  @override
  Future<Fin08Page<Fin08MerchantRelationship>> merchantRelationships(
          {String? cursor, int limit = 50}) async =>
      Fin08Page([
        Fin08MerchantRelationship(
          id: 'relationship-one',
          contactId: 'contact-one',
          contactName: 'عميل التاجر',
          status: status,
          createdAt: DateTime.utc(2026, 11, 20),
        )
      ], null);
}

void main() {
  testWidgets('approved relationship opens the ledger through the callback',
      (tester) async {
    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: Fin08MerchantRelationshipsScreen(
        gateway: _RelationshipsFake(status: 'approved'),
        onOpenLedger: (id) => opened = id,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fin08_merchant_relationship_relationship-one')),
        findsOneWidget);
    final button = find.byKey(const Key('fin13_open_ledger_relationship-one'));
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(opened, 'relationship-one');
  });

  testWidgets('pending relationship never exposes the ledger',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Fin08MerchantRelationshipsScreen(
        gateway: _RelationshipsFake(),
        onOpenLedger: (_) => fail('must not open before approval'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fin13_open_ledger_relationship-one')),
        findsNothing);
    expect(find.textContaining('بانتظار موافقة العميل'), findsOneWidget);
  });
}
