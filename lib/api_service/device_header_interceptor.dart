part of 'index.dart';

/// Injects app/device metadata headers on every request.
class DeviceHeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll({
      Headers.acceptHeader: Headers.jsonContentType,
      'App-Version': baseConstant.appVersion.value,
      'Os-Type': GetPlatform.isIOS ? 'ios' : 'android',
      if (defaultLangController != null)
        'Label-Version': defaultLangController?.labelVersion,
      if (Get.locale != null) 'Accept-Language': Get.locale?.languageCode,
      'Device-Model': baseConstant.deviceModel.value,
      if (baseConstant.deviceId.value != '')
        'Device-ID': baseConstant.deviceId.value,
      if (baseConstant.osVersion.value != '')
        'Os-Version': baseConstant.osVersion.value,
    });
    options.headers.addAll(baseConstant.additionalHeader);
    handler.next(options);
  }
}
