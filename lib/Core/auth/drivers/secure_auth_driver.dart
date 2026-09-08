import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:baseX/Core/auth/x_auth_store.dart';

/// [XAuthStore] driver backed by the platform secure store (Keychain / Keystore).
class SecureAuthDriver extends XAuthStore {
  final FlutterSecureStorage _storage;
  final String key;

  SecureAuthDriver({FlutterSecureStorage? storage, this.key = 'bearer_token'})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      // The Keystore-wrapped AES key can desync from the stored ciphertext on
      // a device (backup restore, OS upgrade, OEM key rotation), making the
      // read throw BadPaddingException/BAD_DECRYPT. Left unguarded this escapes
      // the awaited bind() in boot and hangs the splash. Wipe the unreadable
      // entry and continue as logged-out so the user can simply re-login.
      try {
        await _storage.delete(key: key);
      } catch (_) {
        await _storage.deleteAll();
      }
      return null;
    }
  }

  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: key);
}
