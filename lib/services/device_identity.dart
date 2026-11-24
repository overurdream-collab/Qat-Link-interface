import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stable install identifier used to bind refreshable sessions to one device.
/// It is not a phone identifier and carries no personal data.
abstract class DeviceIdentityStore {
  static DeviceIdentityStore instance = MemoryDeviceIdentityStore();

  Future<String> readOrCreate();
  Future<void> clear();
}

class MemoryDeviceIdentityStore implements DeviceIdentityStore {
  MemoryDeviceIdentityStore([String? deviceId]) : _deviceId = deviceId;

  String? _deviceId;

  @override
  Future<String> readOrCreate() async {
    final existing = _deviceId;
    if (existing != null && isValidDeviceId(existing)) return existing;
    return _deviceId = generateDeviceId();
  }

  @override
  Future<void> clear() async => _deviceId = null;
}

class SecureDeviceIdentityStore implements DeviceIdentityStore {
  SecureDeviceIdentityStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'maqwati.device.id.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String> readOrCreate() async {
    try {
      final existing = await _storage.read(key: _key);
      if (existing != null && isValidDeviceId(existing)) return existing;
    } on Exception {
      // Fall through and create a fresh install id.
    }
    final id = generateDeviceId();
    try {
      await _storage.write(key: _key, value: id);
    } on Exception {
      // The session can still be created; refresh may not survive reinstall.
    }
    return id;
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Fail closed for callers that are already clearing the session.
    }
  }
}

final _uuid = RegExp(r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[1-5][a-fA-F0-9]{3}-'
    r'[89abAB][a-fA-F0-9]{3}-[a-fA-F0-9]{12}$');

bool isValidDeviceId(String value) => _uuid.hasMatch(value);

String generateDeviceId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
