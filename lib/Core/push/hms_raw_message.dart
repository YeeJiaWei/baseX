/// Huawei message fields as the plugin delivers them, before the data string is decoded.
class HmsRawMessage {
  const HmsRawMessage({
    this.id,
    this.rawData,
    this.title,
    this.body,
    this.extras = const {},
  });

  final String? id;

  /// The message `data`, one JSON string.
  final String? rawData;
  final String? title;
  final String? body;

  /// Intent extras the app was launched with when the message was tapped.
  final Map<String, dynamic> extras;
}
