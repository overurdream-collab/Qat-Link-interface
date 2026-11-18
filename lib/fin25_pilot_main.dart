import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/fin25_pilot_setup_screen.dart';
import 'theme/app_theme.dart';

/// Separate install identity and entry point for physical OTP acceptance.
/// No merchant shell, identity token, or financial navigation is reachable here.
void main() => runApp(const Fin25PilotApp());

class Fin25PilotApp extends StatelessWidget {
  const Fin25PilotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مقوتي لينك — اختبار الجوال',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Fin25PilotSetupScreen(),
      );
}
