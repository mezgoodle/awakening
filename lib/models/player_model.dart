// lib/models/player_model.dart
import 'dart:math';
import 'package:flutter/foundation.dart'; // для @required, якщо потрібно, або просто для ChangeNotifier пізніше

// Перелік для можливих характеристик
enum PlayerStat {
  strength, // Сила
  agility, // Спритність
  intelligence, // Інтелект
  perception, // Сприйняття
  stamina, // Витривалість
}

class PlayerModel {
  String playerName = "Hunter";
  int level;
  int xp;
  int xpToNextLevel;
  Map<PlayerStat, int> stats; // Використовуємо PlayerStat як ключ
  int availableStatPoints; // Очки для розподілу при підвищенні рівня

  PlayerModel({
    this.playerName = "Hunter",
    this.level = 1,
    this.xp = 0,
    int? initialXpToNextLevel,
    Map<PlayerStat, int>? initialStats, // Дозволяємо передати початкові стат-и
    this.availableStatPoints = 0,
  })  : stats =
            initialStats ?? // Якщо initialStats не передано, встановлюємо по дефолту
                {
                  PlayerStat.strength: 5,
                  PlayerStat.agility: 5,
                  PlayerStat.intelligence: 5,
                  PlayerStat.perception: 5,
                  PlayerStat.stamina: 5,
                },
        xpToNextLevel = initialXpToNextLevel ?? calculateXpForLevel(1);

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

    return PlayerModel(
      playerName: json['playerName'] as String? ?? "Мисливець",
      level: json['level'] as int,
      xp: json['xp'] as int,
      initialXpToNextLevel: json['xpToNextLevel']
          as int, // Передаємо як initial, бо конструктор сам розрахує
      initialStats: loadedStats,
      availableStatPoints: json['availableStatPoints'] as int,
    );
  }
}
