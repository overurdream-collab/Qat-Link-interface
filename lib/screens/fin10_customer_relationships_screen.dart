import 'package:flutter/material.dart';

import '../services/fin08_api_client.dart';
import 'fin08_customer_claims_screen.dart';

/// Read-only until the host supplies a real, verified customer JWT gateway.
/// The customer must approve each merchant relationship independently.
/// Historical debt claims require a separate approval for each claim.
class Fin10CustomerRelationshipsScreen extends StatefulWidget {
  const Fin10CustomerRelationshipsScreen({
    super.key,
    required this.gateway,
    this.claimsGateway,
  });

  final Fin08RelationshipsGateway gateway;
  final Fin08ClaimsGateway? claimsGateway;

  @override
  State<Fin10CustomerRelationshipsScreen> createState() =>
      _Fin10CustomerRelationshipsScreenState();
}

class _Fin10CustomerRelationshipsScreenState
    extends State<Fin10CustomerRelationshipsScreen> {
  List<Fin08RelationshipInvite> _items = const [];
  final Set<String> _submitting = {};
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
    setState(() { _loading = true; _error = null; });
    try {
      final page = await widget.gateway.customerRelationships(
        cursor: more ? _cursor : null,
      );
      if (!mounted) return;
      setState(() {
        _items = more
            ? List.unmodifiable([..._items, ...page.items])
            : page.items;
        _cursor = page.nextCursor;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is Fin08ApiError
          ? error.message : 'تعذر استرجاع طلبات الارتباط من الخادم.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(Fin08RelationshipInvite item, bool accept) async {
    if (!item.canReview || _submitting.contains(item.id) || _loading) return;
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'الموافقة على ارتباط التاجر؟' : 'رفض الارتباط؟'),
        content: Text('التاجر: ${item.merchantName}. '
          'كل علاقة تحتاج قراراً مستقلاً. '
          'قبول الارتباط لا يعني موافقتك على ديون لم تراجعها، '
          'لكنه قد يعتمد المطالبات التي وافقت عليها سابقاً بشكل منفصل '
          'إذا اكتملت جميع شروطها.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء')),
          FilledButton(
            key: const Key('fin10_confirm_relationship'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(accept ? 'أوافق على الارتباط' : 'أرفض الارتباط'),
          ),
        ],
      ),
    );
    if (!mounted || confirmation != true) return;
    setState(() => _submitting.add(item.id));
    try {
      final receipt = await widget.gateway.decideRelationship(item.id, accept: accept);
      if (!mounted) return;
      final message = receipt.newlyPostedDebts > 0
          ? 'اعتمد الخادم ${receipt.newlyPostedDebts} من المطالبات التي سبق قبولها بشكل مستقل.'
          : accept
              ? 'تمت موافقتك على العلاقة لدى الخادم، دون قبول ديون أخرى تلقائياً.'
              : 'تم تسجيل رفض العلاقة لدى الخادم دون اعتماد ديون.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error is Fin08ApiError
          ? error.message : 'لم يؤكد الخادم تسجيل القرار. راجع الحالة قبل إعادة المحاولة.')));
    } finally {
      if (mounted) setState(() => _submitting.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلبات ارتباط التجار'),
        actions: [
          if (widget.claimsGateway != null)
            IconButton(
              key: const Key('fin10_open_previous_claims'),
              tooltip: 'الديون السابقة',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => Fin08CustomerClaimsScreen(
                  gateway: widget.claimsGateway!),
              )),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text('تظهر هنا طلبات ارتباط التجار المرتبطة بهاتفك بعد التحقق منه.',
              style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('كل تاجر وديونه يحتاجان موافقات مستقلة. '
              'مجرد تثبيت التطبيق لا يعني قبول أي علاقة أو دين.',
              style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 15),
            if (_error != null) ...[
              Text(_error!, key: const Key('fin10_relationship_error'),
                style: TextStyle(color: colors.error)),
              TextButton(onPressed: _loading ? null : () => _load(),
                child: const Text('إعادة المحاولة')),
            ],
            if (_items.isEmpty && _loading)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty && _error == null)
              const Padding(padding: EdgeInsets.all(20),
                child: Text('لا توجد طلبات ارتباط مرتبطة بحسابك الموثق.')),
            for (final item in _items)
              Card(
                key: Key('fin10_relationship_${item.id}'),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.merchantName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(item.status.label,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                      if (item.canReview) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: FilledButton(
                            key: Key('fin10_accept_${item.id}'),
                            onPressed: _submitting.contains(item.id)
                                ? null : () => _review(item, true),
                            child: const Text('موافقة'),
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(
                            key: Key('fin10_reject_${item.id}'),
                            onPressed: _submitting.contains(item.id)
                                ? null : () => _review(item, false),
                            child: const Text('رفض'),
                          )),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            if (_items.isNotEmpty && _loading)
              const Center(child: CircularProgressIndicator()),
            if (_cursor != null && !_loading)
              TextButton(
                key: const Key('fin10_more_relationships'),
                onPressed: () => _load(more: true),
                child: const Text('عرض المزيد من التجار'),
              ),
          ],
        ),
      ),
    );
  }
}
