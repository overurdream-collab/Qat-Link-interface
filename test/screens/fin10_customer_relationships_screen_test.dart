import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/screens/fin10_customer_relationships_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';

class TestRelationshipsGateway implements Fin08RelationshipsGateway {
  Fin08RelationshipStatus state = Fin08RelationshipStatus.pending;
  int decisions = 0;
  bool? lastAccept;
  bool fail = false;
  final first = DateTime.utc(2026, 11, 16);

  @override
  Future<Fin08Page<Fin08RelationshipInvite>> customerRelationships({
    String? cursor, int limit = 50,
  }) async {
    return Fin08Page([
      Fin08RelationshipInvite(
        id: cursor == null ? 'rel-one' : 'rel-two',
        merchantId: cursor == null ? 'merchant-one' : 'merchant-two',
        merchantName: cursor == null ? 'متجر الأصالة' : 'متجر السلام',
        status: cursor == null ? state : Fin08RelationshipStatus.rejected,
        createdAt: first,
      ),
    ], cursor == null ? 'page-2' : null);
  }

  @override
  Future<Fin08RelationshipDecisionReceipt> decideRelationship(
    String relationshipId, {required bool accept},
  ) async {
    decisions++;
    lastAccept = accept;
    if (fail) throw const Fin08ApiError('الخادم لم يؤكد القرار');
    state = accept
        ? Fin08RelationshipStatus.approved
        : Fin08RelationshipStatus.rejected;
    return Fin08RelationshipDecisionReceipt(
      id: relationshipId, status: state, newlyPostedDebts: 0,
    );
  }
}

void main() {
  Future<void> launch(WidgetTester tester, TestRelationshipsGateway gateway) async {
    await tester.pumpWidget(MaterialApp(
      home: Fin10CustomerRelationshipsScreen(gateway: gateway),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('verified merchant invitations are pending, never auto-approved', (tester) async {
    final gateway = TestRelationshipsGateway();
    await launch(tester, gateway);
    expect(find.byKey(const Key('fin10_relationship_rel-one')), findsOneWidget);
    expect(find.text('متجر الأصالة'), findsOneWidget);
    expect(find.text('بانتظار موافقة العميل'), findsOneWidget);
    expect(gateway.decisions, 0);
    await tester.tap(find.byKey(const Key('fin10_accept_rel-one')));
    await tester.pumpAndSettle();
    expect(find.text('الموافقة على ارتباط التاجر؟'), findsOneWidget);
    expect(gateway.decisions, 0);
    await tester.tap(find.byKey(const Key('fin10_confirm_relationship')));
    await tester.pumpAndSettle();
    expect(gateway.decisions, 1);
    expect(gateway.lastAccept, true);
    expect(find.text('ارتباط معتمد'), findsOneWidget);
    expect(find.byKey(const Key('fin10_accept_rel-one')), findsNothing);
  });

  testWidgets('failure does not claim approval; rejected historical requests remain visible', (tester) async {
    final gateway = TestRelationshipsGateway()..fail = true;
    await launch(tester, gateway);
    await tester.tap(find.byKey(const Key('fin10_reject_rel-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin10_confirm_relationship')));
    await tester.pumpAndSettle();
    expect(gateway.decisions, 1);
    expect(gateway.state, Fin08RelationshipStatus.pending);
    expect(find.textContaining('الخادم لم يؤكد القرار'), findsWidgets);
    expect(find.byKey(const Key('fin10_accept_rel-one')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fin10_more_relationships')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fin10_relationship_rel-two')), findsOneWidget);
    expect(find.text('تم رفض الارتباط'), findsOneWidget);
  });
}
