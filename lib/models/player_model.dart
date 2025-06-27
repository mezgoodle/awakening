import 'dart:math';
import 'quest_model.dart';

// Перелік для можливих характеристик
enum PlayerStat {
  strength, // Сила
  agility, // Спритність
  intelligence, // Інтелект
  perception, // Сприйняття
  stamina, // Витривалість
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
  Map<PhysicalActivity, dynamic>? baselinePhysicalPerformance;
  bool initialSurveyCompleted;
  late QuestDifficulty playerRank;

  late int maxHp;
  late int currentHp;
  late int maxMp;
  late int currentMp;

  static const int baseHpPerLevel = 10;
  static const int hpPerStaminaPoint = 5;
  static const int baseMpPerLevel = 5;
  static const int mpPerIntelligencePoint = 3;

  PlayerModel({
    this.playerName = "Мисливець",
    this.level = 1,
    this.xp = 0,
    Map<PlayerStat, int>? initialStats,
    this.availableStatPoints = 0,
    this.baselinePhysicalPerformance,
    this.initialSurveyCompleted = false,
    this.playerRank = QuestDifficulty.F,
    int? loadedCurrentHp,
    int? loadedCurrentMp,
  }) : stats = initialStats ??
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
    int stamina = stats[PlayerStat.stamina] ?? 0;
    int intelligence = stats[PlayerStat.intelligence] ?? 0;

    maxHp = (level * baseHpPerLevel) + (stamina * hpPerStaminaPoint) + 50;
    maxMp =
        (level * baseMpPerLevel) + (intelligence * mpPerIntelligencePoint) + 20;
  }

  // Метод, що викликається при підвищенні рівня (з PlayerProvider)
  void onLevelUp() {
    _calculateAndUpdateHpMp();
    currentHp = maxHp;
    currentMp = maxMp;
  }

  // Метод, що викликається при зміні характеристик (з PlayerProvider)
  void onStatsChanged() {
    int oldMaxHp = maxHp;
    int oldMaxMp = maxMp;
    _calculateAndUpdateHpMp();
    double hpPercentage = (oldMaxHp > 0) ? currentHp / oldMaxHp : 1.0;
    double mpPercentage = (oldMaxMp > 0) ? currentMp / oldMaxMp : 1.0;
    currentHp = (maxHp * hpPercentage).round().clamp(0, maxHp);
    currentMp = (maxMp * mpPercentage).round().clamp(0, maxMp);
  }

  void takeDamage(int amount) {
    currentHp = max(0, currentHp - amount);
  }

  void restoreHp(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  void useMp(int amount) {
    currentMp = max(0, currentMp - amount);
  }

  void restoreMp(int amount) {
    currentMp = min(maxMp, currentMp + amount);
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
    if (level <= 0) return 100;
    if (level == 1) return 100;
    return (pow(level, 1.8) * 75 + (level - 1) * 150).round();
  }

  static String getStatName(PlayerStat stat) {
    switch (stat) {
      case PlayerStat.strength:
        return "Сила";
      case PlayerStat.agility:
        return "Спритність";
      case PlayerStat.intelligence:
        return "Інтелект";
      case PlayerStat.perception:
        return "Сприйняття";
      case PlayerStat.stamina:
        return "Витривалість";
      default:
        return "";
    }
  }

  // Конвертація в JSON
  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'stats': stats.map((key, value) => MapEntry(key.name, value)),
      'availableStatPoints': availableStatPoints,
      'baselinePhysicalPerformance': baselinePhysicalPerformance?.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'initialSurveyCompleted': initialSurveyCompleted,
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
      loadedStats = (json['stats'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          PlayerStat.values.byName(key),
          value as int,
        ),
      );
    } else {
      print(
          "Warning: 'stats' field is missing or not a map in JSON. Using default stats.");
      loadedStats = {
        PlayerStat.strength: 5,
        PlayerStat.agility: 5,
        PlayerStat.intelligence: 5,
        PlayerStat.perception: 5,
        PlayerStat.stamina: 5
      };
    }

    Map<PhysicalActivity, dynamic>? loadedBaselinePerformance;
    if (json['baselinePhysicalPerformance'] != null &&
        json['baselinePhysicalPerformance'] is Map) {
      try {
        Map<String, dynamic> decodedMap =
            Map<String, dynamic>.from(json['baselinePhysicalPerformance']);
        loadedBaselinePerformance = decodedMap.map((key, value) =>
            MapEntry(PhysicalActivity.values.byName(key), value));
      } catch (e) {
        print("Error decoding baselinePhysicalPerformance from JSON: $e");
      }
    }

    return PlayerModel(
      playerName: json['playerName'] as String? ?? "Мисливець",
      level: json['level'] as int? ?? 1,
      xp: json['xp'] as int? ?? 0,
      initialStats: loadedStats,
      availableStatPoints: json['availableStatPoints'] as int? ?? 0,
      initialSurveyCompleted: json['initialSurveyCompleted'] as bool? ?? false,
      playerRank: json['playerRank'] != null &&
              (json['playerRank'] as String).isNotEmpty
          ? QuestDifficulty.values.byName(json['playerRank'] as String)
          : QuestDifficulty.F,
      baselinePhysicalPerformance: loadedBaselinePerformance,
      loadedCurrentHp: json['currentHp'] as int?,
      loadedCurrentMp: json['currentMp'] as int?,
    );
  }
}
