import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/customer_details_screen.dart';
import 'screens/login_screen.dart';
import 'screens/merchant_tabs.dart';
import 'services/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_chrome.dart';
import 'widgets/notifications/maqwati_notifications_sheet.dart';
import 'widgets/notifications/maqwati_incoming_notification_host.dart';
import 'widgets/auth/auth_brand_hero.dart';
import 'widgets/customers/customer_invitation_sheet.dart';
import 'widgets/quick_actions/quick_actions_sheet.dart';
import 'models/app_models.dart';
import 'models/merchant_pending_models.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QatLinkApp());
}

class QatLinkApp extends StatefulWidget {
  const QatLinkApp({super.key});

  @override
  State<QatLinkApp> createState() => _QatLinkAppState();
}

class _QatLinkAppState extends State<QatLinkApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مقوتي لينك',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: LoginScreen(
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// Merchant-only UI shell, reachable after future server authentication.\n/// Never wire a PIN-only client-side navigation to this shell.\n/// The only owner of top and bottom navigation across merchant pages.
/// The future MovementScreen should replace MerchantMovementsTab body only.
class MerchantAppShell extends StatefulWidget {
  const MerchantAppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.merchantId,
    this.verifiedCustomerMatches = const [],
    this.verifiedClaimDecisions = const [],
    this.verifiedTransferredClaimIds = const <String>{},
    this.incomingNotification,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  /// Verified merchant ID is required to select financial customers.
  /// Production obtains this from the authenticated server session.
  final String? merchantId;
  final List<VerifiedCustomerContactMatch> verifiedCustomerMatches;
  final List<VerifiedCustomerClaimDecision> verifiedClaimDecisions;
  final Set<String> verifiedTransferredClaimIds;
  /// An authenticated notification-stream event; null unless connected.
  final MaqwatiNotificationEvent? incomingNotification;

  @override
  State<MerchantAppShell> createState() => _MerchantAppShellState();
}

class _MerchantAppShellState extends State<MerchantAppShell> {
  final AppState _state = AppState();
  int _selectedIndex = 0;
  CustomerModel? _selectedCustomer;
  CurrencyCode _customerDetailCurrency = CurrencyCode.yer;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  Future<void> _showQuickAddSheet() async {
    final action = await showModalBottomSheet<QuickActionKind>(
      context: context,
      backgroundColor: context.colors.card,
      showDragHandle: true,
      builder: (_) => const QuickActionsSheet(),
    );
    if (!mounted || action == null) return;
    if (action == QuickActionKind.addCustomer) {
      await showCustomerInvitationSheet(
        context,
        state: _state,
        merchantId: widget.merchantId,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => MovementEntrySheet(
        state: _state,
        merchantId: widget.merchantId,
        type: action == QuickActionKind.addDebt
            ? MovementType.debt
            : MovementType.payment,
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: context.colors.card,
      builder: (_) => const MaqwatiNotificationsSheet(),
    );
  }

  void _showSettings() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MaqwatiBrandMark(height: 56),
              Align(
                alignment: Alignment.centerRight,
                child: Text('الضبط', style: TextStyle(
                  fontSize: 18, color: c.petrol, fontWeight: FontWeight.w800)),
              ),
              ListTile(
                leading: Icon(
                  widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: c.petrol,
                ),
                title: Text(widget.isDark ? 'الوضع النهاري' : 'الوضع الليلي'),
                onTap: () {
                  Navigator.pop(modalContext);
                  widget.onToggleTheme();
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: c.petrol),
                title: const Text('واجهة أولية — بيانات الحساب غير متصلة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MaqwatiIncomingNotificationHost(
      event: widget.incomingNotification,
      child: Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            AppTopBar(
              isDark: widget.isDark,
              onSettingsTap: _showSettings,
              onNotificationsTap: _showNotifications,
              onThemeTap: widget.onToggleTheme,
            ),
            Expanded(
              child: IndexedStack(
                index: switch (_selectedIndex) {
                  0 => 0,
                  1 => 1,
                  3 => 2,
                  4 => 3,
                  _ => 0,
                },
                children: [
                  HomeScreen(state: _state),
                  MerchantMovementsTab(state: _state),
                  _selectedCustomer == null
                      ? MerchantCustomersTab(
                          state: _state,
                          merchantId: widget.merchantId,
                          verifiedCustomerMatches: widget.verifiedCustomerMatches,
                          verifiedClaimDecisions: widget.verifiedClaimDecisions,
                          verifiedTransferredClaimIds:
                              widget.verifiedTransferredClaimIds,
                          onCustomerTap: (customer, currency) {
                            setState(() {
                              _selectedCustomer = customer;
                              _customerDetailCurrency = currency;
                            });
                          },
                        )
                      : CustomerDetailsScreen(
                          key: ValueKey('detail_${_selectedCustomer!.id}'),
                          customer: _selectedCustomer!,
                          state: _state,
                          merchantId: widget.merchantId,
                          initialCurrency: _customerDetailCurrency,
                          onBack: () => setState(() => _selectedCustomer = null),
                        ),
                  MerchantSpaceTab(state: _state, merchantId: widget.merchantId),
                ],
              ),
            ),
            AppBottomBar(
              selectedIndex: _selectedIndex,
              onSelect: (index) => setState(() {
                if (index != 3 || _selectedIndex == 3) {
                  _selectedCustomer = null;
                }
                _selectedIndex = index;
              }),
              onAdd: () { _showQuickAddSheet(); },
            ),
          ],
        ),
      ),
      ),
    );
  }
}