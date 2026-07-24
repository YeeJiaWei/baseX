import 'package:baseX/api_service/client/standard_api_x_service.dart';

/// Concrete [StandardApiXService] with an explicit endpoint and nothing else —
/// a plain extra connection, or the default one for an app with nothing to add.
class DefaultApiXService extends StandardApiXService {
  final String _endpoint;

  DefaultApiXService(this._endpoint);

  @override
  String get endpoint => _endpoint;
}
