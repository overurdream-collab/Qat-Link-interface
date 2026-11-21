import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/auth/auth_brand_hero.dart';
import '../widgets/notifications/maqwati_incoming_notification_host.dart';
import '../widgets/notifications/maqwati_notifications_sheet.dart';
import '../widgets/notifications/maqwati_peeking_mascot.dart';

/// Debug-only UX preview. Never connects to network or a financial account.
/// The entry point is visible only when kDebugMode is true in LoginScreen.
class NotificationDesignPreviewScreen extends StatefulWidget {
  const NotificationDesignPreviewScreen({super.key});

  @override
  State<NotificationDesignPreviewScreen> createState() =>
      _NotificationDesignPreviewScreenState();
}

class _NotificationDesignPreviewScreenState
    extends State<NotificationDesignPreviewScreen> {
  int _counter = 0;
  MaqwatiNotificationEvent? _preview;

  void _simulate({required bool booking}) {
    setState(() {
      _counter++;
      _preview = MaqwatiNotificationEvent(
        id: 'local-demo-$_counter',
        category: booking ? 'معاينة حجز' : 'معاينة تنبيه',
        title: booking ? 'ظهر حجز جديد!' : 'لديك إشعار جديد!',
        message: booking
            ? 'محاكاة فقط: تظهر شخصية مقوتي بجوار الحجز الجديد.'
            : 'محاكاة فقط: تطل شخصية مقوتي عند وصول التنبيه.',
        receivedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MaqwatiIncomingNotificationHost(
      event: _preview,
      child: Scaffold(
        appBar: AppBar(title: const Text('معاينة إشعارات مقوتي')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MaqwatiBrandMark(height: 78),
                const SizedBox(height: 15),
                Center(child: Text(
                  'جرّب كيف يطل المقوتي!',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                    color: c.petrol),
                )),
                const SizedBox(height: 8),
                Text(
                  'هذه معاينة مرئية داخل التطبيق فقط. '
                  'لم يُرسل أي SMS أو إشعار للهاتف، '
                  'ولم يُنشأ أي حجز أو دين.',
                  key: const Key('design_preview_disclaimer'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('preview_incoming_booking'),
                  onPressed: () => _simulate(booking: true),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('محاكاة وصول حجز جديد'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('preview_incoming_notification'),
                  onPressed: () => _simulate(booking: false),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('محاكاة وصول تنبيه جديد'),
                ),
                const SizedBox(height: 27),
                MaqwatiArrivalCard(
                  key: const Key('preview_booking_card'),
                  isNew: false,
                  category: 'شكل بطاقة الحجز',
                  title: 'تفاصيل حجز العميل',
                  message: 'تظهر هنا بيانات الحجز الموثقة بعد الربط بالخادم.',
                ),
                const SizedBox(height: 12),
                MaqwatiArrivalCard(
                  key: const Key('preview_notification_card'),
                  isNew: false,
                  category: 'شكل بطاقة التنبيه',
                  title: 'تنبيه من مقوتي لينك',
                  message: 'حركة الشخصية داخل التطبيق فقط، وليست حركة إشعار النظام.',
                ),
                const SizedBox(height: 18),
                Text(
                  'سيستخدم إشعار Android في الخلفية صورة ثابتة '
                  'للشخصية، ثم تبدأ الحركة عند فتح التطبيق '
                  'بعد إضافة خدمة الإشعارات الموثوقة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
