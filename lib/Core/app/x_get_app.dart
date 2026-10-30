import 'package:baseX/base_x.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gms_check/gms_check.dart';

late DefaultBaseConstant baseConstant;
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
/// * [navigatorObservers] => Extra observers for the root navigator (e.g.
///   an analytics screen-view observer); GetX's own observer stays in place
/// * [onFreshInstall] => Runs once on a fresh (re)install, after providers
///   have booted (GetX, `defaultService`, theme available) and before
///   `runApp`. Shares the same memoised [XInstallMarker] as
///   `XAuthStore.bind`'s driver hook, so both agree on whether the install
///   is fresh regardless of which one runs first. Failures are caught and
///   logged, never block boot. See doc/FRESH_INSTALL.md.
/// * [lockTextScale] => Ignore the OS font-size setting (text scale fixed at
///   1.0). Default true
/// * [lockDisplaySize] => Ignore the OS display-size setting (Android Display
///   size, iOS Display Zoom); the app renders at the device's default density.
///   Default true. See doc/DISPLAY_LOCK.md
///
/// API connections are declared via an [ApiXServiceProvider] in the provider
/// list (each [ApiXService] subclass owns its endpoint/timeout/interceptors);
/// runXApp itself does no API wiring. Without a provider, touching
/// [defaultService] throws a StateError naming the missing registration.
///
/// Auth: `await XAuthStore.bind(SecureAuthDriver())` in `main` before calling
/// runXApp (and before the first authed request) — bind is async while
/// [sharedPref] is invoked synchronously, so it cannot be done here. See
/// doc/AUTH.md.
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
  ThemeMode? themeMode,
  // Theme: usually a provider sets baseConstant.theme in boot(); these are an
  // optional fallback for apps without a theme provider.
  ThemeData? lightTheme,
  ThemeData? darkTheme,
  bool required200 = false,
  List<DeviceOrientation> allowOrientationList = const [
    DeviceOrientation.portraitUp,
  ],
  DefaultBaseConstant? constantConfig,
  Function? additionalFunction,
  AdditionalWidget? additionalWidget,
  XLangController<T, K>? langController,
  Future<void> Function()? onFreshInstall,
  List<NavigatorObserver> navigatorObservers = const [],
  bool lockTextScale = true,
  bool lockDisplaySize = true,
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

  assert(
    (Uri.tryParse(baseConstant.baseUrl)?.isAbsolute ?? false),
    'Set a valid live url via constantConfig.baseUrl or liveBaseUrl',
  );
  assert(
    (Uri.tryParse(baseConstant.uatBaseUrl)?.isAbsolute ?? false),
    'Set a valid staging url via constantConfig.uatBaseUrl or staginBaseUrl',
  );

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

  // Fresh-install hook — after providers boot, so GetX/services/theme are
  // available. Shares the process-wide marker with XAuthStore.bind, whichever
  // runs first decides "fresh" for both. A handler failure is caught and
  // logged, never crashes boot; the marker is still set either way so an app
  // with no auth store and no handler gets it written too.
  if (onFreshInstall != null) {
    try {
      if (await XInstallMarker.instance.isFreshInstall) {
        await onFreshInstall();
      }
    } catch (e) {
      XLogger.error('onFreshInstall failed: $e');
    }
  }
  await XInstallMarker.instance.markSeen();

  //Set Gloabal onFailed
  baseConstant.onFailed = onFailed;

  //Additional Function required before run app
  if (additionalFunction != null) {
    additionalFunction();
  }

  // Theme applied by a provider during boot() (baseConstant.theme), else the
  // explicit light/darkTheme fallback.
  final ThemeData? resolvedLight = baseConstant.theme ?? lightTheme;
  final ThemeData? resolvedDark = baseConstant.theme ?? darkTheme;
  assert(
    resolvedLight != null && resolvedDark != null,
    'Set baseConstant.theme in a provider boot(), or pass lightTheme/darkTheme',
  );

  if (lockDisplaySize) await XDisplayScale.instance.start();

  runApp(
    MyApp(
      title: resolvedTitle,
      lightTheme: resolvedLight!,
      darkTheme: resolvedDark!,
      getPages: getPages,
      initialPage: initialPage,
      initialBinding: initialBinding,
      themeMode: themeMode,
      additionalWidget: additionalWidget,
      navigatorObservers: navigatorObservers,
      lockTextScale: lockTextScale,
      lockDisplaySize: lockDisplaySize,
    ),
  );
}

class MyApp extends StatelessWidget {
  final String title;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final ThemeMode? themeMode;
  final List<GetPage<dynamic>> getPages;
  final BaseXWidget initialPage;
  final Bindings initialBinding;
  final AdditionalWidget? additionalWidget;
  final List<NavigatorObserver> navigatorObservers;
  final bool lockTextScale;
  final bool lockDisplaySize;
  const MyApp({
    required this.title,
    required this.lightTheme,
    required this.darkTheme,
    required this.getPages,
    required this.initialPage,
    required this.initialBinding,
    this.themeMode,
    this.additionalWidget,
    this.navigatorObservers = const [],
    this.lockTextScale = true,
    this.lockDisplaySize = true,
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
      navigatorObservers: navigatorObservers,
      builder: (context, child) => XDisplayLock(
        lockTextScale: lockTextScale,
        lockDisplaySize: lockDisplaySize,
        child: child ?? const SizedBox.shrink(),
      ),
      locale: Get.locale,
      localizationsDelegates: Get.locale == null
          ? []
          : [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return additionalWidget == null
        ? materialApp()
        : additionalWidget!(materialApp());
  }
}
