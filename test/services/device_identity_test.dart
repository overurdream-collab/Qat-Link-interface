import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/services/device_identity.dart';

void main() {
  test('generated install ids are stable UUID v4 values', () async {
    final id = generateDeviceId();
    expect(isValidDeviceId(id), isTrue);
    expect(id.length, 36);
    expect(id[14], '4', reason: 'UUID version nibble');

    final store = MemoryDeviceIdentityStore();
    final first = await store.readOrCreate();
    expect(isValidDeviceId(first), isTrue);
    expect(await store.readOrCreate(), first);

    await store.clear();
    final second = await store.readOrCreate();
    expect(isValidDeviceId(second), isTrue);
    expect(second, isNot(first));
  });

  test('invalid install ids are rejected', () {
    for (final value in [
      '',
      'not-a-device',
      '33333333-3333-0333-8333-333333333333',
      '33333333-3333-4333-0333-333333333333',
      '33333333-3333-4333-8333-33333333333',
    ]) {
      expect(isValidDeviceId(value), isFalse, reason: value);
    }
  });
}
