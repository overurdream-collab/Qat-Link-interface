import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/device_identity.dart';
import '../services/identity_session_client.dart';
import '../services/maqwati_api_config.dart';
import '../services/session_store.dart';
import 'login_screen.dart';
import 'role_home_screen.dart';

/// Shows login immediately, then restores a previously stored session only
/// after the issuer confirms the token via `/v1/identity/me`.
class SessionGate extends StatefulWidget {
  const SessionGate({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    this.store,
    this.client,
    this.deviceStore,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;
  final SessionStore? store;
  final IdentitySessionClient? client;
  final DeviceIdentityStore? deviceStore;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  late final SessionStore _store;
  http.Client? _ownedHttp;
  IdentitySessionClient? _client;
  IdentitySession? _session;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SessionStore.instance;
    _restore();
  }

  Future<void> _restore() async {
    final stored = await _store.read();
    if (!mounted || stored == null) return;

    var client = widget.client;
    if (client == null) {
      final origin = MaqwatiApiConfig.origin;
      if (origin == null) {
        await _store.clear();
        return;
      }
      _ownedHttp = http.Client();
      client = IdentitySessionClient(
        baseUri: origin,
        httpClient: _ownedHttp!,
        timeout: const Duration(seconds: 4),
      );
    }
    _client = client;
    try {
      final session = await client.confirm(accessToken: stored.accessToken);
      _activate(session);
    } on IdentitySessionException {
      final refreshToken = stored.refreshToken;
      if (refreshToken == null) {
        await _store.clear();
        return;
      }
      try {
        final deviceId = await (widget.deviceStore ?? DeviceIdentityStore.instance)
            .readOrCreate();
        final session = await client.refresh(
          refreshToken: refreshToken,
          deviceId: deviceId,
        );
        await _store.write(session);
        _activate(session);
      } on IdentitySessionException {
        await _store.clear();
      }
    }
  }

  void _activate(IdentitySession session) {
    if (!mounted) return;
    // Do not replace the workspace under an active login/OTP route.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    final session = _session;
    final client = _client;
    if (session != null && client != null) {
      try {
        await client.logout(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
        );
      } on Exception {
        // Revocation is best effort; local clear still prevents reuse here.
      }
    }
    try {
      await _store.clear();
    } on Exception {
      // Continue to login even if secure storage is unavailable.
    }
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  void dispose() {
    _ownedHttp?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) {
      return RoleHomeScreen(
        session: session,
        store: _store,
        onLoggedOut: _logout,
      );
    }
    return LoginScreen(
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
    );
  }
}
