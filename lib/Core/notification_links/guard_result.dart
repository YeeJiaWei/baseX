import 'package:baseX/Core/notification_links/guard_decision.dart';

/// The outcome of a [LinkGuard] check.
class GuardResult {
  const GuardResult._(this.decision);

  /// Continue to the next guard, then the handler.
  const GuardResult.allow() : this._(GuardDecision.allow);

  /// Try the next matching route.
  const GuardResult.skip() : this._(GuardDecision.skip);

  /// The guard dealt with the link; nothing else runs.
  const GuardResult.stop() : this._(GuardDecision.stop);

  final GuardDecision decision;
}
