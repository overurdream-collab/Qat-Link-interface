import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/app_state.dart';
import '../services/movement_calculator.dart';
import '../theme/app_colors.dart';

/// RTL visual foundation for the merchant experience.
/// All figures are calculated from real AppState movements; none are seeded
/// with fictional balances. Write actions remain intentionally disabled
/// until authenticated participant workflows are connected.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AppState _state = AppState();
  CurrencyCode _currency = CurrencyCode.yer;
  MovementStatus? _movementStatusFilter;
  int _tab = 0;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  String get _currencyName => switch (_currency) {
        CurrencyCode.yer => 'الريال اليمني',
        CurrencyCode.sar => 'الريال السعودي',
        CurrencyCode.usd => 'الدولار الأمريكي',
      };

  String get _unit => switch (_currency) {
        CurrencyCode.yer => 'ر.ي',
        CurrencyCode.sar => 'ر.س',
        CurrencyCode.usd => 'USD',
      };

  String _amount(Decimal value) {
    final raw = value.toString();
    final parts = raw.split('.');
    final sign = parts.first.startsWith('-') ? '-' : '';
    final whole = sign.isEmpty ? parts.first : parts.first.substring(1);
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(',');
      buffer.write(whole[i]);
    }
    final fraction = parts.length > 1 ? '.${parts[1]}' : '';
    return '$sign${buffer.toString()}$fraction';
  }

  void _showNotConnected(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action: هذه معاينة للتصميم فقط. الربط المالي يحتاج جلسة موثقة وموافقة الطرف الآخر.'),
      ),
    );
  }

  void _showQuickActions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إضافة سريعة', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              for (final item in const [
                ('إضافة عميل / طلب ارتباط', Icons.person_add_alt_1_rounded),
                ('إضافة دين', Icons.add_card_rounded),
                ('تسجيل تسديد', Icons.payments_outlined),
              ])
                ListTile(
                  leading: Icon(item.$2, color: AppColors.button),
                  title: Text(item.$1),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showNotConnected(item.$1);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_state.movements, _state.customers, _state.relationships]),
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.section,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: IndexedStack(
                  index: _tab == 2 ? 0 : _tab,
                  children: [
                    _buildHome(),
                    _buildMovements(),
                    const SizedBox.shrink(),
                    _buildCustomers(),
                    _buildStore(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavigation(),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: AppGradients.balance,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_graph_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مقوتي لنك', style: TextStyle(
                  color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('إدارة الديون والتحصيل بذكاء',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'التنبيهات',
            onPressed: () => _showNotConnected('التنبيهات'),
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.navy),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () => _showNotConnected('الإعدادات'),
            icon: const Icon(Icons.tune_rounded, color: AppColors.navy),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    final movements = _state.movements.value;
    final approvedDebts = MovementCalculator.approvedDebts(
        movements, currency: _currency);
    final approvedPayments = MovementCalculator.approvedPayments(
        movements, currency: _currency);
    final pending = MovementCalculator.pendingTotal(
        movements, currency: _currency);
    final net = approvedDebts - approvedPayments;
    final debtNumber = double.tryParse(approvedDebts.toString()) ?? 0;
    final paymentsNumber = double.tryParse(approvedPayments.toString()) ?? 0;
    final progress = debtNumber > 0
        ? (paymentsNumber / debtNumber).clamp(0.0, 1.0)
        : 0.0;
    final pendingMovements = _state.pendingMovements
        .where((m) => m.currency == _currency).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      children: [
        _designPreviewNote(),
        const SizedBox(height: 14),
        _buildAdBanner(),
        const SizedBox(height: 22),
        _sectionTitle('ملخص المديونية', trailing: 'لكل عملة بشكل مستقل'),
        const SizedBox(height: 12),
        _currencySelector(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.balance,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
              color: AppColors.blue.withValues(alpha: .14),
              blurRadius: 24, offset: const Offset(0, 10),
            )],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_currencyName, style: const TextStyle(
                fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 10),
              const Text('صافي المديونية المعتمدة', style: TextStyle(
                color: Colors.white, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${_amount(net)}  $_unit', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 29, height: 1.4)),
              const SizedBox(height: 15),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 8,
                            backgroundColor: Colors.white30,
                            valueColor: const AlwaysStoppedAnimation(AppColors.lime),
                          ),
                        ),
                        Text(debtNumber > 0 ? '${(progress * 100).round()}%' : '—',
                            style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _onGradientMetric('الديون المعتمدة', _amount(approvedDebts)),
                        const SizedBox(height: 9),
                        _onGradientMetric('التسديدات المعتمدة', _amount(approvedPayments)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _smallMetric('العمليات المعلقة', _amount(pending),
                Icons.schedule_rounded, AppColors.lime)),
            const SizedBox(width: 10),
            Expanded(child: _smallMetric('عدد العملاء',
                _state.customers.value.length.toString(),
                Icons.people_alt_outlined, AppColors.mint)),
          ],
        ),
        const SizedBox(height: 22),
        _sectionTitle('إجراءات سريعة'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _quickButton('إضافة عميل', Icons.person_add_alt_1_rounded)),
            const SizedBox(width: 9),
            Expanded(child: _quickButton('إضافة دين', Icons.add_card_rounded)),
            const SizedBox(width: 9),
            Expanded(child: _quickButton('تسديد', Icons.payments_rounded)),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('طلبات بانتظار الموافقة',
            trailing: '${pendingMovements.length} معروضة'),
        const SizedBox(height: 11),
        if (pendingMovements.isEmpty)
          _emptyCard('لا توجد طلبات معلقة لهذه العملة.', Icons.task_alt_rounded)
        else
          for (final movement in pendingMovements) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _movementRow(movement),
          ),
        const SizedBox(height: 22),
        _sectionTitle('مساعد التاجر المالي'),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.mint,
                child: Icon(Icons.insights_rounded, color: AppColors.button),
              ),
              SizedBox(width: 12),
              Expanded(child: Text(
                'ستظهر التحليلات والمخاطر عند توفر حركات مالية معتمدة.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdBanner() => Container(
    height: 105,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    decoration: BoxDecoration(
      gradient: AppGradients.header,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('إعلانات التجار', style: TextStyle(
              color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 15)),
            SizedBox(height: 5),
            Text('مساحة الإعلان المخصصة للتاجر — معاينة',
                style: TextStyle(color: AppColors.navy, fontSize: 11)),
          ],
        )),
        const Icon(Icons.storefront_rounded, size: 50, color: AppColors.blue),
      ],
    ),
  );

  Widget _designPreviewNote() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.background),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.button),
        SizedBox(width: 8),
        Expanded(child: Text('معاينة واجهة — لا توجد بيانات مالية محملة',
          style: TextStyle(fontSize: 10, color: AppColors.inkSoft))),
      ],
    ),
  );

  Widget _currencySelector() => Row(
    children: [
      for (final currency in CurrencyCode.values) Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 7),
          child: ChoiceChip(
            label: SizedBox(
              width: double.infinity,
              child: Text(currency.name.toUpperCase(), textAlign: TextAlign.center),
            ),
            selected: currency == _currency,
            onSelected: (_) => setState(() => _currency = currency),
            selectedColor: AppColors.blue,
            backgroundColor: AppColors.surface,
            labelStyle: TextStyle(
              color: currency == _currency ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700, fontSize: 12,
            ),
            side: BorderSide.none,
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
      ),
    ],
  );

  Widget _sectionTitle(String title, {String? trailing}) => Row(
    children: [
      Expanded(child: Text(title, style: const TextStyle(
        color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: 16))),
      if (trailing != null) Text(trailing, style: const TextStyle(
        color: AppColors.inkSoft, fontSize: 10)),
    ],
  );

  Widget _onGradientMetric(String title, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: Text(title, style: const TextStyle(
        color: Colors.white70, fontSize: 10))),
      Text(value, style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
    ],
  );

  Widget _smallMetric(String title, String value, IconData icon, Color tint) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16, backgroundColor: tint,
              child: Icon(icon, size: 18, color: AppColors.button),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(
              color: AppColors.inkSoft, fontSize: 11)),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(
              color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _quickButton(String label, IconData icon) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      borderRadius: BorderRadius.circular(17),
      onTap: () => _showNotConnected(label),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 5),
        child: Column(
          children: [
            Icon(icon, color: AppColors.button, size: 24),
            const SizedBox(height: 7),
            Text(label, style: const TextStyle(
              color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ),
      ),
    ),
  );

  Widget _emptyCard(String label, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.blueMid),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(
          color: AppColors.inkSoft, fontSize: 12))),
      ],
    ),
  );

  Widget _movementRow(MovementModel movement) {
    final isDebt = movement.type == MovementType.debt;
    final status = movement.status;
    final statusLabel = switch (status) {
      MovementStatus.approved => 'معتمد',
      MovementStatus.pending => 'معلق',
      MovementStatus.rejected => 'مرفوض',
    };
    final color = switch (status) {
      MovementStatus.approved => AppColors.success,
      MovementStatus.pending => AppColors.warning,
      MovementStatus.rejected => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.mint,
            child: Icon(isDebt ? Icons.trending_up_rounded :
              Icons.trending_down_rounded, color: AppColors.button),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isDebt ? 'دين — ${_customerName(movement.customerId)}' :
                  'تسديد — ${_customerName(movement.customerId)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.navy,
                  fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 3),
              Text(statusLabel, style: TextStyle(color: color, fontSize: 10)),
            ],
          )),
          Text('${_amount(movement.amount)} $_unit', style: const TextStyle(
            fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 12)),
        ],
      ),
    );
  }

  String _customerName(String id) {
    for (final customer in _state.customers.value) {
      if (customer.id == id) return customer.name;
    }
    return 'عميل $id';
  }

  Widget _buildMovements() {
    final rows = _state.movements.value
      .where((m) => m.currency == _currency &&
        (_movementStatusFilter == null || m.status == _movementStatusFilter))
      .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _sectionTitle('سجل الحركة'),
        const SizedBox(height: 12),
        _currencySelector(),
        const SizedBox(height: 10),
        Wrap(spacing: 7, children: [
          for (final entry in <(MovementStatus?, String)>[
            (null, 'الكل'),
            (MovementStatus.approved, 'معتمد'),
            (MovementStatus.pending, 'معلق'),
            (MovementStatus.rejected, 'مرفوض'),
          ]) ChoiceChip(
            label: Text(entry.$2),
            selected: _movementStatusFilter == entry.$1,
            onSelected: (_) => setState(() => _movementStatusFilter = entry.$1),
          ),
        ]),
        const SizedBox(height: 15),
        if (rows.isEmpty) _emptyCard('لا توجد حركات في هذا التصنيف.',
            Icons.receipt_long_rounded)
        else for (final movement in rows) Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _movementRow(movement),
        ),
      ],
    );
  }

  Widget _buildCustomers() {
    final customers = [..._state.customers.value]
      ..sort((a, b) => MovementCalculator.customerBalance(
         _state.movements.value, customerId: b.id, currency: _currency)
         .compareTo(MovementCalculator.customerBalance(
         _state.movements.value, customerId: a.id, currency: _currency)));
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _sectionTitle('العملاء'),
        const SizedBox(height: 12),
        _currencySelector(),
        const SizedBox(height: 15),
        if (customers.isEmpty)
          _emptyCard('لا توجد علاقات عملاء محملة.',
              Icons.people_outline_rounded)
        else for (final customer in customers) Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: AppColors.mint,
                  child: Icon(Icons.person_outline_rounded, color: AppColors.blue)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.navy)),
                    Text(customer.phone, style: const TextStyle(
                      fontSize: 11, color: AppColors.inkSoft)),
                  ],
                )),
                Text('${_amount(MovementCalculator.customerBalance(
                   _state.movements.value, customerId: customer.id,
                   currency: _currency))} $_unit',
                    style: const TextStyle(fontSize: 11, color: AppColors.navy,
                      fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStore() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      _sectionTitle('متجري'),
      const SizedBox(height: 15),
      Container(
        height: 165,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: AppGradients.header,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, size: 37, color: AppColors.blue),
            SizedBox(height: 10),
            Text('متجري', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
            Text('واجهة المتجر والعروض ستُربط في مرحلتها المعتمدة.',
                style: TextStyle(fontSize: 11, color: AppColors.navy)),
          ],
        ),
      ),
    ],
  );

  Widget _buildBottomNavigation() {
    final items = <(String, IconData, int)>[
      ('الرئيسية', Icons.home_rounded, 0),
      ('الحركة', Icons.history_rounded, 1),
      ('', Icons.add_rounded, 2),
      ('العملاء', Icons.people_alt_outlined, 3),
      ('متجري', Icons.storefront_outlined, 4),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 5, 12, 9),
        height: 69,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(
            color: AppColors.navy.withValues(alpha: .045),
            blurRadius: 16, offset: const Offset(0, 4),
          )],
        ),
        child: Row(
          children: [
            for (final item in items) Expanded(
              child: item.$3 == 2
                ? Center(child: IconButton.filled(
                    tooltip: 'إضافة سريعة',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.button,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(47, 47),
                    ),
                    onPressed: _showQuickActions,
                    icon: const Icon(Icons.add_rounded, size: 28),
                  ))
                : InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => setState(() => _tab = item.$3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.$2,
                          size: 23,
                          color: _tab == item.$3 ? AppColors.button : AppColors.muted),
                        const SizedBox(height: 4),
                        Text(item.$1, style: TextStyle(
                          fontSize: 10,
                          fontWeight: _tab == item.$3
                            ? FontWeight.w800 : FontWeight.w500,
                          color: _tab == item.$3
                            ? AppColors.button : AppColors.inkSoft,
                        )),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
