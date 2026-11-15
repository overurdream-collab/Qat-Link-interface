import 'package:flutter/material.dart';

import '../../features/auth/auth_input_validation.dart';
import '../../models/app_models.dart';
import '../../models/merchant_pending_models.dart';
import '../../services/app_state.dart';
import '../../theme/app_colors.dart';
import '../movement/movement_view_model.dart';

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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _send() {
    if (!_formKey.currentState!.validate()) return;
    final merchantId = widget.merchantId;
    if (merchantId == null || merchantId.trim().isEmpty) {
      _notice('هوية التاجر غير متاحة. لا يمكن حفظ بيانات خاصة '
          'دون جلسة تاجر موثقة.');
      return;
    }
    final phone = AuthInputValidation.normalizePhone(_phone.text);
    try {
      final next = widget.state.merchantContacts.value.length + 1;
      widget.state.addMerchantContact(MerchantPendingContact(
        id: 'local-$merchantId-${DateTime.now().microsecondsSinceEpoch}-$next',
        merchantId: merchantId,
        name: _name.text.trim(),
        phone: phone,
        createdAt: DateTime.now(),
      ));
      _notice('أُضيف العميل إلى سجل التاجر المحلي بحالة غير معتمد. '
          'يمكن تسجيل مبالغ معلقة عليه، ولا تُحتسب ديوناً معتمدة. '
          'الإرسال والاحتفاظ الدائم ينتظران ربط الخادم.');
      Navigator.of(context).pop();
    } on Object catch (_) {
      _notice('تعذر حفظ سجل العميل. تحقق من رقم الهاتف أو وجود '
          'هذا العميل مسبقاً ضمن سجلك.');
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
