import 'package:dio/dio.dart';

import 'package:baseX/Core/index.dart';

import 'package:baseX/api_service/client/api_x_service.dart';

/// Trait: appends the app's [XUserSyncInterceptor] to the connection's stack.
mixin UserSyncApiMixin on ApiXService {
  /// The app's [XUserSyncInterceptor] implementation. Read once at construction.
  XUserSyncInterceptor get userSyncInterceptor;

  @override
  List<Interceptor> get interceptors =>
      [...super.interceptors, userSyncInterceptor];
}

/// Transport half of the checksum-based user-sync contract — sends
/// [currentChecksum] out on authed requests, detects the [userKey] +
/// [checksumKey] envelope siblings coming back, and hands them to
/// [applySyncedUser]. Apply failures are swallowed. See doc/API_SERVICE.md.
abstract class XUserSyncInterceptor extends Interceptor {
  String get checksumHeader => 'X-User-Checksum';
  String get userKey => 'user';
  String get checksumKey => 'user_checksum';

  /// The last server-issued checksum; null forces a sync.
  String? get currentChecksum;

  /// Apply a synced payload; store [checksum] verbatim (server-computed).
  void applySyncedUser(Map<String, dynamic> userJson, String checksum);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final checksum = currentChecksum;
    if (options.extra['requiredToken'] == true && checksum != null) {
      options.headers[checksumHeader] = checksum;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    try {
      final data = response.data;
      if (data is Map) {
        final userJson = data[userKey];
        final checksum = data[checksumKey];
        if (userJson is Map<String, dynamic> && checksum is String) {
          applySyncedUser(userJson, checksum);
        }
      }
    } catch (e) {
      XLogger.error('XUserSyncInterceptor apply failed (swallowed): $e');
    }
    handler.next(response);
  }
}
