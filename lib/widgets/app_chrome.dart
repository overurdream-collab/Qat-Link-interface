import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Fixed header shared by all merchant screens (RTL):
/// profile / greeting on the right; settings, notifications, night mode
/// on the left, matching the approved mobile preview.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.isDark,
    required this.onSettingsTap,
    required this.onNotificationsTap,
    required this.onThemeTap,
    this.accountName = 'حساب التاجر',
  });

  final bool isDark;
  final VoidCallback onSettingsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onThemeTap;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final greeting = DateTime.now().hour < 12 ? 'صباح الخير،' : 'مساء الخير،';
    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 16, 14, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.pale,
              shape: BoxShape.circle,
              border: Border.all(color: c.mint, width: 2),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/maqwati_approved_mascot.jpeg',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_rounded,
                color: c.petrol,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: TextStyle(
                  color: c.muted, fontSize: 12, fontWeight: FontWeight.w600,
                )),
                Text(
                  accountName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.petrol, fontSize: 18, fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          // In RTL visual order: notifications → theme → settings.
          AppSquareIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'التنبيهات',
            onTap: onNotificationsTap,
          ),
          const SizedBox(width: 5),
          AppSquareIconButton(
            icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            onTap: onThemeTap,
          ),
          const SizedBox(width: 5),
          AppSquareIconButton(
            icon: Icons.settings_rounded,
            tooltip: 'الضبط',
            onTap: onSettingsTap,
          ),
        ],
      ),
    );
  }
}

class AppSquareIconButton extends StatelessWidget {
  const AppSquareIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 35,
            height: 37,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.cardBorder),
            ),
            child: Icon(icon, size: 19, color: c.petrol),
          ),
        ),
      ),
    );
  }
}

/// The one official bottom navigation. Do not duplicate per screen.
/// Layout in RTL: الرئيسية / الحركة / circular + / العملاء / مساحتي.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 73,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.cardBorder)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, -7),
          ),
        ],
      ),
      child: Row(
        children: [
          _item(context, 0, 'الرئيسية', Icons.home_outlined),
          _item(context, 1, 'الحركة', Icons.history_rounded),
          Expanded(
            child: Center(
              child: Tooltip(
                message: 'إضافة سريعة',
                child: Material(
                  color: c.petrol,
                  elevation: 3,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      height: 53,
                      width: 53,
                      child: Icon(Icons.add_rounded, size: 31, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _item(context, 3, 'العملاء', Icons.people_outline_rounded),
          _item(context, 4, 'مساحتي', Icons.person_outline_rounded),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    int index,
    String label,
    IconData icon,
  ) {
    final c = context.colors;
    final active = selectedIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(
              color: active ? c.pale : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: active ? c.petrol : c.muted),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? c.petrol : c.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable section heading for incoming Movement/Customers screens.
class AppSectionTitle extends StatelessWidget {
  const AppSectionTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: c.petrol,
          )),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppSurface extends StatelessWidget {
  const AppSurface({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.cardBorder),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
