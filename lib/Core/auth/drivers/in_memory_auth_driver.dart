import 'package:baseX/Core/auth/x_auth_store.dart';

/// [XAuthStore] driver that keeps the token in memory only — for tests and tooling.
class InMemoryAuthDriver extends XAuthStore {
  String? _value;

  InMemoryAuthDriver([this._value]);

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String token) async => _value = token;

  @override
  Future<void> delete() async => _value = null;
}
