import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/models/app_models.dart';
import 'package:qat_link/screens/role_home_screen.dart';
import 'package:qat_link/services/fin08_api_client.dart';
import 'package:qat_link/services/fin13_ledger_gateway.dart';
import 'package:qat_link/services/identity_session_client.dart';
import 'package:qat_link/services/session_store.dart';

class _FakeLedger implements Fin13LedgerGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGateway
    implements Fin08ClaimsGateway, Fin08MerchantRelationshipsGateway {
  _FakeGateway({
    this.customer = false,
    this.relationshipStatus = 'pending',
    this.claimRelationshipStatus,
    this.merchantRelationshipStatus = 'pending',
  });
  final bool customer;
  final String relationshipStatus;
  final String? claimRelationshipStatus;
  final String merchantRelationshipStatus;

  @override
  Future<Fin08Page<Fin08MerchantContact>> merchantContacts(
          {String? cursor, int limit = 50, String? search, MovementType? type, CurrencyCode? currency, String? from, String? to, String sort = 'newest'}) async =>
      Fin08Page([
        Fin08MerchantContact(
          id: 'contact-one',
          name: 'أحمد',
          phone: '+967771234567',
          createdAt: DateTime.utc(2026, 11, 20),
        )
      ], null);

  @override
  Future<Fin08Page<Fin08MerchantRelationship>> merchantRelationships(
          {String? cursor, int limit = 50}) async =>
      Fin08Page([
        Fin08MerchantRelationship(
          id: 'merchant-relationship-one',
          contactId: 'contact-one',
          contactName: 'أحمد',
          status: merchantRelationshipStatus,
          createdAt: DateTime.utc(2026, 11, 20),
        )
      ], null);

  @override
  Future<Fin08Page<Fin08MerchantClaim>> merchantClaims(String contactId,
          {String? cursor, int limit = 50, String? search, MovementType? type, CurrencyCode? currency, String? from, String? to, String sort = 'newest'}) async =>
      Fin08Page([
        Fin08MerchantClaim(
          id: 'claim-one',
          contactId: contactId,
          amount: Decimal.parse('10000'),
          currency: CurrencyCode.yer,
          createdAt: DateTime.utc(2026, 11, 20),
          stage: Fin08Stage.outsideApp,
          relationshipId:
              claimRelationshipStatus == null ? null : 'relationship-one',
          relationshipStatus: claimRelationshipStatus,
        )
      ], null);

  @override
  Future<List<Fin08CurrencyBuckets>> merchantClaimSummary() async => [
        Fin08CurrencyBuckets(
          currency: CurrencyCode.yer,
          outsideApp: Decimal.parse('10000'),
          awaitingCustomer: Decimal.zero,
          approvedFromClaims: Decimal.zero,
        )
      ];

  @override
  Future<Fin08Page<Fin08CustomerRelationship>> customerRelationships(
          {String? cursor, int limit = 50}) async =>
      customer
          ? Fin08Page([
              Fin08CustomerRelationship(
                id: 'relationship-one',
                merchantId: 'merchant-one',
                merchantName: 'متجر الأصالة',
                status: relationshipStatus,
                createdAt: DateTime.utc(2026, 11, 18),
              )
            ], null)
          : const Fin08Page([], null);

  @override
  Future<Fin08Page<Fin08PreviousClaim>> customerPreviousClaims(
          {String? cursor, int limit = 50}) async =>
      customer
          ? Fin08Page([
              Fin08PreviousClaim(
                id: 'claim-one',
                merchantId: 'merchant-one',
                merchantName: 'متجر الأصالة',
                amount: Decimal.parse('1250'),
                currency: CurrencyCode.yer,
                createdAt: DateTime.utc(2026, 11, 15),
                stage: Fin08Stage.awaitingReview,
              )
            ], null)
          : const Fin08Page([], null);

  @override
  Future<Fin08MerchantContact> createMerchantContact(
          {required String name, required String phone}) async =>
      throw UnimplementedError();

  @override
  Future<Fin08ClaimReceipt> createMerchantClaim(
          {required String contactId,
          required Decimal amount,
          required CurrencyCode currency,
          required String idempotencyKey,
          String? description,
          MovementType type = MovementType.debt}) async =>
      throw UnimplementedError();

  @override
  Future<String> requestMerchantRelationship(String contactId) async =>
      throw UnimplementedError();

  @override
  Future<Fin08RelationshipReceipt> decideRelationship(String relationshipId,
          {required bool accept}) async =>
      throw UnimplementedError();

  @override
  Future<Fin08ClaimDecisionReceipt> decidePreviousClaim(String claimId,
          {required bool accept}) async =>
      throw UnimplementedError();
}

IdentitySession _session(String role) => IdentitySession(
      accessToken: 'token',
      id: 'account-one',
      role: role,
      displayName: role == 'merchant' ? 'متجر الأصالة' : 'أحمد',
    );

void main() {
  testWidgets('merchant session opens the server-backed customer book',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('merchant'),
        gateway: _FakeGateway(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('المطالبات'), findsNothing);
    expect(find.byKey(const Key('role_home_logout')), findsOneWidget);
  });

  testWidgets('customer session opens relationships and claim inbox',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('customer'),
        gateway: _FakeGateway(customer: true),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('التجار'), findsOneWidget);
    expect(find.text('المطالبات'), findsOneWidget);
    expect(find.text('متجر الأصالة'), findsWidgets);
    expect(find.text('العملاء'), findsNothing);
  });

  testWidgets('approved customer relationship exposes the ledger entry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('customer'),
        gateway: _FakeGateway(customer: true, relationshipStatus: 'approved'),
        ledgerGateway: _FakeLedger(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fin13_open_ledger_relationship-one')),
        findsOneWidget);
    expect(find.byKey(const Key('fin10_accept_relationship-one')), findsNothing);
  });

  testWidgets('approved merchant claim exposes the ledger entry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('merchant'),
        gateway: _FakeGateway(claimRelationshipStatus: 'approved'),
        ledgerGateway: _FakeLedger(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fin08_contact_contact-one')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last,const Offset(0,-400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fin13_open_ledger_claim_claim-one')),
        findsOneWidget);
  });

  testWidgets('merchant sees approved relationships and opens the ledger',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('merchant'),
        gateway: _FakeGateway(merchantRelationshipStatus: 'approved'),
        ledgerGateway: _FakeLedger(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العلاقات'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const Key('fin13_open_ledger_merchant-relationship-one')),
        findsOneWidget);
  });

  testWidgets('unsupported role fails closed without showing financial data',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('admin'),
        gateway: _FakeGateway(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('غير مدعوم'), findsOneWidget);
    expect(find.text('أحمد'), findsNothing);
  });

  testWidgets('workspace persists the session and clears it on logout',
      (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(MaterialApp(
      home: RoleHomeScreen(
        session: _session('merchant'),
        gateway: _FakeGateway(),
        store: store,
      ),
    ));
    await tester.pumpAndSettle();

    expect((await store.read())?.id, 'account-one');

    await tester.tap(find.byKey(const Key('role_home_logout')));
    await tester.pumpAndSettle();
    expect(await store.read(), isNull);
  });
}
