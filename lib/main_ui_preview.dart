import 'package:flutter/material.dart';
import 'services/app_incident_recorder.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main.dart' show MerchantAppShell;
import 'screens/customer_app_shell.dart';
import 'screens/login_screen.dart';
import 'features/auth/registration_role.dart';
import 'theme/app_theme.dart';

/// Separate, offline-only UI design entrypoint.
/// Never use this entrypoint for authenticated production releases.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppIncidentRecorder.install();
  runApp(const MaqwatiUiPreview());
}

class MaqwatiUiPreview extends StatefulWidget {
  const MaqwatiUiPreview({super.key});

  @override
  State<MaqwatiUiPreview> createState() => _MaqwatiUiPreviewState();
}

class _MaqwatiUiPreviewState extends State<MaqwatiUiPreview> {
  int _view = 0; // 0: Login, 1: Merchant, 2: Customer
  bool _female = false;
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مقوتي لينك — معاينة التصميم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.build(dark: false, pink: _female),
      darkTheme: AppTheme.build(dark: true, pink: _female),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Material(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<int>(
                              value: 0,
                              label: Text('دخول'),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              label: Text('تاجر'),
                            ),
                            ButtonSegment<int>(
                              value: 2,
                              label: Text('عميل'),
                            ),
                          ],
                          selected: {_view},
                          onSelectionChanged: (value) {
                            setState(() => _view = value.first);
                          },
                        ),
                      ),
                      IconButton(
                        key: const Key('preview_female_theme'),
                        tooltip: _female ? 'الثيم الأساسي' : 'الثيم الوردي',
                        onPressed: () => setState(() => _female = !_female),
                        icon: Icon(
                          _female ? Icons.palette_rounded : Icons.favorite_border,
                        ),
                      ),
                      IconButton(
                        key: const Key('preview_night_theme'),
                        tooltip: _dark ? 'الوضع النهاري' : 'الوضع الليلي',
                        onPressed: () => setState(() => _dark = !_dark),
                        icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                // Only mount the selected role. No verified merchant/customer
                // identity, auth token, or live gateway is ever supplied.
                child: _view == 0
                    ? LoginScreen(
                        isDark: _dark,
                        onToggleTheme: () => setState(() => _dark = !_dark),
                        onGenderChanged: (ProfileGender gender) => setState(
                          () => _female = gender == ProfileGender.female,
                        ),
                        onOpenCustomerPreview: () => setState(() => _view = 2),
                      )
                    : _view == 1
                    ? MerchantAppShell(
                        isDark: _dark,
                        onToggleTheme: () => setState(() => _dark = !_dark),
                        isFemale: _female,
                        isPinkTheme: _female,
                      )
                    : CustomerAppShell(
                        isDark: _dark,
                        onToggleTheme: () => setState(() => _dark = !_dark),
                      ),
              ),
              const Material(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      'معاينة تصميم فقط — لا حساب مالي متصل',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
