// lib/providers/player_provider.dart
import 'dart:convert'; // Для jsonEncode/Decode
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_model.dart';

class PlayerProvider with ChangeNotifier {
  late PlayerModel _player; // Зробимо late, бо будемо завантажувати асинхронно
  bool _isLoading = true; // Для індикації завантаження
  bool _justLeveledUp = false; // Прапорець для UI

  PlayerModel get player => _player;
  bool get isLoading => _isLoading;
  bool get justLeveledUp {
    if (_justLeveledUp) {
      _justLeveledUp =
          false; // Скидаємо прапорець після того, як його прочитали
      return true;
    }
    return false;
  }

  PlayerProvider() {
    _player = PlayerModel(); // Початкове значення, поки йде завантаження
    _loadPlayerData();
  }

  static const String _playerDataKey = 'playerData';

  Future<void> _loadPlayerData() async {
    _isLoading = true;
    notifyListeners(); // Повідомити UI про початок завантаження

    final prefs = await SharedPreferences.getInstance();
    final String? playerDataString = prefs.getString(_playerDataKey);

    if (playerDataString != null) {
      try {
        final Map<String, dynamic> playerDataJson =
            jsonDecode(playerDataString);
        _player = PlayerModel.fromJson(playerDataJson);
      } catch (e) {
        print("Error loading player data: $e");
        // Якщо помилка декодування, створюємо гравця за замовчуванням
        _player = PlayerModel();
        // Можна також видалити пошкоджені дані
        // await prefs.remove(_playerDataKey);
      }
    } else {
      _player = PlayerModel(); // Створюємо нового гравця, якщо даних немає
    }

    _isLoading = false;
    notifyListeners(); // Повідомити UI про завершення завантаження
  }

  Future<void> _savePlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    final String playerDataString = jsonEncode(_player.toJson());
    await prefs.setString(_playerDataKey, playerDataString);
  }

  void addXp(int amount) {
    if (_isLoading) return; // Не додавати XP, поки дані завантажуються

    _player.xp += amount;
    print("Added $amount XP. Total XP: ${_player.xp}/${_player.xpToNextLevel}");
    _checkLevelUp();
    _savePlayerData(); // Зберігаємо після змін
    notifyListeners();
  }

  void _checkLevelUp() {
    bool leveledUpThisCheck = false;
    while (_player.xp >= _player.xpToNextLevel) {
      _player.xp -= _player.xpToNextLevel;
      _player.level++;
      _player.xpToNextLevel = PlayerModel.calculateXpForLevel(_player.level);
      _player.availableStatPoints += 3; // Даємо 3 очки за рівень
      leveledUpThisCheck = true;
      print(
          "LEVEL UP! New level: ${_player.level}. XP for next: ${_player.xpToNextLevel}. Points: ${_player.availableStatPoints}");
    }
    if (leveledUpThisCheck) {
      _justLeveledUp = true; // Встановлюємо прапорець
    }
  }

  bool increaseStat(PlayerStat stat, int amount) {
    if (_isLoading) return false;
    if (_player.availableStatPoints >= amount) {
      _player.stats[stat] = (_player.stats[stat] ?? 0) + amount;
      _player.availableStatPoints -= amount;
      _savePlayerData(); // Зберігаємо після змін
      notifyListeners();
      return true;
    }
    return false;
  }

  // Метод для зміни імені гравця (приклад)
  void setPlayerName(String name) {
    if (_isLoading) return;
    if (name.trim().isEmpty) {
      // Додамо перевірку на порожнє ім'я
      print("Player name cannot be empty.");
      // Можна тут кинути виняток або повернути false, щоб UI міг це обробити
      return;
    }
    _player.playerName = name.trim(); // .trim() для видалення зайвих пробілів
    _savePlayerData();
    notifyListeners();
  }

  void updateBaselinePerformance(Map<PhysicalActivity, dynamic> performance) {
    if (_isLoading) return;
    _player.baselinePhysicalPerformance =
        Map.from(performance); // Створюємо копію
    _savePlayerData();
    notifyListeners();
  }

  void setInitialSurveyCompleted(bool completed) {
    if (_isLoading) return;
    _player.initialSurveyCompleted = completed;
    _savePlayerData();
    notifyListeners();
  }

  // Метод для повного скидання прогресу (для тестування) - ОНОВЛЕНО
  Future<void> resetPlayerData() async {
    _player =
        PlayerModel(); // Скидаємо до дефолтного стану, включаючи initialSurveyCompleted = false
    _isLoading = false;
    _justLeveledUp = false;
    await _savePlayerData();
    notifyListeners();
    print("Player data has been reset.");
  }
}
