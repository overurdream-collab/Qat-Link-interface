import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../theme/premium_tokens.dart';
import '../finance_display.dart';

/// Data supplied by the existing approved-only financial read model.
class CurrencyCardData {
  const CurrencyCardData({
    required this.currency,
    required this.debts,
    this.balance,
    this.isCredit = false,
    required this.payments,
    required this.pending,
    required this.collectionRate,
  });

  final CurrencyCode currency;
  final String debts;

  /// Approved debts minus approved payments. Null preserves legacy callers.
  final String? balance;
  final bool isCredit;
  final String payments;
  final String pending;
  final double collectionRate;
}

/// Visual translation of the approved 220px card: gradient, circular meter,
/// separate approved-payment and pending figures.
class NewCurrencyCard extends StatelessWidget {
  const NewCurrencyCard({super.key, required this.data});

  final CurrencyCardData data;

  LinearGradient _gradient(BuildContext context) =>
      context.premium.forWhiteText(switch (data.currency) {
        CurrencyCode.yer => context.premium.yer,
        CurrencyCode.sar => context.premium.sar,
        CurrencyCode.usd => context.premium.usd,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220 * MediaQuery.textScalerOf(context).scale(1),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 17),
      decoration: BoxDecoration(
        gradient: _gradient(context),
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: Colors.white.withValues(alpha: .65), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: context.premium.shadow,
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(FinanceDisplay.currencyName(data.currency),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
            const SizedBox(width: 6),
            Text(FinanceDisplay.currencyCode(data.currency),
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      data.balance == null
                          ? 'إجمالي الديون المعتمدة'
                          : data.isCredit
                              ? 'رصيد دائن لصالح العميل'
                              : 'صافي الرصيد المعتمد',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white)),
                  // Keep every digit readable and available on narrow cards.
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(data.balance ?? data.debts,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              height: 1.5,
                              fontWeight: FontWeight.w900))),
                ])),
            const SizedBox(width: 10),
            SizedBox(
                width: 68,
                height: 68,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                      child: CircularProgressIndicator(
                          value: data.collectionRate.isFinite
                              ? data.collectionRate.clamp(0.0, 1.0)
                              : 0,
                          strokeWidth: 7,
                          backgroundColor: Colors.white30,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white))),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        data.collectionRate.isFinite
                            ? '${(data.collectionRate * 100).round()}%'
                            : '—',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    const Text('نسبة التحصيل',
                        style: TextStyle(color: Colors.white, fontSize: 8)),
                  ]),
                ])),
          ]),
          const Spacer(),
          Row(children: [
            Expanded(
                child: _MiniKpi(
                    icon: Icons.check_rounded,
                    label: 'المسدد المعتمد',
                    value: data.payments)),
            const SizedBox(width: 9),
            Expanded(
                child: _MiniKpi(
                    icon: Icons.schedule_rounded,
                    label: 'المعلق',
                    value: data.pending)),
          ]),
        ],
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
        color: Colors.black.withValues(alpha: .1),
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
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      ),
    );
  }
}
