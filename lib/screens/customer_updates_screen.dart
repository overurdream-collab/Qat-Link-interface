import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/auth/auth_brand_hero.dart';
import '../widgets/notifications/maqwati_notifications_sheet.dart';
import '../widgets/notifications/maqwati_peeking_mascot.dart';

enum CustomerUpdateCategory { notifications, bookings }

class CustomerUpdate {
  const CustomerUpdate({
    required this.event,
    required this.category,
    this.bookingStatus,
  });

  final MaqwatiNotificationEvent event;
  final CustomerUpdateCategory category;
  /// Optional server-verified booking stage, never inferred from a message.
  final String? bookingStatus;
}

/// Read-only customer presentation. Source events must be authorized by the
/// customer API; this screen never creates or approves a financial movement.
class CustomerUpdatesScreen extends StatefulWidget {
  const CustomerUpdatesScreen({
    super.key,
    this.updates = const <CustomerUpdate>[],
    this.onOpen,
  });
  final List<CustomerUpdate> updates;
  final ValueChanged<CustomerUpdate>? onOpen;

  @override
  State<CustomerUpdatesScreen> createState() => _CustomerUpdatesScreenState();
}

class _CustomerUpdatesScreenState extends State<CustomerUpdatesScreen> {
  CustomerUpdateCategory _tab = CustomerUpdateCategory.notifications;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = widget.updates.where((u) => u.category == _tab).toList()
      ..sort((a, b) => b.event.receivedAt.compareTo(a.event.receivedAt));

    return Scaffold(
      appBar: AppBar(title: const Text('تنبيهاتي وحجوزاتي')),
      body: SafeArea(child: ListView(
        key: const Key('customer_updates_screen'),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const MaqwatiBrandMark(height: 68),
          const SizedBox(height: 14),
          Text('أهلاً بك، الجديد عندنا يطل عليك!',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.petrol,
                  fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: ChoiceChip(
              key: const Key('customer_tab_notifications'),
              label: const Text('التنبيهات'),
              selected: _tab == CustomerUpdateCategory.notifications,
              onSelected: (_) => setState(
                () => _tab = CustomerUpdateCategory.notifications),
            )),
            const SizedBox(width: 8),
            Expanded(child: ChoiceChip(
              key: const Key('customer_tab_bookings'),
              label: const Text('حجوزاتي'),
              selected: _tab == CustomerUpdateCategory.bookings,
              onSelected: (_) => setState(
                () => _tab = CustomerUpdateCategory.bookings),
            )),
          ]),
          const SizedBox(height: 18),
          if (selected.isEmpty) ...[
            const Center(child: MaqwatiPeekingMascot(
              animate: false, size: 90)),
            const SizedBox(height: 12),
            Text(_tab == CustomerUpdateCategory.bookings
                  ? 'لا توجد حجوزات موثّقة لعرضها.'
                  : 'لا توجد تنبيهات جديدة مرتبطة بحسابك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted)),
          ],
          for (final update in selected) ...[
            MaqwatiArrivalCard(
              key: ValueKey('customer-update-${update.event.id}'),
              category: update.bookingStatus == null
                  ? update.event.category
                  : '${update.event.category} • ${update.bookingStatus}',
              title: update.event.title,
              message: update.event.message,
              isNew: DateTime.now()
                    .difference(update.event.receivedAt)
                    .inSeconds.abs() < 30,
              onTap: widget.onOpen == null
                  ? null : () => widget.onOpen!(update),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          Text('الحجوزات هنا مستقلة عن الديون. لا يصبح أي مبلغ ديناً معتمداً دون الموافقات اللازمة.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 11)),
        ],
      )),
    );
  }
}
