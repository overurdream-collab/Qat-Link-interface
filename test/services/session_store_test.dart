import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/services/identity_session_client.dart';
import 'package:qat_link/services/session_store.dart';

void main() {
  test('memory store round-trips a session and clears it', () async {
    final store = MemorySessionStore();
    expect(await store.read(), isNull);

    const session = IdentitySession(
      accessToken: 'token-value',
      id: 'account-one',
      role: 'merchant',
      displayName: 'متجر الأصالة',
      refreshToken: 'rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr',
    );
    await store.write(session);
    final restored = await store.read();
    expect(restored?.accessToken, session.accessToken);
    expect(restored?.id, session.id);
    expect(restored?.role, session.role);
    expect(restored?.displayName, session.displayName);
    expect(restored?.refreshToken, session.refreshToken);

    await store.clear();
    expect(await store.read(), isNull);
  });
}
