import 'package:flutter/material.dart';
import 'main_phone_preview.dart';

/// Offline Android preview with the approved login as its initial screen.
/// Navigation to merchant/customer is available only from the explicitly
/// labeled preview expansion; no real authentication is performed.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaqwatiPhonePreview());
}
