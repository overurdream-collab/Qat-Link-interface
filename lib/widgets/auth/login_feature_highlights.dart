import 'package:flutter/material.dart';

import '../../theme/premium_tokens.dart';

/// Four compact, informational feature highlights under the login form.
///
/// These are visual feature labels, not shortcuts into protected accounts.
/// All four follow the active blue/purple or feminine pink light/dark theme.
class LoginFeatureHighlights extends StatelessWidget {
  const LoginFeatureHighlights({super.key});

  static const double _iconSize = 23;
  static const double _tileHeight = 83;

  @override
  Widget build(BuildContext context) {
    final visual = context.premium;
    const features = <({String keyName, String label, IconData icon})>[
      (
        keyName: 'ledger',
        label: 'دفتر حسابات',
        icon: Icons.receipt_long_rounded
      ),
      (keyName: 'studio', label: 'استوديو', icon: Icons.movie_creation_rounded),
      (
        keyName: 'bookings',
        label: 'حجوزات',
        icon: Icons.event_available_rounded
      ),
      (
        keyName: 'insights',
        label: 'مؤشرات مالية',
        icon: Icons.trending_up_rounded
      ),
    ];

    return Semantics(
      container: true,
      label: 'مميزات مقوتي لينك: دفتر حسابات، استوديو، حجوزات، مؤشرات مالية',
      child: Row(
        key: const Key('login_feature_highlights'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < features.length; i++) ...[
            if (i != 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                key: Key('login_feature_${features[i].keyName}'),
                constraints: BoxConstraints(
                  minHeight:
                      _tileHeight * MediaQuery.textScalerOf(context).scale(1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                decoration: BoxDecoration(
                  color: visual.surface,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: visual.outline,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: visual.shadow,
                      offset: const Offset(0, 5),
                      blurRadius: 11,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      features[i].icon,
                      key: Key('login_feature_icon_${features[i].keyName}'),
                      color: visual.accent,
                      size: _iconSize,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      features[i].label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visual.ink,
                        fontSize: 10,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
