import 'dart:collection';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';

/// Privacy-first, bounded diagnostic events. NO exception messages, stack
/// traces, requests, URLs, account IDs, phone numbers, financial values,
/// tokens, or device identifiers are captured.
enum AppIncidentKind { flutterFramework, platformUnhandled, manualFeedback }

class AppIncident {
  const AppIncident(this.kind, this.at);
  final AppIncidentKind kind;
  final DateTime at;

  String get safeLine => '${at.toUtc().toIso8601String()} | ${kind.name}';
}

abstract final class AppIncidentRecorder {
  static const int maxEvents = 40;
  static final Queue<AppIncident> _incidents = Queue<AppIncident>();
  static bool _installed = false;

  static void record(AppIncidentKind kind, {DateTime? when}) {
    if (_incidents.length >= maxEvents) _incidents.removeFirst();
    _incidents.add(AppIncident(kind, when ?? DateTime.now().toUtc()));
  }

  static List<AppIncident> snapshot() => List.unmodifiable(_incidents);

  /// User-triggered export only; never upload to GitHub from a client app.
  /// There is deliberately no arbitrary metadata argument.
  static String exportSanitized() =>
      'Maqwati incident diagnostics v1 (no personal/financial content)\n'
      '${_incidents.map((event) => event.safeLine).join('\n')}';

  static void install() {
    if (_installed) return;
    _installed = true;

    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      record(AppIncidentKind.flutterFramework);
      // Keep full exception details in developer-only diagnostics, never in
      // the exportable user report. Release builds do not echo stack traces.
      if (kDebugMode) previousFlutterHandler?.call(details);
    };

    final previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      record(AppIncidentKind.platformUnhandled);
      if (kDebugMode && previousPlatformHandler != null) {
        return previousPlatformHandler(error, stack);
      }
      return true;
    };
  }

  @visibleForTesting
  static void resetForTests() => _incidents.clear();
}
