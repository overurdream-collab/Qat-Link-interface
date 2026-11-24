import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import '../services/fin08_api_client.dart';
import '../services/fin13_ledger_gateway.dart';
import '../services/fin14_batch_gateway.dart';
import '../services/fin15_amendment_gateway.dart';
import '../services/fin16_credit_gateway.dart';
import '../services/identity_session_client.dart';
import '../services/maqwati_api_config.dart';
import '../services/session_store.dart';
import 'fin08_customer_claims_screen.dart';
import 'fin08_customer_relationships_screen.dart';
import 'fin08_merchant_book_screen.dart';
import 'fin08_merchant_relationships_screen.dart';
import 'fin13_relationship_ledger_screen.dart';
import 'fin15_amendments_screen.dart';
import 'verified_fin08_overview_screen.dart';

/// Opens the real, server-backed workspace for the authenticated role.
/// No local AppState or demo balance is used here.
class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({
    super.key,
    required this.session,
    this.gateway,
    this.batchGateway,
    this.amendmentGateway,
    this.ledgerGateway,
    this.creditGateway,
    this.store,
    this.onLoggedOut,
  });

  final IdentitySession session;
  final Fin08ClaimsGateway? gateway;
  final Fin14BatchGateway? batchGateway;
  final Fin15AmendmentGateway? amendmentGateway;
  final Fin13LedgerGateway? ledgerGateway;
  final Fin16CreditGateway? creditGateway;
  final SessionStore? store;
  final VoidCallback? onLoggedOut;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  http.Client? _http;
  Fin08ClaimsGateway? _gateway;
  Fin14BatchGateway? _batchGateway;
  Fin15AmendmentGateway? _amendmentGateway;
  Fin13LedgerGateway? _ledgerGateway;
  Fin16CreditGateway? _creditGateway;
  String? _configError;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _saveSession();
    _gateway = widget.gateway;
    _batchGateway = widget.batchGateway;
    _amendmentGateway = widget.amendmentGateway;
    _ledgerGateway = widget.ledgerGateway;
    _creditGateway = widget.creditGateway;
    if (_gateway == null) {
      final origin = MaqwatiApiConfig.origin;
      if (origin == null) {
        _configError = 'عنوان الخادم غير مهيأ. لا يمكن عرض أي بيانات.';
      } else {
        _http = http.Client();
        final transport = Fin08HttpClaimsGateway(
          baseUri: origin,
          client: _http!,
          accessToken: () async => widget.session.accessToken,
        );
        _gateway = transport;
        _batchGateway ??= Fin14HttpBatchGateway(transport);
        _amendmentGateway ??= Fin15HttpAmendmentGateway(transport);
        _ledgerGateway ??= Fin13HttpLedgerGateway(transport);
        _creditGateway ??= Fin16HttpCreditGateway(transport);
      }
    }
  }

  @override
  void dispose() {
    _http?.close();
    super.dispose();
  }

  Future<void> _saveSession() async {
    try {
      await (widget.store ?? SessionStore.instance).write(widget.session);
    } on Exception {
      // A storage failure must not block an already-valid in-memory session.
    }
  }

  Future<void> _logout() async {
    if (widget.onLoggedOut == null) {
      final origin = MaqwatiApiConfig.origin;
      if (origin != null) {
        final httpClient = http.Client();
        final client = IdentitySessionClient(
          baseUri: origin,
          httpClient: httpClient,
          timeout: const Duration(seconds: 4),
        );
        try {
          await client.logout(
            accessToken: widget.session.accessToken,
            refreshToken: widget.session.refreshToken,
          );
        } on Exception {
          // Revocation is best effort; local clear still signs the user out.
        } finally {
          httpClient.close();
        }
      }
    }
    try {
      await (widget.store ?? SessionStore.instance).clear();
    } on Exception {
      // Continue to login even if secure storage is unavailable.
    }
    if (!mounted) return;
    final onLoggedOut = widget.onLoggedOut;
    if (onLoggedOut != null) {
      onLoggedOut();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openLedger(String relationshipId) {
    final gateway = _ledgerGateway;
    if (gateway == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Fin13RelationshipLedgerScreen(
        gateway: gateway,
        relationshipId: relationshipId,
        actorId: widget.session.id,
        role: _isMerchant ? ParticipantRole.merchant : ParticipantRole.customer,
        batchGateway: _batchGateway,
        amendmentGateway: _amendmentGateway,
        creditGateway: _creditGateway,
      ),
    ));
  }

  bool get _isMerchant => widget.session.role == 'merchant';
  bool get _isCustomer => widget.session.role == 'customer';

  @override
  Widget build(BuildContext context) {
    final gateway = _gateway;
    final tabs = <_RoleTab>[];
    if (gateway != null) {
      if (_isMerchant) {
        tabs.add(_RoleTab(
          label: 'العملاء',
          icon: Icons.people_alt_outlined,
          body: Fin08MerchantBookScreen(
            gateway: gateway,
            amendmentGateway: _amendmentGateway,
            onOpenLedger: _ledgerGateway == null ? null : _openLedger,
          ),
        ));
        if (gateway is Fin08MerchantRelationshipsGateway) {
          tabs.add(_RoleTab(
            label: 'العلاقات',
            icon: Icons.handshake_outlined,
            body: Fin08MerchantRelationshipsScreen(
              gateway: gateway as Fin08MerchantRelationshipsGateway,
              onOpenLedger: _ledgerGateway == null ? null : _openLedger,
            ),
          ));
        }
      } else if (_isCustomer) {
        tabs.add(_RoleTab(
          label: 'التجار',
          icon: Icons.storefront_outlined,
          body: Fin08CustomerRelationshipsScreen(
            gateway: gateway,
            onOpenLedger:
                _ledgerGateway == null ? null : (r) => _openLedger(r.id),
          ),
        ));
        tabs.add(_RoleTab(
          label: 'المطالبات',
          icon: Icons.receipt_long_outlined,
          body: Fin08CustomerClaimsScreen(
            gateway: gateway,
            batchGateway: _batchGateway,
            amendmentGateway: _amendmentGateway,
          ),
        ));
      }
      final amendments = _amendmentGateway;
      if (amendments != null) {
        tabs.add(_RoleTab(
          label: 'التعديلات',
          icon: Icons.edit_note_outlined,
          body: Fin15AmendmentsScreen(
            gateway: amendments,
            forMerchant: _isMerchant,
          ),
        ));
      }
      if (MaqwatiApiConfig.origin != null) {
        tabs.add(_RoleTab(
          label: 'حسابي',
          icon: Icons.verified_user_outlined,
          body: VerifiedFin08OverviewScreen(session: widget.session),
        ));
      }
    }

    final safeIndex = tabs.isEmpty ? 0 : _index.clamp(0, tabs.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.displayName == null
            ? 'مقوتي لينك'
            : 'مقوتي لينك — ${widget.session.displayName}'),
        actions: [
          IconButton(
            key: const Key('role_home_logout'),
            onPressed: _logout,
            tooltip: 'تسجيل الخروج',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _buildBody(gateway, tabs, safeIndex),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                for (final tab in tabs)
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
              ],
            ),
    );
  }

  Widget _buildBody(
      Fin08ClaimsGateway? gateway, List<_RoleTab> tabs, int safeIndex) {
    if (_configError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(_configError!, textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    if (gateway == null || (!_isMerchant && !_isCustomer)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'هذا النوع من الحسابات غير مدعوم في هذه الواجهة.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (tabs.length == 1) return tabs.first.body;
    return IndexedStack(
      index: safeIndex,
      children: [for (final tab in tabs) tab.body],
    );
  }
}

class _RoleTab {
  const _RoleTab({required this.label, required this.icon, required this.body});
  final String label;
  final IconData icon;
  final Widget body;
}
