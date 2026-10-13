/// Platform-neutral push message so apps never import `firebase_messaging`.
class PushMessage {
  const PushMessage({
    this.id,
    this.type,
    this.title,
    this.body,
    this.data = const {},
  });

  final String? id;
  final String? type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}
