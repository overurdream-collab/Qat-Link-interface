import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'main.dart' show MerchantAppShell;
import 'screens/customer_app_shell.dart';
import 'theme/app_theme.dart';

/// Separate, offline-only UI design entrypoint.
/// Never use this entrypoint for authenticated production releases.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaqwatiUiPreview());
}

class MaqwatiUiPreview extends StatefulWidget {
  const MaqwatiUiPreview({super.key});

  @override
  State<MaqwatiUiPreview> createState() => _MaqwatiUiPreviewState();
}

class _MaqwatiUiPreviewState extends State<MaqwatiUiPreview> {
  bool _merchant = true;
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
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('تاجر'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('عميل'),
                            ),
                          ],
                          selected: {_merchant},
                          onSelectionChanged: (value) {
                            setState(() => _merchant = value.first);
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
                child: _merchant
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
