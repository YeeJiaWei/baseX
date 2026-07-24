class DefaultBaseXHttp extends BaseXHttp {}

/// [BaseXHttp] is abstract class to let external to be override
/// for certain value
abstract class BaseXHttp {
  int get unknown => -1;
  int get forceUpdate => 426;
  int get internalserver => 500;
  int get invalidRequest => 400;
  int get maintenanceMode => 503;
  int get notFound => 404;
  int get tooManyRequest => 429;
  int get unauthorized => 401;
  int get validationRequest => 422;
  int get versionOutdate => 409;
}

enum XHttpType {
  unknown(-1),
  forceUpdate(426),
  internalserver(500),
  invalidRequest(400),
  maintenanceMode(503),
  notFound(404),
  tooManyRequest(429),
  unauthorized(401),
  validationRequest(422),
  versionOutdate(409),
  ;

  final int value;
  const XHttpType(this.value);

  /// Match a status code against [http]'s (per-connection) mapping. A plain
  /// [DefaultBaseXHttp] (or null) uses the enum's built-in values.
  factory XHttpType.fromValue(int? value, {BaseXHttp? http}) =>
      values.firstWhere((x) => x.codeX(http) == value, orElse: () => unknown);

  int defaultCodeX() {
    return value;
  }

  int customCodeX(BaseXHttp http) {
    switch (this) {
      case XHttpType.forceUpdate:
        return http.forceUpdate;
      case XHttpType.internalserver:
        return http.internalserver;
      case XHttpType.invalidRequest:
        return http.invalidRequest;
      case XHttpType.maintenanceMode:
        return http.maintenanceMode;
      case XHttpType.notFound:
        return http.notFound;
      case XHttpType.tooManyRequest:
        return http.tooManyRequest;
      case XHttpType.unauthorized:
        return http.unauthorized;
      case XHttpType.validationRequest:
        return http.validationRequest;
      case XHttpType.versionOutdate:
        return http.versionOutdate;
      case XHttpType.unknown:
        return http.unknown;
    }
  }

  int codeX(BaseXHttp? http) {
    if (http != null && http.runtimeType != DefaultBaseXHttp) {
      return customCodeX(http);
    } else {
      return defaultCodeX();
    }
  }
}
