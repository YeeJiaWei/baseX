import 'package:flutter/foundation.dart';

import 'package:package_info_plus/package_info_plus.dart';

/// App metadata sent as request headers; [load]ed once by `runXApp` at boot.
class AppInfo {
  AppInfo._();

  /// The process-wide instance.
  static final AppInfo instance = AppInfo._();

  String _name = '';
  String _version = '';
  String _buildNumber = '';
  String _packageName = '';

  /// App display name, empty until [load] completes.
  String get name => _name;

  /// App version, empty until [load] completes.
  String get version => _version;

  /// App build number, empty until [load] completes.
  String get buildNumber => _buildNumber;

  /// App package name, empty until [load] completes.
  String get packageName => _packageName;

  /// Reads the package info into this instance.
  Future<void> load() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _name = packageInfo.appName;
    _version = packageInfo.version;
    _buildNumber = packageInfo.buildNumber;
    _packageName = packageInfo.packageName;
  }

  /// Sets the values directly, for tests.
  @visibleForTesting
  void debugSet({
    String name = '',
    String version = '',
    String buildNumber = '',
    String packageName = '',
  }) {
    _name = name;
    _version = version;
    _buildNumber = buildNumber;
    _packageName = packageName;
  }
}
