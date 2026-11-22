import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/auth/registration_role.dart';
import 'main.dart' show MerchantAppShell;
import 'screens/customer_app_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

/// Phone-facing, offline VISUAL preview. Unlike the QA-only preview, its
/// initial screen has no tester navigation bar and no mock-session footer.
/// Never use this entrypoint for actual authenticated financial transactions.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaqwatiPhonePreview());
}

class MaqwatiPhonePreview extends StatefulWidget {
  const MaqwatiPhonePreview({super.key});

  @override
  State<MaqwatiPhonePreview> createState() => _MaqwatiPhonePreviewState();
}

class _MaqwatiPhonePreviewState extends State<MaqwatiPhonePreview> {
  bool _pink = false;
  bool _dark = false;
  int _view = 0; // 0 login, 1 merchant, 2 customer.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مقوتي لينك',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(dark: false, pink: _pink),
      darkTheme: AppTheme.build(dark: true, pink: _pink),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _view == 0
          ? LoginScreen(
              isDark: _dark,
              onToggleTheme: () => setState(() => _dark = !_dark),
              onGenderChanged: (ProfileGender value) => setState(
                () => _pink = value == ProfileGender.female,
              ),
              onOpenCustomerPreview: () => setState(() => _view = 2),
              onOpenMerchantPreview: () => setState(() => _view = 1),
              showPreviewLinks: false,
            )
          : Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    Material(
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('phone_preview_back_to_login'),
                            tooltip: 'العودة إلى تسجيل الدخول',
                            onPressed: () => setState(() => _view = 0),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          Expanded(
                            child: Text(
                              _view == 1 ? 'معاينة التاجر' : 'معاينة العميل',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _view == 1
                          ? MerchantAppShell(
                              isDark: _dark,
                              onToggleTheme: () =>
                                  setState(() => _dark = !_dark),
                              isFemale: _pink,
                              isPinkTheme: _pink,
                            )
                          : CustomerAppShell(
                              isDark: _dark,
                              onToggleTheme: () =>
                                  setState(() => _dark = !_dark),
                            ),
                    ),
                    const Text(
                      'معاينة بصرية دون اتصال بالخادم أو بيانات مالية حقيقية',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
