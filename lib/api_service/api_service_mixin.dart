import 'package:baseX/api_service/client/api_x_service.dart';

/// Contract for API service classes. Both members are abstract on purpose —
/// a service must state its transport; there is no implicit default. Define
/// one project-level base per connection (`defaultServ => defaultService` or
/// `ApiXConnections.of(alias)`) and extend it. See doc/API_SERVICE.md.
mixin ApiServiceMixin {
  /// The transport this service's calls go through.
  ApiXService get defaultServ;

  /// Base endpoint for the service.
  String get apiPath;
}
