import 'dart:math';
import 'package:flutter/foundation.dart';
import 'item_model.dart';
import 'quest_model.dart';

enum PlayerStat {
  strength,
  agility,
  intelligence,
  perception,
  stamina,
}

enum PhysicalActivity {
  pullUps,
  pushUps,
  runningDurationInMin,
  regularExercise,
}

class PlayerModel {
  String playerName;
  int level;
  int xp;
  late int xpToNextLevel;
  Map<PlayerStat, int> stats;
  int availableStatPoints;
  int availableSkillPoints;
  List<String> learnedSkillIds;
  Map<PhysicalActivity, dynamic>? baselinePhysicalPerformance;
  Map<String, String> activeBuffs;
  Map<String, String> skillCooldowns;
  String? lastDailyQuestGenerationDate;
  late QuestDifficulty playerRank;

  late int maxHp;
  late int currentHp;
  late int maxMp;
  late int currentMp;

  static const int baseHpPerLevel = 10;
  static const int hpPerStaminaPoint = 5;
  static const int baseMpPerLevel = 5;
  static const int mpPerIntelligencePoint = 3;

  List<QuestItemReward> inventory;

  PlayerModel({
    this.playerName = "Hunter",
    this.level = 1,
    this.xp = 0,
    Map<PlayerStat, int>? initialStats,
    Map<String, String>? initialActiveBuffs,
    Map<String, String>? initialSkillCooldowns,
    this.lastDailyQuestGenerationDate,
    this.availableStatPoints = 0,
    this.availableSkillPoints = 0,
    this.baselinePhysicalPerformance,
    this.playerRank = QuestDifficulty.F,
    int? loadedCurrentHp,
    int? loadedCurrentMp,
    List<String>? initialLearnedSkillIds,
    List<QuestItemReward>? initialInventory,
  })  : learnedSkillIds = initialLearnedSkillIds ?? [],
        activeBuffs = initialActiveBuffs ?? {},
        skillCooldowns = initialSkillCooldowns ?? {},
        inventory = initialInventory ?? [],
        stats = initialStats ??
            {
              PlayerStat.strength: 5,
              PlayerStat.agility: 5,
              PlayerStat.intelligence: 5,
              PlayerStat.perception: 5,
              PlayerStat.stamina: 5,
            } {
    xpToNextLevel = calculateXpForLevel(level);
    _calculateAndUpdateHpMp();

    currentHp = loadedCurrentHp ?? maxHp;
    currentMp = loadedCurrentMp ?? maxMp;

    currentHp = min(currentHp, maxHp);
    currentMp = min(currentMp, maxMp);
  }

  void _calculateAndUpdateHpMp() {
    final int stamina = stats[PlayerStat.stamina] ?? 0;
    final int intelligence = stats[PlayerStat.intelligence] ?? 0;

    maxHp = (level * baseHpPerLevel) + (stamina * hpPerStaminaPoint) + 50;
    maxMp =
        (level * baseMpPerLevel) + (intelligence * mpPerIntelligencePoint) + 20;
  }

  void onLevelUp() {
    _calculateAndUpdateHpMp();
    currentHp = maxHp;
    currentMp = maxMp;
  }

  void onStatsChanged() {
    final int oldMaxHp = maxHp;
    final int oldMaxMp = maxMp;
    _calculateAndUpdateHpMp();
    final double hpPercentage = (oldMaxHp > 0) ? currentHp / oldMaxHp : 1.0;
    final double mpPercentage = (oldMaxMp > 0) ? currentMp / oldMaxMp : 1.0;
    currentHp = (maxHp * hpPercentage).round().clamp(0, maxHp);
    currentMp = (maxMp * mpPercentage).round().clamp(0, maxMp);
  }

  void takeDamage(int amount) {
    currentHp = max(0, currentHp - amount);
  }

  void restoreHp(int amount, {int? maxAllowedHp}) {
    final effectiveMax = maxAllowedHp ?? maxHp;
    currentHp = min(effectiveMax, currentHp + amount);
  }

  void useMp(int amount) {
    currentMp = max(0, currentMp - amount);
  }

  void restoreMp(int amount, {int? maxAllowedMp}) {
    final effectiveMax = maxAllowedMp ?? maxMp;
    currentMp = min(effectiveMax, currentMp + amount);
  }

  static QuestDifficulty calculateRankByLevel(int level) {
    if (level < 5) return QuestDifficulty.F;
    if (level < 10) return QuestDifficulty.E;
    if (level < 20) return QuestDifficulty.D;
    if (level < 30) return QuestDifficulty.C;
    if (level < 40) return QuestDifficulty.B;
    if (level < 50) return QuestDifficulty.A;
    return QuestDifficulty.S;
  }

  static int calculateXpForLevel(int level) {
    if (level <= 1) return 100;
    return (pow(level, 1.8) * 75 + (level - 1) * 150).round();
  }

  static String getStatName(PlayerStat stat) {
    switch (stat) {
      case PlayerStat.strength:
        return "Strength";
      case PlayerStat.agility:
        return "Agility";
      case PlayerStat.intelligence:
        return "Intelligence";
      case PlayerStat.perception:
        return "Perception";
      case PlayerStat.stamina:
        return "Stamina";
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'stats': stats.map((key, value) => MapEntry(key.name, value)),
      'availableStatPoints': availableStatPoints,
      'availableSkillPoints': availableSkillPoints,
      'learnedSkillIds': learnedSkillIds,
      'baselinePhysicalPerformance': baselinePhysicalPerformance?.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'activeBuffs': activeBuffs,
      'skillCooldowns': skillCooldowns,
      'lastDailyQuestGenerationDate': lastDailyQuestGenerationDate,
      'inventory': inventory.map((item) => item.toJson()).toList(),
      'playerRank': playerRank.name,
      'maxHp': maxHp,
      'currentHp': currentHp,
      'maxMp': maxMp,
      'currentMp': currentMp,
    };
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    Map<PlayerStat, int> loadedStats = {};
    if (json['stats'] is Map) {
      final statsMap = json['stats'] as Map<String, dynamic>;
      for (final entry in statsMap.entries) {
        try {
          final stat = PlayerStat.values.byName(entry.key);
          loadedStats[stat] = (entry.value as num).toInt();
        } catch (_) {}
      }
    }
    if (loadedStats.isEmpty) {
      loadedStats = {
        PlayerStat.strength: 5,
        PlayerStat.agility: 5,
        PlayerStat.intelligence: 5,
        PlayerStat.perception: 5,
        PlayerStat.stamina: 5,
      };
    }

    Map<PhysicalActivity, dynamic>? loadedBaselinePerformance;
    if (json['baselinePhysicalPerformance'] != null &&
        json['baselinePhysicalPerformance'] is Map) {
      try {
        final decodedMap =
            Map<String, dynamic>.from(json['baselinePhysicalPerformance']);
        loadedBaselinePerformance = decodedMap.map((key, value) =>
            MapEntry(PhysicalActivity.values.byName(key), value));
      } catch (e) {
        debugPrint("Error decoding baselinePhysicalPerformance from JSON: $e");
      }
    }

    List<QuestItemReward> loadedInventory = [];
    if (json['inventory'] is List) {
      for (final item in (json['inventory'] as List<dynamic>)) {
        if (item is Map<String, dynamic>) {
          loadedInventory.add(QuestItemReward.fromJson(item));
        }
      }
    }

    Map<String, String> loadedActiveBuffs = {};
    if (json['activeBuffs'] is Map) {
      (json['activeBuffs'] as Map<String, dynamic>).forEach((k, v) {
        if (v != null) loadedActiveBuffs[k] = v.toString();
      });
    }

    Map<String, String> loadedSkillCooldowns = {};
    if (json['skillCooldowns'] is Map) {
      (json['skillCooldowns'] as Map<String, dynamic>).forEach((k, v) {
        if (v != null) loadedSkillCooldowns[k] = v.toString();
      });
    }

    QuestDifficulty loadedRank = QuestDifficulty.F;
    if (json['playerRank'] != null) {
      try {
        loadedRank = QuestDifficulty.values.byName(json['playerRank'] as String);
      } catch (_) {}
    }

    return PlayerModel(
      playerName: json['playerName'] as String? ?? "Hunter",
      level: (json['level'] as num?)?.toInt() ?? 1,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      initialStats: loadedStats,
      availableStatPoints:
          (json['availableStatPoints'] as num?)?.toInt() ?? 0,
      availableSkillPoints:
          (json['availableSkillPoints'] as num?)?.toInt() ?? 0,
      initialLearnedSkillIds:
          (json['learnedSkillIds'] as List<dynamic>?)?.cast<String>() ?? [],
      initialActiveBuffs: loadedActiveBuffs,
      initialSkillCooldowns: loadedSkillCooldowns,
      lastDailyQuestGenerationDate:
          json['lastDailyQuestGenerationDate'] as String?,
      initialInventory: loadedInventory,
      playerRank: loadedRank,
      baselinePhysicalPerformance: loadedBaselinePerformance,
      loadedCurrentHp: (json['currentHp'] as num?)?.toInt(),
      loadedCurrentMp: (json['currentMp'] as num?)?.toInt(),
    );
  }
}
