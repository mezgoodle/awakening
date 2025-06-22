// lib/models/quest_model.dart
import 'package:uuid/uuid.dart'; // Додай 'uuid: ^4.4.0' в pubspec.yaml
import 'player_model.dart'; // Для PlayerStat

// Типи квестів
enum QuestType {
  daily, // Щоденний
  weekly, // Щотижневий (поки не використовуємо, але закладаємо)
  milestone, // Досягнення певного етапу
  generated, // Згенерований (наприклад, через Gemini)
  story, // Сюжетний (для майбутнього)
  rankUpChallenge, // Виклик підвищення рангу
}

// Складність квестів
enum QuestDifficulty {
  F, // Найлегший
  E,
  D,
  C,
  B,
  A,
  S, // Найскладніший
}

class QuestModel {
  final String id;
  final String title;
  final String description;
  final int xpReward;
  final Map<PlayerStat, int>?
      statRewards; // Нагороди характеристиками (опціонально)
  final QuestType type;
  final QuestDifficulty difficulty;
  final PlayerStat?
      targetStat; // На яку характеристику сфокусовано (опціонально)
  bool isCompleted;
  final DateTime? createdAt; // Коли квест було створено/додано
  DateTime? completedAt; // Коли квест було виконано

  QuestModel({
    String? id, // Дозволяємо передавати id або генеруємо
    required this.title,
    required this.description,
    required this.xpReward,
    this.statRewards,
    required this.type,
    required this.difficulty,
    this.targetStat,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(), // Генеруємо унікальний ID, якщо не надано
        createdAt = createdAt ?? DateTime.now();

  // Метод для зручного отримання назви типу квесту
  static String getQuestTypeName(QuestType type) {
    switch (type) {
      case QuestType.daily:
        return "Щоденне";
      case QuestType.weekly:
        return "Щотижневе";
      case QuestType.milestone:
        return "Віха";
      case QuestType.generated:
        return "Згенероване";
      case QuestType.story:
        return "Сюжетне";
      case QuestType.rankUpChallenge:
        return "Рангове Випробування";
      default:
        return "Завдання";
    }
  }

  // Метод для зручного отримання назви складності
  static String getQuestDifficultyName(QuestDifficulty difficulty) {
    return difficulty.name; // Просто повертаємо назву enum (F, E, D...)
  }

  // toJson та fromJson для збереження/завантаження
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'xpReward': xpReward,
      'statRewards':
          statRewards?.map((key, value) => MapEntry(key.name, value)),
      'type': type.name, // Зберігаємо як рядок
      'difficulty': difficulty.name, // Зберігаємо як рядок
      'targetStat': targetStat?.name, // Зберігаємо як рядок або null
      'isCompleted': isCompleted,
      'createdAt': createdAt?.toIso8601String(), // Зберігаємо як ISO рядок
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    Map<PlayerStat, int>? parsedStatRewards;
    if (json['statRewards'] != null) {
      parsedStatRewards = (json['statRewards'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          PlayerStat.values.byName(key),
          value as int,
        ),
      );
    }

    PlayerStat? parsedTargetStat;
    if (json['targetStat'] != null) {
      parsedTargetStat = PlayerStat.values.byName(json['targetStat'] as String);
    }

    return QuestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      xpReward: json['xpReward'] as int,
      statRewards: parsedStatRewards,
      type: QuestType.values.byName(json['type'] as String),
      difficulty: QuestDifficulty.values.byName(json['difficulty'] as String),
      targetStat: parsedTargetStat,
      isCompleted: json['isCompleted'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }
}
