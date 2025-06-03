// lib/models/player_model.dart
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
  int level;
  int xp;
  int xpToNextLevel;
  Map<PlayerStat, int> stats; // Використовуємо PlayerStat як ключ
  int availableStatPoints; // Очки для розподілу при підвищенні рівня

  PlayerModel({
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 100, // Початкове значення XP для наступного рівня
    Map<PlayerStat, int>? initialStats, // Дозволяємо передати початкові стат-и
    this.availableStatPoints = 0,
  }) : stats =
            initialStats ?? // Якщо initialStats не передано, встановлюємо по дефолту
                {
                  PlayerStat.strength: 5,
                  PlayerStat.agility: 5,
                  PlayerStat.intelligence: 5,
                  PlayerStat.perception: 5,
                  PlayerStat.stamina: 5,
                };

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

  // Тут пізніше можна додати методи toJson/fromJson для збереження/завантаження
}
