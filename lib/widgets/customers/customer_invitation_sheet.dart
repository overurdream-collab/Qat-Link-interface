import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/auth/auth_input_validation.dart';
import '../../models/merchant_pending_models.dart';
import '../../services/app_state.dart';
import '../../theme/app_colors.dart';

/// Shared merchant contact form; an unregistered customer can be noted locally.
/// This is not account registration, confirmed invitation delivery or a ledger debt.
class CustomerInvitationSheet extends StatefulWidget {
  const CustomerInvitationSheet({
    super.key,
    required this.state,
    this.merchantId,
  });

  final AppState state;
  final String? merchantId;

  @override
  State<CustomerInvitationSheet> createState() =>
      _CustomerInvitationSheetState();
}

class _CustomerInvitationSheetState extends State<CustomerInvitationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  // Search links are safe before the official store listings are published.
  // Replace them with direct listing URLs once the store IDs are assigned.
  static final Uri _playStoreUri = Uri.https(
    'play.google.com',
    '/store/search',
    {'q': 'Qat-Link', 'c': 'apps'},
  );
  static final Uri _appStoreUri = Uri.https(
    'apps.apple.com',
    '/search',
    {'term': 'Qat-Link'},
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final merchantId = widget.merchantId;
    if (merchantId == null || merchantId.trim().isEmpty) {
      _notice('هوية التاجر غير متاحة. لا يمكن حفظ بيانات خاصة '
          'دون جلسة تاجر موثقة.');
      return;
    }

    final name = _name.text.trim();
    final phone = AuthInputValidation.normalizePhone(_phone.text);
    try {
      final next = widget.state.merchantContacts.value.length + 1;
      widget.state.addMerchantContact(MerchantPendingContact(
        id: 'local-$merchantId-${DateTime.now().microsecondsSinceEpoch}-$next',
        merchantId: merchantId,
        name: name,
        phone: phone,
        createdAt: DateTime.now(),
      ));
      await _showDownloadInvite(name: name, phone: phone);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (_) {
      _notice('تعذر حفظ سجل العميل. تحقق من رقم الهاتف أو وجود '
          'هذا العميل مسبقاً ضمن سجلك.');
    }
  }

  Future<void> _showDownloadInvite({
    required String name,
    required String phone,
  }) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          title: Row(children: [
            Icon(Icons.qr_code_2_rounded, color: dialogContext.colors.petrol),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('شارك رابط تحميل التطبيق',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'امسح الرمز المناسب لهاتف العميل، أو أرسل له الدعوة عبر واتساب. '
                  'إضافة العميل لا تعني موافقته على الارتباط أو على أي دين.',
                  style: TextStyle(
                    color: dialogContext.colors.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _storeQr(
                      context: dialogContext,
                      title: 'Android',
                      storeName: 'Google Play',
                      uri: _playStoreUri,
                    ),
                    _storeQr(
                      context: dialogContext,
                      title: 'iPhone',
                      storeName: 'App Store',
                      uri: _appStoreUri,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dialogContext.colors.pendingBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dialogContext.colors.cardBorder),
                  ),
                  child: Text(
                    'روابط المتاجر حالياً روابط بحث عن Qat-Link. بعد نشر التطبيق '
                    'تُستبدل بروابط صفحة التطبيق الرسمية. تبقى بيانات العميل '
                    'محلية وغير متزامنة حتى ربط الخادم.',
                    style: TextStyle(
                      color: dialogContext.colors.text,
                      fontSize: 9,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('customer_invite_close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
            FilledButton.icon(
              key: const Key('customer_invite_whatsapp'),
              onPressed: () => _shareOnWhatsApp(name: name, phone: phone),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: const Text('إرسال عبر واتساب'),
            ),
          ],
        ),
      );

  Widget _storeQr({
    required BuildContext context,
    required String title,
    required String storeName,
    required Uri uri,
  }) {
    final c = context.colors;
    return Container(
      width: 118,
      padding: const EdgeInsets.fromLTRB(7, 9, 7, 7),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 3),
          Text(storeName, style: TextStyle(color: c.muted, fontSize: 9)),
          const SizedBox(height: 6),
          QrImageView(
            key: Key('customer_download_qr_$title'),
            data: uri.toString(),
            version: QrVersions.auto,
            size: 96,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF172B30),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF172B30),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareOnWhatsApp({
    required String name,
    required String phone,
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final message = 'مرحباً $name، حمّل تطبيق مقوتي لنك لمتابعة حسابك '
        'واستلام طلبات الارتباط والعمليات:\n'
        'Android (Google Play): $_playStoreUri\n'
        'iPhone (App Store): $_appStoreUri\n'
        'ستبقى الطلبات معلقة حتى تراجعها وتوافق عليها من التطبيق.';
    final whatsappUri = Uri.https(
      'wa.me',
      '/$digits',
      {'text': message},
    );
    try {
      final launched = await launchUrl(
        whatsappUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _notice('تعذر فتح واتساب. يمكنك مسح رمز QR أو مشاركة الرابط يدوياً.');
      }
    } on Object {
      if (mounted) {
        _notice('تعذر فتح واتساب. يمكنك مسح رمز QR أو مشاركة الرابط يدوياً.');
      }
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        19, 10, 19, MediaQuery.viewInsetsOf(context).bottom + 19,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      color: c.petrol, size: 22),
                  const SizedBox(width: 8),
                  Expanded(child: Text('إضافة عميل إلى سجلي', style: TextStyle(
                    color: c.text, fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ))),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: c.muted),
                  ),
                ]),
                const SizedBox(height: 9),
                Text(
                  'يمكنك تسجيل العميل في سجلك حتى قبل تحميله التطبيق. '
                  'سيبقى غير معتمد حتى يوافق على الارتباط، '
                  'وتظل المبالغ التي تسجلها له معلقة.',
                  style: TextStyle(color: c.muted, fontSize: 11),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  key: const Key('new_customer_name'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (text) =>
                    (text ?? '').trim().length < 3
                      ? 'أدخل اسم العميل' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('new_customer_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف العميل',
                    prefixIcon: Icon(Icons.phone_android_rounded),
                  ),
                  validator: AuthInputValidation.phone,
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: c.pale,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(11),
                  child: Text(
                    'بعد إضافة العميل يمكنك تسجيل مبالغ معلقة بشكل مستقل. '
                    'لا يثبت هذا موافقة العميل، ولا تدخل المبالغ '
                    'في الأرصدة المعتمدة حتى يوافق عليها.',
                    style: TextStyle(color: c.petrol, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('request_customer_link'),
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('إضافة العميل إلى سجلي',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 7),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One modal implementation for Customer and Quick Add entry points.
Future<void> showCustomerInvitationSheet(
  BuildContext context, {
  required AppState state,
  String? merchantId,
}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      showDragHandle: true,
      builder: (_) => CustomerInvitationSheet(
        state: state,
        merchantId: merchantId,
      ),
    );
