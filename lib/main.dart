import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/merchant_tabs.dart';
import 'services/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';
import 'widgets/app_chrome.dart';

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
      title: 'مقوتي لنك',
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
      home: MerchantAppShell(
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

/// The only owner of top and bottom navigation across merchant pages.
/// The future MovementScreen should replace MerchantMovementsTab body only.
class MerchantAppShell extends StatefulWidget {
  const MerchantAppShell({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<MerchantAppShell> createState() => _MerchantAppShellState();
}

class _MerchantAppShellState extends State<MerchantAppShell> {
  final AppState _state = AppState();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  void _showMessage(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title — يلزم ربط الحساب والموافقات قبل تفعيل هذه العملية.')),
    );
  }

  void _showQuickAddSheet() {
    final c = context.colors;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('إضافة سريعة', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: c.petrol)),
              const SizedBox(height: 8),
              for (final action in const <(String, String, IconData)>[
                ('إضافة عميل', 'يرسل طلب ارتباط للطرف الآخر', Icons.person_add_alt_1_rounded),
                ('إضافة دين', 'تحتاج موافقة الطرفين', Icons.add_card_rounded),
                ('تسجيل تسديد', 'تحتاج موافقة الطرفين', Icons.payments_rounded),
              ])
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: c.pale,
                    child: Icon(action.$3, color: c.petrol),
                  ),
                  title: Text(action.$1, style: TextStyle(color: c.text)),
                  subtitle: Text(action.$2, style: TextStyle(color: c.muted)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _showMessage(action.$1);
                  },
                ),
              const SizedBox(height: 10),
              Text('لا تُعتمد العمليات ولا تؤثر على الأرصدة قبل موافقة الطرفين.',
                  style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          ),
        ),
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
                  HomeScreen(state: _state),
                  MerchantMovementsTab(state: _state),
                  MerchantCustomersTab(state: _state),
                  const MerchantSpaceTab(),
                ],
              ),
            ),
            AppBottomBar(
              selectedIndex: _selectedIndex,
              onSelect: (index) => setState(() => _selectedIndex = index),
              onAdd: _showQuickAddSheet,
            ),
          ],
        ),
      ),
    );
  }
}
