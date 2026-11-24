import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../auth/auth_brand_hero.dart';
import 'maqwati_peeking_mascot.dart';

/// The feed is empty until a trusted notifications API supplies real events.
/// This screen never reports that a synthetic sample was received.
class MaqwatiNotificationEvent {
  const MaqwatiNotificationEvent({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.receivedAt,
  });
  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime receivedAt;
}

class MaqwatiNotificationsSheet extends StatefulWidget {
  const MaqwatiNotificationsSheet({
    super.key,
    this.events = const <MaqwatiNotificationEvent>[],
  });

  final List<MaqwatiNotificationEvent> events;

  @override
  State<MaqwatiNotificationsSheet> createState() =>
      _MaqwatiNotificationsSheetState();
}

class _MaqwatiNotificationsSheetState extends State<MaqwatiNotificationsSheet> {
  bool _showPreview = false;
  int _previewCounter = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const MaqwatiBrandMark(height: 58),
            const SizedBox(height: 10),
            Text('التنبيهات والحجوزات',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.text,
                    fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (widget.events.isEmpty) ...[
              const MaqwatiPeekingMascot(
                key: Key('notifications_empty_mascot'),
                animate: false, size: 75),
              const SizedBox(height: 9),
              Text('لا توجد تنبيهات متصلة بالخادم حالياً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 13)),
            ] else
              for (final event in widget.events) ...[
                MaqwatiArrivalCard(
                  key: ValueKey(event.id),
                  category: event.category,
                  title: event.title,
                  message: event.message,
                  isNew: DateTime.now().difference(event.receivedAt).inSeconds
                      .abs() < 30,
                ),
                const SizedBox(height: 9),
              ],
            const SizedBox(height: 17),
            OutlinedButton.icon(
              key: const Key('preview_mascot_animation'),
              onPressed: () => setState(() {
                _showPreview = true;
                _previewCounter++;
              }),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('معاينة حركة الشخصية'),
            ),
            if (_showPreview) ...[
              const SizedBox(height: 9),
              Text('معاينة شكلية فقط — لم يتم إرسال أي إشعار.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, fontSize: 11)),
              const SizedBox(height: 8),
              MaqwatiArrivalCard(
                key: ValueKey('preview-$_previewCounter'),
                isNew: true,
                category: 'معاينة حركة',
                title: 'مرحباً بك في مقوتي لينك',
                message: 'هكذا تطل الشخصية عند ظهور إشعار داخل التطبيق.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
