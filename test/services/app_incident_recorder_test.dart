import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/services/app_incident_recorder.dart';

void main() {
  setUp(AppIncidentRecorder.resetForTests);

  test('diagnostics never accept exception text or personal financial payloads', () {
    AppIncidentRecorder.record(AppIncidentKind.flutterFramework,
      when: DateTime.utc(2026, 11, 21, 6));
    final report = AppIncidentRecorder.exportSanitized();
    expect(report, contains('flutterFramework'));
    expect(report, contains('2026-11-21T06:00:00.000Z'));
    expect(report, isNot(contains('Authorization')));
    expect(report, isNot(contains('password')));
    expect(report, isNot(contains('phone')));
    expect(report, isNot(contains('amount')));
    expect(report, isNot(contains('stack')));
  });

  test('client diagnostics use bounded FIFO and immutable snapshot', () {
    for (var i = 0; i < 100; i++) {
      AppIncidentRecorder.record(AppIncidentKind.manualFeedback,
        when: DateTime.utc(2026, 11, 21).add(Duration(seconds: i)));
    }
    final snapshot = AppIncidentRecorder.snapshot();
    expect(snapshot, hasLength(AppIncidentRecorder.maxEvents));
    expect(snapshot.first.at, DateTime.utc(2026, 11, 21, 0, 1));
    expect(snapshot.last.at, DateTime.utc(2026, 11, 21, 0, 1, 39));
    expect(() => snapshot.clear(), throwsUnsupportedError);
  });
}
