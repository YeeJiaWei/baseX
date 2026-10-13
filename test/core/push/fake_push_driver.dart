import 'dart:async';

import 'package:baseX/Core/index.dart';

/// Scriptable [PushDriver] with no platform channels.
class FakePushDriver implements PushDriver {
  PushPermission permission = PushPermission.notDetermined;
  PushPermission permissionAfterRequest = PushPermission.authorized;
  String? token = 'token-1';
  PushMessage? initialMessage;
  int requestCount = 0;
  Completer<String?>? tokenCompleter;
  bool throwOnPermission = false;
  bool throwOnPresentation = false;

  final tokenController = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushMessage>.broadcast();
  final openedController = StreamController<PushMessage>.broadcast();

  @override
  Future<PushPermission> getPermission() async {
    if (throwOnPermission) throw StateError('permission boom');
    return permission;
  }

  @override
  Future<PushPermission> requestPermission() async {
    requestCount++;
    return permission = permissionAfterRequest;
  }

  @override
  Future<void> setForegroundPresentation() async {
    if (throwOnPresentation) throw StateError('presentation boom');
  }

  @override
  Future<String?> getToken() async => tokenCompleter?.future ?? token;

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<String> get onTokenRefresh => tokenController.stream;

  @override
  Stream<PushMessage> get onForeground => foregroundController.stream;

  @override
  Stream<PushMessage> get onOpened => openedController.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initialMessage;
}
