import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'store_discovery_ranking.dart';

/// Prepared for the future customer home. No private financial amounts
/// or customer names are exposed in public discovery cards.
class CustomerStoreDiscoverySections extends StatelessWidget {
  const CustomerStoreDiscoverySections({
    super.key,
    required this.standings,
    required this.storeNames,
    required this.onOpenStore,
  });

  final List<StoreDiscoveryStanding> standings;
  final Map<String, String> storeNames;
  final ValueChanged<String> onOpenStore;

  @override
  Widget build(BuildContext context) {
    final rated = StoreDiscoveryRanking.bestRated(standings);
    final requested = StoreDiscoveryRanking.mostRequested(standings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context, Icons.stars_outlined, 'الأفضل تقييماً',
          'تقييمات موثقة بعد موافقة العميل على تسجيل الدين',
          rated, ratedMode: true),
        const SizedBox(height: 17),
        _section(context, Icons.local_fire_department_outlined,
          'الأكثر طلباً',
          'نشاط العملاء ذوي الديون المعتمدة خلال آخر 30 يوماً',
          requested, ratedMode: false),
      ],
    );
  }

  Widget _section(BuildContext context,
      IconData icon, String title, String subtitle,
      List<StoreDiscoveryStanding> entries, {
      required bool ratedMode,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: c.petrol),
          const SizedBox(width: 7),
          Text(title, style: TextStyle(
            color: c.text, fontSize: 17, fontWeight: FontWeight.w900,
          )),
        ]),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: c.muted, fontSize: 11)),
        const SizedBox(height: 9),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.cardBorder),
            ),
            child: Text('لا توجد بيانات موثقة كافية للترتيب حالياً.',
              style: TextStyle(color: c.muted, fontSize: 12)),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final item = entries[index];
                return Material(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: Key('store_discovery_${ratedMode ? 'rating' : 'requested'}_${item.merchantId}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onOpenStore(item.merchantId),
                    child: Container(
                      width: 179,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.cardBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(storeNames[item.merchantId] ?? 'متجر',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.text,
                              fontWeight: FontWeight.w900, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            ratedMode
                                ? '★ ${item.reviews.average!.toStringAsFixed(1)} / 5'
                                : '${item.uniqueCustomers} عملاء',
                            style: TextStyle(color: c.petrol,
                              fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          const Spacer(),
                          Text(
                            ratedMode
                              ? '${item.reviews.publishedCount} تقييم معتمد'
                              : '${item.approvedDebtMovements} دين معتمد',
                            style: TextStyle(color: c.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
