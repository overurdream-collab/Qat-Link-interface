import 'package:flutter/material.dart';
import 'services/app_incident_recorder.dart';
import 'main_ui_preview.dart';

/// Separate offline green design experiment. The production entrypoint
/// remains lib/main.dart; never grants a logged-in financial session.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppIncidentRecorder.install();
  runApp(const MaqwatiUiPreview());
}
