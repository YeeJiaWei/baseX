import 'dart:async';

import 'package:baseX/Core/index.dart';

/// Recording [PushHandler] for assertions.
class FakePushHandler extends PushHandler {
  final registered = <String>[];
  final registeredPermissions = <PushPermission>[];
  final registrations = <PushRegistration>[];
  final unregistered = <String>[];
  final foreground = <PushMessage>[];
  final opened = <PushMessage>[];
  final receipts = <PushReceipt>[];
  bool failRegistration = false;
  bool hangUnregister = false;

  @override
  Future<void> registerToken(PushRegistration registration) async {
    if (failRegistration) throw StateError('unauthenticated');
    registrations.add(registration);
    registered.add(registration.token);
    registeredPermissions.add(registration.permission);
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
