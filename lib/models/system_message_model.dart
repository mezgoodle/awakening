import 'package:uuid/uuid.dart';

enum MessageType {
  info, // Загальна інформація
  levelUp, // Підвищення рівня
  rankUp, // Підвищення рангу
  questCompleted, // Завдання виконано
  questAdded, // Завдання додано
  statsIncreased, // Характеристики збільшено (за очки)
  error, // Помилка
  warning, // Попередження
  system, // Системне повідомлення (наприклад, від Gemini)
}

class SystemMessageModel {
  final String id;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  bool isRead; // Для майбутнього, якщо потрібно буде відмічати прочитані в лозі

  SystemMessageModel({
    String? id,
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.isRead = false, // За замовчуванням нові повідомлення не прочитані
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type.name, // Зберігаємо enum як рядок
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
