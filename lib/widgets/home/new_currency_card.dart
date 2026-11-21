import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/app_colors.dart';
import '../finance_display.dart';

/// Data supplied by the existing approved-only financial read model.
class CurrencyCardData {
  const CurrencyCardData({
    required this.currency,
    required this.debts,
    required this.payments,
    required this.pending,
    required this.collectionRate,
  });

  final CurrencyCode currency;
  final String debts;
  final String payments;
  final String pending;
  final double collectionRate;
}

/// Visual translation of the approved 220px card: gradient, circular meter,
/// separate approved-payment and pending figures.
class NewCurrencyCard extends StatelessWidget {
  const NewCurrencyCard({super.key, required this.data});

  final CurrencyCardData data;

  LinearGradient get _gradient => switch (data.currency) {
    CurrencyCode.yer => AppGradients.yer,
    CurrencyCode.sar => AppGradients.sar,
    CurrencyCode.usd => AppGradients.usd,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        gradient: _gradient,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: .65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.petrol.withValues(alpha: .22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Positioned(
              top: -137,
              left: -107,
              child: Container(
                height: 225, width: 225,
                decoration: const BoxDecoration(
                  color: Color(0x0AFFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -76,
              child: Container(
                height: 215, width: 215,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0x30FFFFFF),
                    width: 3,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(
                        FinanceDisplay.currencyName(data.currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          border: Border.all(color: Colors.white30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${FinanceDisplay.currencyCode(data.currency)} · ${FinanceDisplay.currencySymbol(data.currency)}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('إجمالي الديون المعتمدة', style: TextStyle(
                    fontSize: 11, color: Colors.white70,
                  )),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      data.debts,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniKpi(
                          icon: Icons.check_rounded,
                          label: 'المسدد المعتمد',
                          value: data.payments,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _MiniKpi(
                          icon: Icons.schedule_rounded,
                          label: 'المعلق',
                          value: data.pending,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 59,
              left: 5,
              child: SizedBox(
                width: 87,
                height: 87,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: data.collectionRate.isFinite
                            ? data.collectionRate.clamp(0.0, 1.0).toDouble()
                            : 0.0,
                        strokeWidth: 9,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFAEEBFF),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.collectionRate.isNaN
                              ? '—'
                              : '${(data.collectionRate * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text('نسبة التحصيل', style: TextStyle(
                          color: Colors.white, fontSize: 8,
                        )),
                      ],
                    ),
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

class _MiniKpi extends StatelessWidget {
  const _MiniKpi({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .21),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 12),
              const SizedBox(width: 3),
              Expanded(
                child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800,
            )),
          ),
        ],
      ),
    );
  }
}
