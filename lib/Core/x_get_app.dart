import 'package:baseX/base_x.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gms_check/gms_check.dart';

late DefaultBaseConstant baseConstant;
late ApiXService defaultService;
XLangController? defaultLangController;

/// [runXApp] runXApp<XLabel, XLanguage>
/// * [title] => Title for when hold minimized app will hold
/// * [themeMode] => Enable dark mode, if null being pass, will disable dark mode. Default value is null
/// * [currentEnv] => Set current environment. Staging or Live
/// * [liveBaseUrl] => Set live base url. Required if currentEnv is live
/// * [staginBaseUrl] => Set staging base url. Required if currentEnv is staging
/// * [allowOrientationList] => Set allowed Orientation List
/// * [onFailed] => Set Global onFailed
/// * [getPages] => Register all page route with binding (if any)
/// * [initialBinding] => Set Global Binding
/// * [additionalFunction] => Add additional function before runEtcApp
/// * [additionalWidget] => Add additional widget before material app
/// * [required200] => Set api whether always receive http code 200
/// * [timeOutDurationInSecond] => Set api timeoutDuration to this field in seconds
Future<void> runXApp<T extends XLabel, K extends XLanguage>({
  // required bool requireSharePref,
  required VoidCallback sharedPref,
  required List<GetPage<dynamic>> getPages,
  required BaseXWidget initialPage,
  required Bindings initialBinding,
  required GeneralErrorHandle onFailed,
  // App title + base URLs are derived from the constant's environment
  // (constantConfig.env); pass these only to set or override them explicitly.
  String? title,
  String? liveBaseUrl,
  String? staginBaseUrl,
  Environment? currentEnv,
  BaseXHttp? customHttp,
  ThemeMode? themeMode,
  // Theme: usually a provider sets baseConstant.theme in boot(); these are an
  // optional fallback for apps without a theme provider.
  ThemeData? lightTheme,
  ThemeData? darkTheme,
  bool required200 = false,
  Duration timeOutDurationInSecond = timeoutDuration,
  List<DeviceOrientation> allowOrientationList = const [DeviceOrientation.portraitUp],
  DefaultBaseConstant? constantConfig,
  Function? additionalFunction,
  AddtionalWidget? additionalWidget,
  XLangController<T, K>? langController,
}) async {
  //Check required field
  // assert(!(appLanguage != null && !requireSharePref),
  //     'Required Share Preference to enable App Language');

  await GmsCheck().checkGmsAvailability();

  //Set available orientation
  SystemChrome.setPreferredOrientations(allowOrientationList);

  //Set Constant File
  baseConstant = constantConfig ?? DefaultBaseConstant();

  //Set Base Url — from the constant's resolved environment, then overrides.
  final environment = baseConstant.env?.active;
  if (environment != null) {
    baseConstant.baseUrl = environment.apiBaseUrl;
    baseConstant.uatBaseUrl = environment.apiBaseUrl;
  }
  if (staginBaseUrl != null) baseConstant.uatBaseUrl = staginBaseUrl;
  if (liveBaseUrl != null) baseConstant.baseUrl = liveBaseUrl;
  if (currentEnv != null) baseConstant.appEnv = currentEnv;

  final resolvedTitle = title ?? environment?.name ?? '';

  assert((Uri.tryParse(baseConstant.baseUrl)?.isAbsolute ?? false),
      'Set a valid live url via constantConfig.baseUrl or liveBaseUrl');
  assert((Uri.tryParse(baseConstant.uatBaseUrl)?.isAbsolute ?? false),
      'Set a valid staging url via constantConfig.uatBaseUrl or staginBaseUrl');

  // Set api whether always receive http code 200
  baseConstant.success200 = required200;

  sharedPref();

  // Boot service providers (declared on the constant config) now that storage
  // (sharedPref) is ready. register() for all, then boot() for all — so a
  // boot() may rely on another's register().
  final providers = baseConstant.providers();
  for (final provider in providers) {
    provider.register();
  }
  for (final provider in providers) {
    provider.boot();
  }

  if (langController != null) {
    defaultLangController = Get.put<XLangController<T, K>>(langController);
  }

  //Set Gloabal onFailed
  baseConstant.onFailed = onFailed;

  //Additional Function required before run app
  if (additionalFunction != null) {
    additionalFunction();
  }
  Dio _dio = Dio();

  defaultService =
      ApiXService.init(_dio, timeOutDurationInSecond, customHttp: customHttp ?? DefaultBaseXHttp());

  // Theme applied by a provider during boot() (baseConstant.theme), else the
  // explicit light/darkTheme fallback.
  final ThemeData? resolvedLight = baseConstant.theme ?? lightTheme;
  final ThemeData? resolvedDark = baseConstant.theme ?? darkTheme;
  assert(resolvedLight != null && resolvedDark != null,
      'Set baseConstant.theme in a provider boot(), or pass lightTheme/darkTheme');

  runApp(MyApp(
    title: resolvedTitle,
    lightTheme: resolvedLight!,
    darkTheme: resolvedDark!,
    getPages: getPages,
    initialPage: initialPage,
    initialBinding: initialBinding,
    themeMode: themeMode,
    additionalWidget: additionalWidget,
  ));
}

class MyApp extends StatelessWidget {
  final String title;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode? themeMode;
  final List<GetPage<dynamic>> getPages;
  final BaseXWidget initialPage;
  final Bindings initialBinding;
  final AddtionalWidget? additionalWidget;
  const MyApp({
    required this.title,
    required this.lightTheme,
    required this.darkTheme,
    required this.getPages,
    required this.initialPage,
    required this.initialBinding,
    this.themeMode,
    this.additionalWidget,
  });

  Widget materialApp() {
    return GetMaterialApp(
      title: title,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      getPages: getPages,
      initialRoute: initialPage.routeName,
      initialBinding: initialBinding,
      locale: Get.locale,
      localizationsDelegates: Get.locale == null
          ? []
          : [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return additionalWidget == null ? materialApp() : additionalWidget!(materialApp());
  }
}
