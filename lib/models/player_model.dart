// lib/models/player_model.dart
import 'dart:math';
import 'package:flutter/foundation.dart'; // для @required, якщо потрібно, або просто для ChangeNotifier пізніше
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
  runningDurationInMin, // Будемо питати тривалість бігу в хвилинах
  regularExercise,
}

class PlayerModel {
  String playerName;
  int level;
  int xp;
  late int xpToNextLevel;
  Map<PlayerStat, int> stats; // Ось ці стат-и ми будемо змінювати
  int availableStatPoints;
  Map<PhysicalActivity, dynamic>? baselinePhysicalPerformance;
  bool initialSurveyCompleted;
  late QuestDifficulty playerRank;

  PlayerModel({
    this.playerName = "Мисливець",
    this.level = 1, // Завжди починаємо з 1-го рівня
    this.xp = 0,
    Map<PlayerStat, int>? initialStats, // Дозволяємо передати для оновлення
    this.availableStatPoints = 0, // Початкові очки за замовчуванням 0
    this.baselinePhysicalPerformance,
    this.initialSurveyCompleted = false,
    this.playerRank = QuestDifficulty.F,
  }) : stats =
            initialStats ?? // Якщо initialStats передано, використовуємо їх, інакше дефолтні
                {
                  PlayerStat.strength: 5,
                  PlayerStat.agility: 5,
                  PlayerStat.intelligence: 5,
                  PlayerStat.perception: 5,
                  PlayerStat.stamina: 5,
                } {
    xpToNextLevel = calculateXpForLevel(level); // Розраховуємо для 1-го рівня
    // playerRank = _calculatePlayerRank(level); // Розраховуємо для 1-го рівня
  }

  // Метод для розрахунку рангу гравця на основі рівня
  static QuestDifficulty calculateRankByLevel(int level) {
    if (level < 5) return QuestDifficulty.F; // Додали F-ранг для початківців
    if (level < 10) return QuestDifficulty.E;
    if (level < 20) return QuestDifficulty.D;
    if (level < 30) return QuestDifficulty.C;
    if (level < 40) return QuestDifficulty.B;
    if (level < 50) return QuestDifficulty.A;
    return QuestDifficulty.S;
  }

  static int calculateXpForLevel(int level) {
    if (level <= 0) return 100; // Базове значення для невалідних рівнів
    if (level == 1) return 100; // Початкове XP для 2-го рівня
    // Формула: (level^1.8 * 75) + ((level-1) * 150)
    return (pow(level, 1.8) * 75 + (level - 1) * 150).round();
  }

  // Метод для зручного отримання назви характеристики (для UI)
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
      'stats': stats.map((key, value) =>
          MapEntry(key.name, value)), // enum.name для рядкового ключа
      'availableStatPoints': availableStatPoints,
      'baselinePhysicalPerformance': baselinePhysicalPerformance?.map(
        (key, value) =>
            MapEntry(key.name, value), // Зберігаємо enum ключ як рядок
      ),
      'initialSurveyCompleted': initialSurveyCompleted,
      'playerRank': playerRank.name, // Зберігаємо як рядок
    };
  }

  // Створення з JSON
  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    // Конвертація рядкових ключів статів назад в PlayerStat
    Map<PlayerStat, int> loadedStats =
        (json['stats'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        PlayerStat.values.byName(key), // PlayerStat.values.byName(stringKey)
        value as int,
      ),
    );

    Map<PhysicalActivity, dynamic>? loadedBaselinePerformance;
    if (json['baselinePhysicalPerformance'] != null) {
      loadedBaselinePerformance = (json['baselinePhysicalPerformance']
              as Map<String, dynamic>)
          .map(
        (key, value) {
          try {
            return MapEntry(PhysicalActivity.values.byName(key), value);
          } catch (e) {
            // Обробка можливої помилки, якщо enum змінився, а дані старі
            print(
                "Warning: Could not parse PhysicalActivity key '$key' from saved data.");
            return MapEntry(PhysicalActivity.pullUps,
                null); // Повертаємо щось, що потім можна відфільтрувати
          }
        },
      )..removeWhere((key, value) =>
          value == null &&
          key ==
              PhysicalActivity.pullUps); // Видаляємо, якщо ключ не розпарсився
      if (loadedBaselinePerformance.isEmpty) loadedBaselinePerformance = null;
    }

    int loadedLevel =
        json['level'] as int; // Отримуємо рівень для розрахунку рангу

    return PlayerModel(
      playerName: json['playerName'] as String? ?? "Мисливець",
      level: loadedLevel,
      xp: json['xp'] as int,
      initialStats: loadedStats,
      playerRank: json['playerRank'] != null
          ? QuestDifficulty.values.byName(json['playerRank'] as String)
          : QuestDifficulty.F,
      availableStatPoints: json['availableStatPoints'] as int,
      baselinePhysicalPerformance: loadedBaselinePerformance,
      initialSurveyCompleted: json['initialSurveyCompleted'] as bool? ??
          false, // Якщо поле відсутнє, вважаємо false
    );
  }
}
