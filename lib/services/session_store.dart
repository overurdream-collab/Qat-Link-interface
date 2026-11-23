import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'identity_session_client.dart';

/// Persists only the identity session needed to restore an already-issued
/// login. No PIN, OTP proof, or financial data is stored here.
abstract class SessionStore {
  static SessionStore instance = MemorySessionStore();

  Future<IdentitySession?> read();
  Future<void> write(IdentitySession session);
  Future<void> clear();
}

/// Used by tests and as the safe default before production boot wires the
/// platform secure store. Never persists across process restarts.
class MemorySessionStore implements SessionStore {
  MemorySessionStore([this._session]);

  IdentitySession? _session;

  @override
  Future<IdentitySession?> read() async => _session;

  @override
  Future<void> write(IdentitySession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// Platform-backed encrypted storage. Production `main` installs this.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'maqwati.identity.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<IdentitySession?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final access = decoded['accessToken'];
      final id = decoded['id'];
      final role = decoded['role'];
      final displayName = decoded['displayName'];
      final refreshToken = decoded['refreshToken'];
      if (access is! String ||
          access.length < 50 ||
          id is! String ||
          !['merchant', 'customer'].contains(role)) {
        return null;
      }
      return IdentitySession(
        accessToken: access,
        id: id,
        role: role as String,
        displayName: displayName is String ? displayName : null,
        refreshToken: refreshToken is String ? refreshToken : null,
      );
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> write(IdentitySession session) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'accessToken': session.accessToken,
        'id': session.id,
        'role': session.role,
        'displayName': session.displayName,
        'refreshToken': session.refreshToken,
      }),
    );
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Exception {
      // Fail closed: a delete failure must not block returning to login.
    }
  }
}
