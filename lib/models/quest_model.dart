import 'package:uuid/uuid.dart';
import 'item_model.dart';
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
  List<QuestItemReward>? itemRewards;

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

  QuestModel copyWith({
    String? id,
    String? title,
    String? description,
    int? xpReward,
    QuestType? type,
    QuestDifficulty? difficulty,
    PlayerStat? targetStat,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    int? hpCostOnCompletion,
    List<QuestItemReward>? itemRewards,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      xpReward: xpReward ?? this.xpReward,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      targetStat: targetStat ?? this.targetStat,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      hpCostOnCompletion: hpCostOnCompletion ?? this.hpCostOnCompletion,
      itemRewards: itemRewards ?? this.itemRewards,
    );
  }

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
        return "Rank Up Challenge";
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
      'itemRewards': itemRewards?.map((item) => item.toJson()).toList(),
    };
  }

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    PlayerStat? parsedTargetStat;
    if (json['targetStat'] != null) {
      try {
        parsedTargetStat = PlayerStat.values.byName(json['targetStat'] as String);
      } catch (_) {}
    }

    List<QuestItemReward>? itemRewards;
    if (json['itemRewards'] != null && json['itemRewards'] is List) {
      itemRewards = (json['itemRewards'] as List<dynamic>)
          .map((item) => QuestItemReward.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return QuestModel(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Untitled Quest',
      description: json['description'] as String? ?? '',
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 0,
      type: json['type'] != null
          ? QuestType.values.byName(json['type'] as String)
          : QuestType.generated,
      difficulty: json['difficulty'] != null
          ? QuestDifficulty.values.byName(json['difficulty'] as String)
          : QuestDifficulty.F,
      targetStat: parsedTargetStat,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      hpCostOnCompletion: (json['hpCostOnCompletion'] as num?)?.toInt(),
      itemRewards: itemRewards,
    );
  }
}
