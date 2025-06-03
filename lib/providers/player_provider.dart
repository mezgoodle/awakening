// lib/providers/player_provider.dart
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';

class PlayerProvider with ChangeNotifier {
  PlayerModel _player = PlayerModel(); // Створюємо екземпляр нашої моделі

  PlayerModel get player => _player;

  // Приклад методу для оновлення гравця (пізніше тут буде більше логіки)
  void addXp(int amount) {
    _player.xp += amount;
    // Тут буде логіка перевірки на підвищення рівня
    // checkLevelUp();
    notifyListeners(); // Повідомляємо слухачів про зміни
  }

  // TODO: Додати методи для:
  // - checkLevelUp()
  // - increaseStat(PlayerStat stat)
  // - loadPlayerData() (для завантаження з SharedPreferences/Sqflite)
  // - savePlayerData() (для збереження)
}
