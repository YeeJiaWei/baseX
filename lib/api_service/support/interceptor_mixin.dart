import 'package:dio/dio.dart';

import 'package:baseX/custom_error/index.dart';

import 'package:baseX/api_service/support/http_type_x.dart';

/// Maps a status code + envelope error body to a typed [DioException].
mixin InterceptorMixin {
  DioException onErrorProcess(
    int? statusCode,
    String message,
    RequestOptions requestOptions,
    BaseXHttp http, {
    int? code,
    Response? response,
  }) {
    XHttpType x = XHttpType.fromValue(statusCode, http: http);

    switch (x) {
      case XHttpType.invalidRequest:
        if (code != null && code != 40000) {
          return InvalidRequestException(
            errorMsg: message,
            requestOptions: requestOptions,
            response: response,
            statusCode: code,
          );
        } else {
          return InvalidRequestException(
            errorMsg: message,
            requestOptions: requestOptions,
            response: response,
            statusCode: statusCode,
          );
        }
      case XHttpType.unauthorized:
        return UnauthorizedException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      case XHttpType.notFound:
        return NotFoundException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      case XHttpType.validationRequest:
        return ValidationException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      case XHttpType.tooManyRequest:
        return TooManyRequestException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      case XHttpType.forceUpdate:
        return ForceUpdateException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      case XHttpType.maintenanceMode:
        return MaintenanceException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
      default:
        return InternalServerErrorException(
          errorMsg: message,
          requestOptions: requestOptions,
          response: response,
          statusCode: statusCode,
        );
    }
  }
}
