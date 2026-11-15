import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../models/merchant_pending_models.dart';
import '../../theme/app_colors.dart';
import '../finance_display.dart';
import 'joined_customer_claims_query.dart';

class CustomerClaimReviewRequest {
  const CustomerClaimReviewRequest({
    required this.customerId,
    required this.merchantId,
    required this.claimId,
    required this.decision,
  });

  final String customerId;
  final String merchantId;
  final String claimId;
  final PreRegistrationClaimDecision decision;
}

/// Reusable inbox panel for the FUTURE authenticated customer home.
///
/// All prior merchant claims become visible after a VERIFIED customer/contact
/// account binding, even before accepting the relationship. No phone matching
/// or changes to approved balances occur in this widget.
///
/// The caller's onReview callback MUST persist a uniquely keyed server
/// decision for the authenticated customer and return true only on success.
/// Without that callback, actions are disabled (no fake approval).
class CustomerJoinedClaimsPanel extends StatefulWidget {
  const CustomerJoinedClaimsPanel({
    super.key,
    required this.authenticatedCustomerId,
    required this.customers,
    required this.contacts,
    required this.claims,
    required this.verifiedMatches,
    required this.relationships,
    required this.verifiedDecisions,
    required this.verifiedMerchantNames,
    this.onReview,
  });

  final String? authenticatedCustomerId;
  final List<CustomerModel> customers;
  final List<MerchantPendingContact> contacts;
  final List<MerchantPendingDebt> claims;
  final List<VerifiedCustomerContactMatch> verifiedMatches;
  final List<RelationshipModel> relationships;
  final List<VerifiedCustomerClaimDecision> verifiedDecisions;
  final Map<String, String> verifiedMerchantNames;
  final Future<bool> Function(CustomerClaimReviewRequest request)? onReview;

  @override
  State<CustomerJoinedClaimsPanel> createState() =>
      _CustomerJoinedClaimsPanelState();
}

class _CustomerJoinedClaimsPanelState extends State<CustomerJoinedClaimsPanel> {
  final _busyClaimIds = <String>{};

  Future<void> _review(
      JoinedCustomerClaimRow item, PreRegistrationClaimDecision decision) async {
    if (widget.onReview == null ||
        widget.authenticatedCustomerId == null ||
        !item.canReview) return;
    final claimKey = '${item.claim.merchantId}|${item.claim.id}';
    if (_busyClaimIds.contains(claimKey)) return;
    final willAccept = decision == PreRegistrationClaimDecision.accept;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(willAccept ? 'الموافقة على طلب الدين؟' : 'رفض طلب الدين؟'),
        content: Text(
          'طلب من ${item.merchantName}: '
          '${FinanceDisplay.amount(item.claim.amount)} '
          '${FinanceDisplay.currencyCode(item.claim.currency)}. '
          '${willAccept ? 'تُسجل موافقتك على هذه المطالبة وحدها. '
              'ولا تصبح رصيداً معتمداً قبل اكتمال موافقات العلاقة والمعاملة.' :
              'سيتم تسجيل رفضك لهذه المطالبة دون قبول أي دين.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('claim_confirm_decision'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(willAccept ? 'أوافق على هذا الدين' : 'أرفض هذا الدين'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _busyClaimIds.add(claimKey));
    try {
      final saved = await widget.onReview!(CustomerClaimReviewRequest(
        customerId: widget.authenticatedCustomerId!,
        merchantId: item.claim.merchantId,
        claimId: item.claim.id,
        decision: decision,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved
          ? 'سُجل القرار لدى الخادم. تُحدّث القائمة من الحالة الموثقة.'
          : 'لم يؤكد الخادم تسجيل القرار. ظل الطلب معلقاً.'),
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تسجيل القرار. لا يزال الطلب معلقاً.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busyClaimIds.remove(claimKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = JoinedCustomerClaimsQuery.forCustomer(
      authenticatedCustomerId: widget.authenticatedCustomerId,
      customers: widget.customers,
      contacts: widget.contacts,
      claims: widget.claims,
      verifiedMatches: widget.verifiedMatches,
      relationships: widget.relationships,
      verifiedDecisions: widget.verifiedDecisions,
      verifiedMerchantNames: widget.verifiedMerchantNames,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('طلبات ديون سابقة بانتظار مراجعتك',
          style: TextStyle(color: c.petrol,
            fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 5),
        Text('هذه طلبات سجّلها التجار قبل انضمامك. '
             'لم تُعتمد بعد ولا تدخل رصيدك المعتمد.',
          style: TextStyle(color: c.muted, fontSize: 11)),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Text('لا توجد طلبات سابقة مرتبطة بحسابك المتحقق منه.',
            style: TextStyle(color: c.muted, fontSize: 12))
        else
          for (final row in items) ...[
            _claimCard(c, row),
            const SizedBox(height: 9),
          ],
      ],
    );
  }

  Widget _claimCard(AppThemeColors c, JoinedCustomerClaimRow row) {
    final claim = row.claim;
    final claimKey = '${claim.merchantId}|${claim.id}';
    final disabled = widget.onReview == null ||
        _busyClaimIds.contains(claimKey) || !row.canReview;
    final status = switch (row.stage) {
      JoinedClaimStage.awaitingReview => 'بانتظار موافقتك',
      JoinedClaimStage.acceptedAwaitingRelationship =>
        'وافقت على الطلب — الارتباط لم يعتمد بعد',
      JoinedClaimStage.acceptedAwaitingLedger =>
        'وافقت على الطلب — بانتظار تأكيد الخادم',
      JoinedClaimStage.rejected => 'طلب مرفوض',
    };
    return Container(
      key: Key('joined_claim_${claim.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.cardBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(row.merchantName,
            style: TextStyle(color: c.petrol,
              fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('${FinanceDisplay.amount(claim.amount)} '
                '${FinanceDisplay.currencyCode(claim.currency)}',
            style: TextStyle(color: c.text,
              fontWeight: FontWeight.w900, fontSize: 18)),
          Text(claim.description ?? 'مطالبة مسجلة من التاجر',
            style: TextStyle(color: c.muted, fontSize: 11)),
          Text(status, style: TextStyle(
            color: c.pendingText, fontWeight: FontWeight.w700, fontSize: 11)),
          if (row.canReview) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton(
                key: Key('joined_claim_accept_${claim.id}'),
                onPressed: disabled
                    ? null : () => _review(row, PreRegistrationClaimDecision.accept),
                child: const Text('موافقة'),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(
                key: Key('joined_claim_reject_${claim.id}'),
                onPressed: disabled
                    ? null : () => _review(row, PreRegistrationClaimDecision.reject),
                child: const Text('رفض'),
              )),
            ]),
            if (widget.onReview == null)
              Text('تسجيل القرارات غير متصل بالخادم بعد.',
                style: TextStyle(color: c.muted, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}
