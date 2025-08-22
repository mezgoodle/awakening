import 'package:uuid/uuid.dart';
import 'player_model.dart';

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
enum QuestDifficulty { F, E, D, C, B, A, S }

class QuestModel {
  final String id;
  final String title;
  final String description;
  final int xpReward;
  final QuestType type;
  final QuestDifficulty difficulty;
  final PlayerStat? targetStat;
  bool isCompleted;
  final DateTime? createdAt; // Коли квест було створено/додано
  DateTime? completedAt; // Коли квест було виконано
  final int? hpCostOnCompletion;
  List<Map<String, dynamic>>? itemRewards; // Нагороди у вигляді предметів

  QuestModel({
    String? id, // Дозволяємо передавати id або генеруємо
    required this.title,
    required this.description,
    required this.xpReward,
    required this.type,
    required this.difficulty,
    this.targetStat,
    this.isCompleted = false,
    DateTime? createdAt,
    this.completedAt,
    this.hpCostOnCompletion,
    this.itemRewards,
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

  static String getQuestDifficultyName(QuestDifficulty difficulty) {
    return difficulty.name;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'xpReward': xpReward,
      'type': type.name, // Зберігаємо як рядок
      'difficulty': difficulty.name, // Зберігаємо як рядок
      'targetStat': targetStat?.name, // Зберігаємо як рядок або null
      'isCompleted': isCompleted,
      'createdAt': createdAt?.toIso8601String(), // Зберігаємо як ISO рядок
      'completedAt': completedAt?.toIso8601String(),
      'hpCostOnCompletion': hpCostOnCompletion,
      'itemRewards': itemRewards,
    };
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    PlayerStat? parsedTargetStat;
    if (json['targetStat'] != null) {
      parsedTargetStat = PlayerStat.values.byName(json['targetStat'] as String);
    }

    return QuestModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      xpReward: json['xpReward'] as int,
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
      hpCostOnCompletion: json['hpCostOnCompletion'] as int?,
      itemRewards: (json['itemRewards'] as List<dynamic>?)
          ?.map((item) => item as Map<String, dynamic>)
          .toList(),
    );
  }
}
