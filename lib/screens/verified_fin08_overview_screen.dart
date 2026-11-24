import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/identity_session_client.dart';
import '../services/fin08_api_client.dart';
import '../services/maqwati_api_config.dart';

/// Read-only FIN08 overview reached only from a server-confirmed Identity session.
/// It never reads AppState demo balances and never permits account mutations.
class VerifiedFin08OverviewScreen extends StatefulWidget {
  const VerifiedFin08OverviewScreen({super.key, required this.session});
  final IdentitySession session;

  @override
  State<VerifiedFin08OverviewScreen> createState() => _VerifiedFin08OverviewScreenState();
}

class _VerifiedFin08OverviewScreenState extends State<VerifiedFin08OverviewScreen> {
  late final http.Client _http;
  late final Fin08HttpClaimsGateway _gateway;
  late Future<_ReadSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _http = http.Client();
    final origin = MaqwatiApiConfig.origin;
    if (origin == null) {
      _snapshot = Future.error(const Fin08ApiError('عنوان الخادم غير مهيأ.'));
    } else {
      _gateway = Fin08HttpClaimsGateway(
        baseUri: origin,
        client: _http,
        accessToken: () async => widget.session.accessToken,
      );
      _snapshot = _load();
    }
  }

  Future<_ReadSnapshot> _load() async {
    if (widget.session.role == 'merchant') {
      final contacts = await _gateway.merchantContacts();
      final summary = await _gateway.merchantClaimSummary();
      return _ReadSnapshot(contacts: contacts.items, summary: summary);
    }
    if (widget.session.role == 'customer') {
      final relationships = await _gateway.customerRelationships();
      final claims = await _gateway.customerPreviousClaims();
      return _ReadSnapshot(relationships: relationships.items, claims: claims.items);
    }
    throw const Fin08ApiError('الدور غير مخوّل للاطلاع على هذه البيانات.');
  }

  void _refresh() => setState(() { _snapshot = _load(); });

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بيانات الحساب من الخادم')),
    body: FutureBuilder<_ReadSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error;
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 12),
              Text(error is Fin08ApiError ? error.message :
                'تعذر قراءة بيانات الحساب من الخادم. لم نعرض أي بيانات تجريبية.',
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _refresh, child: const Text('إعادة المحاولة')),
            ]),
          ));
        }
        final data = snapshot.requireData;
        return RefreshIndicator(
          onRefresh: () async { _refresh(); await _snapshot; },
          child: ListView(padding: const EdgeInsets.all(18), children: [
            const Text('قراءة مباشرة من FIN08 — لا توجد أرصدة أو حركات تجريبية.',
              style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (widget.session.role == 'merchant') ...[
              const Text('ملخص المطالبات السابقة فقط — ليس الرصيد المالي الكامل'),
              for (final bucket in data.summary) Card(child: ListTile(
                title: Text(bucket.currency.name.toUpperCase()),
                subtitle: Text('غير معتمد: ${bucket.outsideApp} | انتظار موافقة: ${bucket.awaitingCustomer}\n'
                  'معتمد من المطالبات السابقة فقط: ${bucket.approvedFromClaims}'),
              )),
              const SizedBox(height: 12),
              Text('جهات الاتصال لدى الخادم: ${data.contacts.length} (الصفحة الأولى)'),
              for (final contact in data.contacts) Card(child: ListTile(
                title: Text(contact.name), subtitle: Text(contact.phone),
              )),
              if (data.contacts.isEmpty) const Text('لا توجد جهات اتصال مسجلة لدى الخادم.'),
            ] else ...[
              Text('طلبات الارتباط: ${data.relationships.length} (الصفحة الأولى)'),
              for (final relation in data.relationships) Card(child: ListTile(
                title: Text(relation.merchantName), subtitle: Text(relation.status),
              )),
              const SizedBox(height: 12),
              Text('المطالبات السابقة: ${data.claims.length} (الصفحة الأولى)'),
              for (final claim in data.claims) Card(child: ListTile(
                title: Text(claim.merchantName),
                subtitle: Text('${claim.amount} ${claim.currency.name.toUpperCase()} — ${claim.stage.label}'),
              )),
              if (data.relationships.isEmpty && data.claims.isEmpty)
                const Text('لا توجد طلبات مرتبطة بحسابك لدى الخادم.'),
            ],
          ]),
        );
      },
    ),
  );
}

class _ReadSnapshot {
  const _ReadSnapshot({
    this.contacts = const [],
    this.summary = const [],
    this.relationships = const [],
    this.claims = const [],
  });
  final List<Fin08MerchantContact> contacts;
  final List<Fin08CurrencyBuckets> summary;
  final List<Fin08CustomerRelationship> relationships;
  final List<Fin08PreviousClaim> claims;
}
