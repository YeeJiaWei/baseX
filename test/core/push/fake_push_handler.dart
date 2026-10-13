import 'dart:async';

import 'package:baseX/Core/index.dart';

/// Recording [PushHandler] for assertions.
class FakePushHandler extends PushHandler {
  final registered = <String>[];
  final registeredPermissions = <PushPermission>[];
  final unregistered = <String>[];
  final foreground = <PushMessage>[];
  final opened = <PushMessage>[];
  final receipts = <PushReceipt>[];
  bool failRegistration = false;
  bool hangUnregister = false;

  @override
  Future<void> registerToken(
      String token, PushPlatform platform, PushPermission permission) async {
    if (failRegistration) throw StateError('unauthenticated');
    registered.add(token);
    registeredPermissions.add(permission);
  }

  @override
  Future<void> unregisterToken(String token) async {
    if (hangUnregister) return Completer<void>().future;
    unregistered.add(token);
  }

  @override
  void onForeground(PushMessage message) => foreground.add(message);

  @override
  void onOpened(PushMessage message) => opened.add(message);

  @override
  void onReceipt(PushMessage message, PushReceipt receipt) =>
      receipts.add(receipt);
}
