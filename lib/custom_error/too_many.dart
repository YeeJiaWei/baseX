part of 'index.dart';

/// Status Code is 429
/// will throw TooManyRequestException
class TooManyRequestException extends XError {
  TooManyRequestException({
    required super.requestOptions,
    super.errorMsg,
    super.statusCode,
    super.response,
  });

  @override
  String toString() {
    return errorMsg ?? 'The connection has request too many, please try again later.';
  }

  @override
  int? getStatusCode() {
    return statusCode;
  }
}
