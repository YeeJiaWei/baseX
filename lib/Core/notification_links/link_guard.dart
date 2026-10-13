import 'package:baseX/Core/notification_links/guard_result.dart';
import 'package:baseX/Core/notification_links/link_match.dart';

/// A reusable check that runs before a handler, like route middleware.
abstract class LinkGuard {
  /// Decides whether the link may continue.
  Future<GuardResult> check(LinkMatch link);
}
