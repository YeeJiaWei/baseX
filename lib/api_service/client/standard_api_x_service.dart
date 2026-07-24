import 'package:baseX/api_service/client/api_x_service.dart';
import 'package:baseX/api_service/interceptor/api_error_interceptor.dart';
import 'package:baseX/api_service/interceptor/x_logger_interceptor.dart';
import 'package:baseX/api_service/interceptor/auth_interceptor.dart';
import 'package:baseX/api_service/interceptor/device_header_interceptor.dart';

/// [ApiXService] pre-composed with the standard baseX traits: device headers
/// → bearer auth → envelope error mapping → logging. Extend it, declare
/// [endpoint], and mix in app traits. Foreign-API connections compose from
/// [ApiXService] directly instead.
abstract class StandardApiXService extends ApiXService
    with DeviceHeaderApiMixin, AuthApiMixin, ApiErrorApiMixin, XLoggerApiMixin {}
