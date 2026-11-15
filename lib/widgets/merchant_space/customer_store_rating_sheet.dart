import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/app_colors.dart';
import 'merchant_rating_policy.dart';

/// Reusable customer-side rating form for future public store details.
/// The caller MUST derive customer ID from authenticated session and
/// revalidate evidence server-side before persisting the review.
class CustomerStoreRatingSheet extends StatefulWidget {
  const CustomerStoreRatingSheet({
    super.key,
    required this.merchantId,
    required this.customerId,
    required this.customers,
    required this.relationships,
    required this.movements,
    this.onVerifiedSubmit,
  });

  final String merchantId;
  final String customerId;
  final List<CustomerModel> customers;
  final List<RelationshipModel> relationships;
  final List<MovementModel> movements;
  /// Sends after backend authorization; null until server integration.
  final Future<bool> Function(int stars, String comment)? onVerifiedSubmit;

  @override
  State<CustomerStoreRatingSheet> createState() =>
      _CustomerStoreRatingSheetState();
}

class _CustomerStoreRatingSheetState extends State<CustomerStoreRatingSheet> {
  int _selectedStars = 0;
  bool _busy = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final permitted = MerchantReviewPolicy.canRateFromApprovedPurchase(
      merchantId: widget.merchantId,
      customerId: widget.customerId,
      customers: widget.customers,
      relationships: widget.relationships,
      movements: widget.movements,
    );
    if (!permitted || _selectedStars == 0) return;
    if (widget.onVerifiedSubmit == null) return;
    setState(() => _busy = true);
    try {
      final ok = await widget.onVerifiedSubmit!(
        _selectedStars, _comment.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
          ? 'تم تسليم تقييمك للخادم للمراجعة'
          : 'لم يقبل الخادم التقييم؛ لم يتم نشر شيء.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إرسال التقييم.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final eligible = MerchantReviewPolicy.canRateFromApprovedPurchase(
      merchantId: widget.merchantId, customerId: widget.customerId,
      customers: widget.customers, relationships: widget.relationships,
      movements: widget.movements);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18, 10, 18, MediaQuery.viewInsetsOf(context).bottom + 18),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('قيّم تجربتك مع المتجر', style: TextStyle(
                color: c.petrol, fontSize: 19,
                fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('تقييم صادق من نجمة إلى خمس نجوم بعد شراء موثق.',
                style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      key: Key('rate_star_$star'),
                      tooltip: '$star من 5',
                      onPressed: !eligible
                          ? null : () => setState(() => _selectedStars = star),
                      icon: Icon(
                        star <= _selectedStars
                            ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: star <= _selectedStars
                          ? const Color(0xFFDA9A22) : c.muted,
                        size: 35,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 9),
              TextField(
                key: const Key('rating_comment'),
                controller: _comment,
                enabled: eligible,
                maxLines: 3,
                maxLength: 350,
                decoration: const InputDecoration(
                  labelText: 'رأيك في الجودة والتعامل (اختياري)',
                ),
              ),
              const SizedBox(height: 6),
              if (!eligible)
                Text('التقييم متاح بعد تعامل موثق ومعتمد مع هذا المتجر.',
                  style: TextStyle(color: c.pendingText, fontSize: 11)),
              if (eligible && widget.onVerifiedSubmit == null)
                Text('تسجيل التقييم ينتظر ربط حساب العميل وخدمة مراجعة التقييمات.',
                  style: TextStyle(color: c.pendingText, fontSize: 11)),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('rating_submit'),
                onPressed: eligible && _selectedStars > 0 &&
                        widget.onVerifiedSubmit != null && !_busy
                    ? _submit : null,
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(_busy ? 'جارٍ الإرسال' : 'إرسال التقييم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
