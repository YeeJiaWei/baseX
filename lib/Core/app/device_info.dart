import 'package:flutter/foundation.dart';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:ios_utsname_ext/extension.dart';

/// Device metadata sent as request headers; [load]ed once by `runXApp` at boot.
class DeviceInfo {
  DeviceInfo._();

  /// The process-wide instance.
  static final DeviceInfo instance = DeviceInfo._();

  String _osVersion = '';
  String _model = '';
  String _id = '';

  /// OS version, empty until [load] completes.
  String get osVersion => _osVersion;

  /// Device model, empty until [load] completes.
  String get model => _model;

  /// Platform device id, empty until [load] completes.
  String get id => _id;

  /// The platform name, 'ios' or 'android'; needs no [load].
  String get os => GetPlatform.isIOS ? 'ios' : 'android';

  /// Reads the platform device info into this instance.
  Future<void> load() async {
    final deviceInfo = DeviceInfoPlugin();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      _id = (await AndroidId().getId())!;
      _osVersion = androidInfo.version.release;
      _model = '${androidInfo.manufacturer} ${androidInfo.model}';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _id = iosInfo.identifierForVendor!;
      _osVersion = iosInfo.systemVersion;
      _model = iosInfo.utsname.machine.iOSProductName;
    }
  }

  /// Sets the values directly, for tests.
  @visibleForTesting
  void debugSet({String osVersion = '', String model = '', String id = ''}) {
    _osVersion = osVersion;
    _model = model;
    _id = id;
  }
}
