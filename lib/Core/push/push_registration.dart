import 'package:baseX/Core/push/push_permission.dart';
import 'package:baseX/Core/push/push_platform.dart';
import 'package:baseX/Core/push/push_provider.dart';

/// Everything the backend needs to deliver pushes to one device.
class PushRegistration {
  const PushRegistration({
    required this.token,
    required this.platform,
    required this.provider,
    required this.permission,
  });

  final String token;
  final PushPlatform platform;
  final PushProvider provider;
  final PushPermission permission;
}
