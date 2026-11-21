import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/customer_details_screen.dart';
import 'screens/customer_app_shell.dart';
import 'screens/login_screen.dart';
import 'screens/merchant_tabs.dart';
import 'services/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_chrome.dart';
import 'widgets/account_settings_sheet.dart';
import 'widgets/customers/customer_invitation_sheet.dart';
import 'widgets/quick_actions/quick_actions_sheet.dart';
import 'models/app_models.dart';
import 'models/merchant_pending_models.dart';
import 'features/auth/registration_role.dart';

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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  ThemeMode _themeMode = ThemeMode.light;
  bool _femaleProfile = false;

  bool get _pinkTheme => _femaleProfile;

  void _setProfileGender(ProfileGender gender) {
    setState(() {
      _femaleProfile = gender == ProfileGender.female;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'مقوتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(dark: false, pink: _pinkTheme),
      darkTheme: AppTheme.build(dark: true, pink: _pinkTheme),
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
        onGenderChanged: _setProfileGender,
        onOpenMerchantPreview: () => _navigatorKey.currentState?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => MerchantAppShell(
              isDark: _themeMode == ThemeMode.dark,
              onToggleTheme: () => setState(() {
                _themeMode = _themeMode == ThemeMode.dark
                    ? ThemeMode.light : ThemeMode.dark;
              }),
            ),
          ),
        ),
        onOpenCustomerPreview: () => _navigatorKey.currentState?.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CustomerAppShell(
              isDark: _themeMode == ThemeMode.dark,
              onToggleTheme: () => setState(() {
                _themeMode = _themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
              }),
            ),
          ),
        ),
        onToggleTheme: () => setState(() {
          _themeMode = _themeMode == ThemeMode.dark
              ? ThemeMode.light
              : ThemeMode.dark;
        }),
      ),
    );
  }
}

/// Merchant-only UI shell, reachable after future server authentication.
/// Never wire a PIN-only client-side navigation to this shell.
/// The only owner of top and bottom navigation across merchant pages.
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
    this.isFemale = false,
    this.isPinkTheme = false,
    this.onUseBaseTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  /// Verified merchant ID is required to select financial customers.
  /// Production obtains this from the authenticated server session.
  final String? merchantId;
  final List<VerifiedCustomerContactMatch> verifiedCustomerMatches;
  final List<VerifiedCustomerClaimDecision> verifiedClaimDecisions;
  final Set<String> verifiedTransferredClaimIds;
  final bool isFemale;
  final bool isPinkTheme;
  final VoidCallback? onUseBaseTheme;

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
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.card,
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('التنبيهات', style: TextStyle(
                fontSize: 18, color: c.petrol, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Text('لا توجد تنبيهات متصلة بالخادم حالياً.',
                  style: TextStyle(color: c.muted)),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    AccountSettingsSheet.open(
      context,
      accountName: 'حساب التاجر',
      roleLabel: 'التاجر',
      onChangeTheme: widget.onToggleTheme,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
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
                  HomeScreen(
                    state: _state,
                    onOpenMovements: () => setState(() => _selectedIndex = 1),
                  ),
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
    );
  }
}
