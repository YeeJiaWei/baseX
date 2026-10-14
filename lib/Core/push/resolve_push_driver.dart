import 'package:get/get.dart';

import 'package:baseX/Core/app/x_get_app.dart';
import 'package:baseX/Core/logger/x_logger.dart';
import 'package:baseX/Core/push/push_driver.dart';

/// Picks the push driver for this device: iOS and Google devices use FCM, Huawei devices without Google services use HMS, null when neither exists.
Future<PushDriver?> resolvePushDriver({
  required PushDriver Function() fcm,
  required PushDriver Function() hms,
  bool? isIOS,
  Future<bool> Function()? isGms,
  Future<bool> Function()? isHms,
}) async {
  try {
    if (isIOS ?? GetPlatform.isIOS) return fcm();
    if (await (isGms ?? baseConstant.isGMS)()) return fcm();
    if (await (isHms ?? baseConstant.isHMS)()) return hms();
    XLogger.warning(
      'No push service available on this device',
      className: 'resolvePushDriver',
    );
    return null;
  } catch (error) {
    XLogger.error(
      'Push service detection failed, falling back to FCM: $error',
      className: 'resolvePushDriver',
    );
    return fcm();
  }
}
