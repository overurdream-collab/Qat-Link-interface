import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_chrome.dart';
import '../widgets/finance_display.dart';

enum _ApprovalView { needsMerchant, waitingCustomer }

/// Read-only approval inbox for the UI-only merchant session.
/// Decisions stay disabled until a verified session and server gateway exist.
class MerchantApprovalCenterScreen extends StatefulWidget {
  const MerchantApprovalCenterScreen({
    super.key,
    required this.state,
    this.initialView = 0,
  });

  final AppState state;
  final int initialView;

  @override
  State<MerchantApprovalCenterScreen> createState() =>
      _MerchantApprovalCenterScreenState();
}

class _MerchantApprovalCenterScreenState
    extends State<MerchantApprovalCenterScreen> {
  late _ApprovalView _view = _ApprovalView
      .values[widget.initialView.clamp(0, _ApprovalView.values.length - 1).toInt()];

  String _customerName(String id) {
    for (final customer in widget.state.customers.value) {
      if (customer.id == id) return customer.name;
    }
    return 'عميل';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الموافقات',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.state.movements,
          widget.state.relationships,
          widget.state.customers,
        ]),
        builder: (context, _) {
          final incomingMovements = widget.state.pendingMovements
              .where((movement) =>
                  movement.createdByRole == ParticipantRole.customer)
              .toList(growable: false);
          final outgoingMovements = widget.state.pendingMovements
              .where((movement) =>
                  movement.createdByRole == ParticipantRole.merchant)
              .toList(growable: false);
          final incomingRelations = widget.state.pendingRelationships
              .where((relation) =>
                  relation.createdByRole == ParticipantRole.customer)
              .toList(growable: false);
          final rows = _view == _ApprovalView.needsMerchant
              ? incomingMovements
              : outgoingMovements;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppSurface(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: c.petrol),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'هذه معاينة من بيانات الذاكرة على هذا الجهاز. '
                        'لا يمكن اعتماد أو رفض عملية حتى يتصل الحساب الموثق بالخادم.',
                        style: TextStyle(
                            color: c.text, fontSize: 11, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<_ApprovalView>(
                key: const Key('merchant_approval_view'),
                segments: const [
                  ButtonSegment(
                    value: _ApprovalView.needsMerchant,
                    label: Text('تحتاج موافقتي'),
                    icon: Icon(Icons.inbox_outlined),
                  ),
                  ButtonSegment(
                    value: _ApprovalView.waitingCustomer,
                    label: Text('بانتظار العميل'),
                    icon: Icon(Icons.hourglass_top_rounded),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (selection) =>
                    setState(() => _view = selection.first),
              ),
              const SizedBox(height: 16),
              if (_view == _ApprovalView.needsMerchant &&
                  incomingRelations.isNotEmpty) ...[
                AppSectionTitle(
                  title: 'طلبات ارتباط من العملاء',
                  trailing: _count(c, incomingRelations.length),
                ),
                const SizedBox(height: 8),
                for (final relation in incomingRelations)
                  _relationCard(c, relation),
                const SizedBox(height: 18),
              ],
              AppSectionTitle(
                title: _view == _ApprovalView.needsMerchant
                    ? 'عمليات تنتظر موافقتك'
                    : 'عمليات تنتظر موافقة العملاء',
                trailing: _count(c, rows.length),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty &&
                  !(_view == _ApprovalView.needsMerchant &&
                      incomingRelations.isNotEmpty))
                AppSurface(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt_rounded,
                          color: c.success, size: 34),
                      const SizedBox(height: 8),
                      Text(
                        _view == _ApprovalView.needsMerchant
                            ? 'لا توجد عمليات تنتظر قرارك'
                            : 'لا توجد عمليات بانتظار العميل',
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                )
              else
                for (final movement in rows) _movementCard(c, movement),
            ],
          );
        },
      ),
    );
  }

  Widget _count(AppThemeColors c, int count) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.pale,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: TextStyle(
                color: c.petrol, fontSize: 11, fontWeight: FontWeight.w900)),
      );

  Widget _relationCard(AppThemeColors c, RelationshipModel relation) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppSurface(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: c.pale,
                child: Icon(Icons.person_add_alt_1_rounded, color: c.petrol),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_customerName(relation.customerId),
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w800)),
                    Text('طلب ارتباط — يحتاج مراجعة التاجر',
                        style: TextStyle(color: c.muted, fontSize: 10)),
                  ],
                ),
              ),
              Icon(Icons.lock_outline_rounded, color: c.muted, size: 17),
            ],
          ),
        ),
      );

  Widget _movementCard(AppThemeColors c, MovementModel movement) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppSurface(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: c.pale,
                    child: Icon(
                      movement.type == MovementType.debt
                          ? Icons.receipt_long_outlined
                          : Icons.payments_outlined,
                      color: c.petrol,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_customerName(movement.customerId),
                            style: TextStyle(
                                color: c.text, fontWeight: FontWeight.w800)),
                        Text(
                            movement.type == MovementType.debt
                                ? 'طلب تسجيل دين'
                                : 'طلب تسجيل دفعة',
                            style: TextStyle(color: c.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                  Text(
                    '${FinanceDisplay.amount(movement.amount)} '
                    '${FinanceDisplay.currencySymbol(movement.currency)}',
                    style: TextStyle(
                        color: c.petrol, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              if (movement.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(movement.description!,
                    style: TextStyle(color: c.muted, fontSize: 11)),
              ],
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(Icons.schedule_rounded, color: c.muted, size: 14),
                  const SizedBox(width: 4),
                  Text('بانتظار الطرف الآخر',
                      style: TextStyle(
                          color: c.pendingText,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('القرار غير متاح دون اتصال موثق',
                      style: TextStyle(color: c.muted, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
      );
}
