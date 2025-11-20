import 'package:uuid/uuid.dart';

enum MessageType {
  info,
  levelUp,
  rankUp,
  questCompleted,
  questAdded,
  statsIncreased,
  error,
  warning,
  system,
}

class SystemMessageModel {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  bool isRead;

  SystemMessageModel({
    String? id,
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.isRead = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory SystemMessageModel.fromJson(Map<String, dynamic> json) {
    return SystemMessageModel(
      id: json['id'] as String,
      text: json['text'] as String,
      type: MessageType.values.byName(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }
}
