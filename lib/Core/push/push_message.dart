import 'package:baseX/Core/push/push_payload.dart';

/// Platform-neutral push message so apps never import `firebase_messaging`.
class PushMessage {
  const PushMessage({
    this.id,
    this.title,
    this.body,
    this.payload = const PushPayload(),
    this.data = const {},
  });

  final String? id;
  final String? title;
  final String? body;

  /// The package-owned payload parsed from `data`.
  final PushPayload payload;

  /// All data keys as delivered, including the raw `payload` entry.
  final Map<String, dynamic> data;

  /// The payload's event type.
  String? get type => payload.type;
}
