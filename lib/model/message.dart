

class Message {
  final String? text;
  final String? imagePath;
  final bool isUser;
  final DateTime timestamp;

  Message({
    this.text,
    this.imagePath,
    required this.isUser,
    required this.timestamp,
  });
}