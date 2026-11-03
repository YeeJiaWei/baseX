import 'package:baseX/base_x.dart';
import 'package:flutter/material.dart';
import 'package:gms_check/gms_check.dart';
import 'package:huawei_hmsavailability/huawei_hmsavailability.dart';

enum Environment { Live, Staging }

enum Position { top, bottom, none }

/// Default variable:
///
/// 1. baseUrl => Live url set in runEtcApp
/// 2. staginBaseUrl => Staging url set in runEtcApp
/// 3. languageCode => current language selected, by default is English, en. (if multi langauge is enable in runEtcApp)
/// 4. onFailed => global onFailed set in runEtcApp
class BaseConstant {
  /// The app's [ProviderConfig]. Override in your AppConstant to point at your
  /// ProviderConfig subclass; defaults to an empty config.
  ProviderConfig get providerConfig => const ProviderConfig();

  /// The app's environment resolver. Override in your AppConstant to point at
  /// your [EnvironmentResolver]; runXApp reads its active environment for the title + base URLs.
  EnvironmentResolver<EnvironmentConstant>? get env => null;

  /// The app's error tracking, the same for every flavor; null turns it off.
  ErrorTrackingConstant? get errorTracking => null;

  /// The device's model, OS version and id, loaded by [runXApp] at boot.
  DeviceInfo get deviceInfo => DeviceInfo.instance;

  /// The app's name, version, build number and package name, loaded by [runXApp] at boot.
  AppInfo get appInfo => AppInfo.instance;

  /// The service providers [runXApp] boots. Reads them from [providerConfig].
  List<ServiceProvider> providers() => providerConfig.providers;

  /// The app's initial theme. A service provider sets this during boot();
  /// [runXApp] reads it when building the app. Null falls back to runXApp's
  /// lightTheme/darkTheme.
  ThemeData? theme;

  Color get defaultBackgroundColor => Colors.white;

  Widget get defaultLoadingWidget => SizedBox.shrink();

  Environment appEnv = Environment.Live;

  String baseUrl = '';

  String uatBaseUrl = '';

  bool success200 = false;

  Position position = Position.bottom;

  Map<String, String> additionalHeader = <String, String>{};


  Widget envBar = Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    color: Colors.greenAccent,
    child: Builder(
      builder: (_) => Text(
        'Endpoint: Staging | Os-type: ${baseConstant.deviceInfo.os} | Device-Model: ${baseConstant.deviceInfo.model} | Os-version: ${baseConstant.deviceInfo.osVersion}',
        style: TextStyle(
          fontSize: 8,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );

  @Deprecated('Use XExceptionHandler (runXApp exceptionHandler:) instead')
  late GeneralErrorHandle onFailed;

  /// 0: HMS Core (APK) is available.
  ///
  /// 1: No HMS Core (APK) is found on device.
  ///
  /// 2: HMS Core (APK) installed is out of date.
  ///
  /// 3: HMS Core (APK) installed on the device is unavailable.
  ///
  /// 9: HMS Core (APK) installed on the device is not the official version.
  ///
  /// 21: The device is too old to support HMS Core (APK)
  ///
  Future<bool> isHMS() async {
    if (GetPlatform.isIOS) return false;
    HmsApiAvailability client = HmsApiAvailability();
    int status = await client.isHMSAvailable();
    bool _isGMS = await isGMS();
    return status == 0 && !_isGMS;
    // -- Added !_isGMS to ensure the device have actually no GMS, else still can proceed GMS services.
  }

  Future<bool> isGMS() async {
    if (GetPlatform.isIOS) return true;
    bool result = GmsCheck().isGmsAvailable;
    return result;
  }

  /// Error Widget which can be override
  Widget customErrorWidget(FlutterErrorDetails error) => SafeArea(
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.only(top: 30, bottom: 10),
                child: Icon(Icons.announcement, size: 40, color: Colors.red),
              ),
              Text(
                'An application error has occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
              ),
              Container(
                  padding: EdgeInsets.all(15),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error message:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Text(error.exceptionAsString()),
                    ],
                  )),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stack Trace:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Expanded(child: SingleChildScrollView(child: Text(error.stack.toString()))),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(15),
                width: double.infinity,
                child: InkWell(
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'Send Bug Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> defaulOnFailedDialog(int statusCode, String message) => Get.dialog(AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        content: Text(message),
      ));

  /// Put [floatingAction] with [FloatingAction] in your app_constant for global floating action
  /// ```dart
  /// @override
  /// FloatingAction get floatingAction => FloatingAction(
  ///   floatingActionButton: FloatingActionButton(
  ///   onPressed: () {
  ///     //TODO Add your onPressed code here!
  ///   },
  ///   backgroundColor: Colors.blue,
  ///   child: Icon(Icons.add),
  ///  ),
  /// );
  /// ```
  FloatingAction? get floatingAction => null;

  /// Put [drawerAction] with [DrawerAction] in your app_constant for global drawer action
  /// ```dart
  /// @override
  /// DrawerAction get drawerAction => DrawerAction(
  ///    drawerPosition: DrawerPosition.Right,
  ///    drawer: Drawer(
  ///      child: ListView(
  ///        padding: EdgeInsets.zero,
  ///        children: [
  ///          DrawerHeader(
  ///            decoration: BoxDecoration(
  ///              color: Colors.blue,
  ///            ),
  ///            child: Text('Drawer Header 2'),
  ///          ),
  ///          ListTile(
  ///            title: Text('Item 2'),
  ///            onTap: () {
  ///              //TODO Add your onTap code here!
  ///            },
  ///          ),
  ///        ],
  ///      ),
  ///    ),
  /// );
  /// ```
  DrawerAction? get drawerAction => null;
}
