class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isRead;
  final bool deleted;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.isRead = false,
    this.deleted = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      text: json['text'] ?? '',
      imageUrl: json['image_url'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['is_read'] ?? false,
      deleted: json['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
      'image_url': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'deleted': deleted,
    };
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
