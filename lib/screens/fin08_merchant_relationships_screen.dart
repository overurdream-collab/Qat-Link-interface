import 'package:flutter/material.dart';

import '../services/fin08_api_client.dart';

/// Tenant-scoped merchant relationship list. Only an approved relationship
/// can open the FIN-13 ledger; the server re-checks ownership on every read.
class Fin08MerchantRelationshipsScreen extends StatefulWidget {
  const Fin08MerchantRelationshipsScreen({
    super.key,
    required this.gateway,
    this.onOpenLedger,
  });

  final Fin08MerchantRelationshipsGateway gateway;
  final void Function(String relationshipId)? onOpenLedger;

  @override
  State<Fin08MerchantRelationshipsScreen> createState() =>
      _Fin08MerchantRelationshipsScreenState();
}

class _Fin08MerchantRelationshipsScreenState
    extends State<Fin08MerchantRelationshipsScreen> {
  List<Fin08MerchantRelationship> _items = const [];
  String? _cursor;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.gateway
          .merchantRelationships(cursor: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        _items = more
            ? List.unmodifiable([..._items, ...result.items])
            : result.items;
        _cursor = result.nextCursor;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is Fin08ApiError
            ? e.message
            : 'تعذر تحميل علاقات العملاء من الخادم.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('علاقات العملاء')),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('تُعرض العلاقات المؤكدة من الخادم فقط. '
                'فتح الدفتر متاح للعلاقة المعتمدة، والخادم يتحقق من الملكية.'),
            const SizedBox(height: 16),
            if (_items.isEmpty && _loading)
              const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(_error!,
                  key: const Key('fin08_merchant_relationships_error'),
                  style: TextStyle(color: colors.error)),
              TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: const Text('إعادة المحاولة')),
            ],
            if (_items.isEmpty && !_loading && _error == null)
              const Text('لا توجد علاقات عملاء مؤكدة بعد.'),
            for (final item in _items)
              Card(
                key: Key('fin08_merchant_relationship_${item.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.contactName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        switch (item.status) {
                          'pending' => 'بانتظار موافقة العميل',
                          'approved' => 'العلاقة معتمدة',
                          'rejected' => 'العلاقة مرفوضة',
                          _ => 'حالة غير معروفة',
                        },
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      if (item.canOpenLedger &&
                          widget.onOpenLedger != null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: Key('fin13_open_ledger_${item.id}'),
                          onPressed: () => widget.onOpenLedger!(item.id),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: const Text('فتح الدفتر'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_cursor != null && !_loading)
              TextButton(
                key: const Key('fin08_more_merchant_relationships'),
                onPressed: () => _load(more: true),
                child: const Text('عرض علاقات أقدم'),
              ),
            if (_loading && _items.isNotEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
