import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

/// Injects app/device metadata headers on every request.
class DeviceHeaderInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll({
      Headers.acceptHeader: Headers.jsonContentType,
      'App-Version': baseConstant.appInfo.version,
      'Os-Type': baseConstant.deviceInfo.os,
      if (defaultLangController != null)
        'Label-Version': defaultLangController?.labelVersion,
      if (Get.locale != null) 'Accept-Language': Get.locale?.languageCode,
      'Device-Model': baseConstant.deviceInfo.model,
      if (baseConstant.deviceInfo.id != '')
        'Device-ID': baseConstant.deviceInfo.id,
      if (baseConstant.deviceInfo.osVersion != '')
        'Os-Version': baseConstant.deviceInfo.osVersion,
    });
    options.headers.addAll(baseConstant.additionalHeader);
    handler.next(options);
  }
}

/// Trait: appends [DeviceHeaderInterceptor] to the connection's stack.
mixin DeviceHeaderApiMixin on ApiXService {
  @override
  List<Interceptor> get interceptors =>
      [...super.interceptors, DeviceHeaderInterceptor()];
}
