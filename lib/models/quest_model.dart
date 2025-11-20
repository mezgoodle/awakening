import 'package:uuid/uuid.dart';
import 'player_model.dart';

enum QuestType {
  daily,
  weekly,
  milestone,
  generated,
  story,
  rankUpChallenge,
}

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
  final DateTime? createdAt;
  DateTime? completedAt;
  final int? hpCostOnCompletion;
  List<Map<String, dynamic>>? itemRewards;

  QuestModel({
    String? id,
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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  static String getQuestTypeName(QuestType type) {
    switch (type) {
      case QuestType.daily:
        return "Daily";
      case QuestType.weekly:
        return "Weekly";
      case QuestType.milestone:
        return "Milestone";
      case QuestType.generated:
        return "Generated";
      case QuestType.story:
        return "Story";
      case QuestType.rankUpChallenge:
        return "RankUpChallenge";
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
      'type': type.name,
      'difficulty': difficulty.name,
      'targetStat': targetStat?.name,
      'isCompleted': isCompleted,
      'createdAt': createdAt?.toIso8601String(),
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
