import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qat_link/main.dart';
import 'package:qat_link/theme/app_theme.dart';

/// Financial-shell-only widget harness. Production QatLinkApp always starts
/// on LoginScreen; this keeps legacy financial widget tests independent of
/// the future authenticated backend.
class MerchantShellTestApp extends StatefulWidget {
  const MerchantShellTestApp({super.key});

  @override
  State<MerchantShellTestApp> createState() => _MerchantShellTestAppState();
}

class _MerchantShellTestAppState extends State<MerchantShellTestApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _mode,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MerchantAppShell(
          isDark: _mode == ThemeMode.dark,
          onToggleTheme: () => setState(() {
            _mode = _mode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light;
          }),
        ),
      );
}
