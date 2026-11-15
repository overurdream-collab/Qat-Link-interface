import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/auth_input_validation.dart';
import '../../models/app_models.dart';
import '../../services/app_state.dart';
import '../../theme/app_colors.dart';
import '../finance_display.dart';
import 'approved_customer_picker_model.dart';
import '../movement/movement_view_model.dart';

enum QuickActionKind { addCustomer, addDebt, addAmount }

/// The same three-action menu is used by the shared (+) bottom button.
class QuickActionsSheet extends StatelessWidget {
  const QuickActionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entries = <(QuickActionKind, String, IconData, Color)>[
      (QuickActionKind.addCustomer, 'إضافة عميل',
          Icons.person_add_alt_1_rounded, AppColors.success),
      (QuickActionKind.addDebt, 'إضافة دين',
          Icons.receipt_long_rounded, const Color(0xFFD99113)),
      (QuickActionKind.addAmount, 'إضافة مبلغ',
          Icons.account_balance_wallet_rounded, AppColors.sea),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 27),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الإضافة السريعة',
                    style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w900,
                      color: c.petrol,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: c.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      key: Key('quick_action_${entries[i].$1.name}'),
                      onTap: () => Navigator.of(context).pop(entries[i].$1),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          children: [
                            Container(
                              width: 62, height: 62,
                              decoration: BoxDecoration(
                                color: entries[i].$4.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(17),
                                border: Border.all(
                                  color: entries[i].$4.withValues(alpha: .26),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(entries[i].$3,
                                  color: entries[i].$4, size: 28),
                            ),
                            const SizedBox(height: 9),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(entries[i].$2,
                                style: TextStyle(
                                  color: c.petrol, fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single form for debt and payment. The selected customer MUST be a
/// member of the merchant's approved list; no manual free-text customer.
class MovementEntrySheet extends StatefulWidget {
  const MovementEntrySheet({
    super.key,
    required this.state,
    required this.type,
    this.merchantId,
  });

  final AppState state;
  final MovementType type;
  final String? merchantId;

  @override
  State<MovementEntrySheet> createState() => _MovementEntrySheetState();
}

class _MovementEntrySheetState extends State<MovementEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  CurrencyCode _currency = CurrencyCode.yer;
  ApprovedCustomerOption? _selection;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool get _isDebt => widget.type == MovementType.debt;

  String? _validateAmount(String? raw) {
    final clean = AuthInputValidation.normalizeDigits(raw ?? '')
        .replaceAll('٫', '.')
        .trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(clean)) {
      return 'أدخل مبلغاً صحيحاً، بمنزلتين عشريتين كحد أقصى';
    }
    if (Decimal.parse(clean) <= Decimal.zero) {
      return 'يجب أن يكون المبلغ أكبر من صفر';
    }
    return null;
  }

  Future<void> _chooseCustomer(FormFieldState<ApprovedCustomerOption> field) async {
    final options = ApprovedCustomerPickerModel.available(
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      merchantId: widget.merchantId,
    );
    final selected = await showModalBottomSheet<ApprovedCustomerOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.colors.card,
      isScrollControlled: true,
      builder: (sheetContext) => _ApprovedCustomerSearch(
        options: options,
      ),
    );
    if (!mounted || selected == null) return;
    field.didChange(selected);
    setState(() {
      _selection = selected;
      _currency = selected.customer.primaryCurrency;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final eligible = ApprovedCustomerPickerModel.isStillEligible(
      selection: _selection,
      customers: widget.state.customers.value,
      relationships: widget.state.relationships.value,
      merchantId: widget.merchantId,
    );
    if (!eligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'لم تعد العلاقة معتمدة أو لا تتوفر هوية تاجر موثقة. '
          'اختر عميلاً مرتبطاً بصورة صحيحة.',
        )),
      );
      return;
    }
    // Never treat a locally completed form as authenticated financial write.
    // Production must call an authorized API with customerId, relationshipId,
    // exact Decimal amount and currency, then await server confirmation.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(
        'تم التحقق من بيانات النموذج، لكن لم تُحفظ العملية. '
        'الحفظ الفعلي ينتظر ربط المصادقة والخادم والموافقة الثنائية.',
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.state.customers,
        widget.state.relationships,
      ]),
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          18, 8, 18, MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('تسجيل حركة جديدة', style: TextStyle(
                          color: c.petrol,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        )),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: c.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('نوع العملية', style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  InputDecorator(
                    decoration: const InputDecoration(isDense: true),
                    child: Text(
                      _isDebt ? 'تسجيل دين جديد (آجل)' : 'إضافة مبلغ (تسديد)',
                      style: TextStyle(color: c.text, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('اختر العميل من قائمتك', style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  FormField<ApprovedCustomerOption>(
                    key: const Key('movement_customer_field'),
                    validator: (selected) {
                      if (selected == null) return 'اختيار العميل مطلوب';
                      if (!ApprovedCustomerPickerModel.isStillEligible(
                        selection: selected,
                        customers: widget.state.customers.value,
                        relationships: widget.state.relationships.value,
                        merchantId: widget.merchantId,
                      )) {
                        return 'العميل غير مرتبط بعلاقة معتمدة حالياً';
                      }
                      return null;
                    },
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          color: c.card,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: const Key('movement_select_customer'),
                            onTap: () => _chooseCustomer(field),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: field.hasError
                                    ? c.danger : c.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Icon(Icons.people_outline_rounded,
                                    color: c.petrol, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    field.value?.customer.name ??
                                        'اختر عميلاً مرتبطاً',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: field.value == null
                                          ? c.muted : c.text,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Icon(Icons.expand_more_rounded, color: c.muted),
                              ]),
                            ),
                          ),
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                                start: 9, top: 5),
                            child: Text(field.errorText!,
                              style: TextStyle(color: c.danger, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text('المبلغ والعملة', style: TextStyle(
                    color: c.petrol, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          key: const Key('movement_amount'),
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(22),
                          ],
                          decoration: const InputDecoration(
                            hintText: '0.00',
                          ),
                          validator: _validateAmount,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: DropdownButtonFormField<CurrencyCode>(
                          key: ValueKey('movement_currency_${_selection?.customer.id ?? 'none'}'),
                          value: _currency,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 9, vertical: 14),
                          ),
                          items: [
                            for (final currency in CurrencyCode.values)
                              DropdownMenuItem(
                                value: currency,
                                child: Text(FinanceDisplay.currencyCode(currency),
                                  style: const TextStyle(fontSize: 12)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _currency = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: c.pale,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      _isDebt
                          ? 'الدين يزيد المديونية بعد موافقة الطرفين فقط.'
                          : 'المبلغ المسدد يخفض المديونية بعد موافقة الطرفين فقط، '
                              'وقد يصبح الرصيد دائناً للعميل.',
                      style: TextStyle(
                        color: c.petrol, fontSize: 11, height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.assistant,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: FilledButton(
                      key: const Key('movement_save'),
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(49),
                      ),
                      child: const Text('حفظ العملية', style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w900,
                      )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApprovedCustomerSearch extends StatefulWidget {
  const _ApprovedCustomerSearch({required this.options});

  final List<ApprovedCustomerOption> options;

  @override
  State<_ApprovedCustomerSearch> createState() => _ApprovedCustomerSearchState();
}

class _ApprovedCustomerSearchState extends State<_ApprovedCustomerSearch> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = MovementQuery.normalizeSearch(
        AuthInputValidation.normalizeDigits(_search.text));
    final filtered = widget.options.where((item) {
      final name = MovementQuery.normalizeSearch(item.customer.name);
      final phone = MovementQuery.normalizeSearch(
          AuthInputValidation.normalizeDigits(item.customer.phone));
      return query.isEmpty ||
          name.contains(query) ||
          phone.contains(query);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 9, 16, MediaQuery.viewInsetsOf(context).bottom + 15,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .52,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('اختيار عميل', style: TextStyle(
                color: c.petrol, fontWeight: FontWeight.w900,
                fontSize: 18,
              )),
              const SizedBox(height: 4),
              Text('العملاء المرتبطون والمعتمدون فقط',
                  style: TextStyle(color: c.muted, fontSize: 11)),
              const SizedBox(height: 10),
              TextField(
                key: const Key('customer_picker_search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو رقم الجوال',
                  prefixIcon: Icon(Icons.search_rounded, color: c.muted),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(
                        'لا يوجد عملاء مرتبطون مطابقون للبحث. '
                        'يجب اعتماد الارتباط أولاً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 12),
                      ))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            Divider(color: c.cardBorder, height: 1),
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            key: Key('picker_customer_${option.customer.id}'),
                            leading: CircleAvatar(
                              backgroundColor: c.pale,
                              child: Icon(Icons.person_rounded,
                                  color: c.petrol),
                            ),
                            title: Text(option.customer.name,
                                style: TextStyle(color: c.text,
                                    fontWeight: FontWeight.w800)),
                            subtitle: Text(option.customer.phone,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(color: c.muted,
                                    fontSize: 11)),
                            trailing: Icon(Icons.chevron_left_rounded,
                                color: c.petrol),
                            onTap: () =>
                                Navigator.of(context).pop(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
