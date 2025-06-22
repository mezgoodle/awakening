// lib/providers/player_provider.dart
import 'dart:convert'; // Для jsonEncode/Decode
import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/providers/quest_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart'; // Для QuestDifficulty
import 'system_log_provider.dart';

class PlayerProvider with ChangeNotifier {
  late PlayerModel _player; // Зробимо late, бо будемо завантажувати асинхронно
  bool _isLoading = true; // Для індикації завантаження
  bool _justLeveledUp = false; // Прапорець для UI
  QuestModel? activeRankUpChallenge;

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
    _loadPlayerData().then((_) {
      _checkForAvailableRankUpChallenge();
    });
  }

  static const String _playerDataKey = 'playerData';

  @override
  Future<void> _loadPlayerData() async {
    _isLoading = true;

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
    _checkForAvailableRankUpChallenge();
    notifyListeners(); // Повідомити UI про завершення завантаження
  }

  Future<void> _savePlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    final String playerDataString = jsonEncode(_player.toJson());
    await prefs.setString(_playerDataKey, playerDataString);
  }

  void addXp(int amount, SystemLogProvider slog) {
    if (_isLoading) return; // Не додавати XP, поки дані завантажуються

    _player.xp += amount;
    print("Added $amount XP. Total XP: ${_player.xp}/${_player.xpToNextLevel}");
    bool previousLevelUpState = _justLeveledUp; // Зберігаємо попередній стан
    _checkLevelUp(slog);
    _savePlayerData(); // Зберігаємо після змін
    if (_justLeveledUp && !previousLevelUpState) {
      notifyListeners(); // Якщо _justLeveledUp щойно змінився
    } else if (!_justLeveledUp && !previousLevelUpState && amount > 0) {
      // Якщо XP додано, але рівня не було, все одно оновити XP бар
      notifyListeners();
    }
  }

  void _checkLevelUp(SystemLogProvider slog) {
    bool leveledUpThisCheck = false;
    QuestDifficulty oldRank = _player.playerRank; // Зберігаємо старий ранг
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
      _justLeveledUp = true;
      slog.addMessage("Рівень підвищено! Новий рівень: ${_player.level}",
          MessageType.levelUp);
      _checkForAvailableRankUpChallenge();

      if (_player.playerRank != oldRank) {
        slog.addMessage(
            "Ранг Мисливця підвищено! Новий ранг: ${_player.playerRank.name}",
            MessageType.rankUp);
        print("RANK UP! New rank: ${_player.playerRank.name}");
        // Тут можна буде додати системне повідомлення про підвищення рангу
      }
    }
  }

  void _checkForAvailableRankUpChallenge() {
    if (_isLoading)
      return; // Не перевіряти, якщо дані ще не завантажені повністю

    QuestDifficulty potentialNewRank =
        PlayerModel.calculateRankByLevel(_player.level);
    bool alreadyHasRankUpQuestForThisOrHigherRank = false;

    // Потрібен доступ до QuestProvider, щоб перевірити активні квести
    // Це створює залежність. Альтернатива - QuestProvider сам повідомляє PlayerProvider.
    // Або PlayerProvider зберігає ID активного rankUpChallenge.
    // Поки що, для простоти, припустимо, що UI ініціює запит на квест.

    // Логіка: якщо потенційний ранг за рівнем вищий за поточний ранг гравця,
    // і гравець ще не має активного квесту на цей (або вищий) ранг,
    // то він може отримати новий ранговий квест.
    // Цей метод просто оновлює стан, а UI/QuestProvider вже генерує квест.
    notifyListeners(); // Повідомити UI, що, можливо, щось змінилося
  }

  // Метод, який викликається, коли гравець успішно виконав RankUpChallenge
  void awardNewRank(QuestDifficulty newRank, SystemLogProvider slog) {
    if (newRank.index > _player.playerRank.index) {
      // Переконуємося, що новий ранг вищий
      _player.playerRank = newRank;
      slog.addMessage(
          "Ранг Мисливця підвищено! Новий ранг: ${QuestModel.getQuestDifficultyName(_player.playerRank)}",
          MessageType.rankUp);
      print("RANK UP! Awarded new rank: ${_player.playerRank.name}");
      _savePlayerData();
      notifyListeners();
      _checkForAvailableRankUpChallenge(); // Перевіряємо наступний можливий ранг-ап
    }
  }

  // Метод для ініціації генерації рангового квесту (викликається з UI або QuestProvider)
  // Повертає true, якщо запит на генерацію відправлено, false - якщо ні (наприклад, умови не виконані)
  Future<bool> requestRankUpChallenge(
      QuestProvider questProvider,
      SystemLogProvider slog,
      PlayerProvider
          playerProvider /*передаємо себе для доступу до player*/) async {
    if (_isLoading) return false;

    QuestDifficulty currentRank = _player.playerRank;
    QuestDifficulty nextPotentialRankByLevel =
        PlayerModel.calculateRankByLevel(_player.level);

    // Чи є вже активний квест на підвищення рангу?
    bool hasActiveRankUpQuest = questProvider.activeQuests
        .any((q) => q.type == QuestType.rankUpChallenge);

    if (nextPotentialRankByLevel.index > currentRank.index &&
        !hasActiveRankUpQuest) {
      // Визначаємо, на який ранг буде випробування
      // Це буде наступний ранг після поточного
      QuestDifficulty targetRankForChallenge =
          QuestDifficulty.values[currentRank.index + 1];

      // Переконуємося, що ми не намагаємося стрибнути через кілька рангів за рівнем
      // і що targetRankForChallenge не вищий, ніж максимально можливий за рівнем.
      if (targetRankForChallenge.index > nextPotentialRankByLevel.index) {
        print(
            "Cannot request rank up challenge yet. Level too low for the next rank after ${targetRankForChallenge.name}.");
        slog.addMessage(
            "Рівень недостатній для випробування на ранг ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}.",
            MessageType.info);
        return false;
      }

      slog.addMessage(
          "Запит на Випробування на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг...",
          MessageType.info);

      // Генерація квесту через QuestProvider, який викличе Gemini
      await questProvider.fetchAndAddGeneratedQuest(
          playerProvider: playerProvider, // Передаємо поточний PlayerProvider
          slog: slog,
          questType: QuestType.rankUpChallenge,
          // targetStat: null, // Рангові квести можуть бути комплексними
          customInstruction:
              "Це дуже важливе Рангове Випробування для гравця ${playerProvider.player.playerName} (Рівень: ${playerProvider.player.level}, Поточний Ранг: ${QuestModel.getQuestDifficultyName(currentRank)}) для переходу на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг. Завдання має бути унікальним, складним (відповідати рангу ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}), епічним та перевіряти навички мисливця. Наприклад, перемогти міні-боса, зачистити невелике підземелля (описово), знайти рідкісний артефакт або врятувати когось. Вкажи в описі, що це офіційне випробування від Асоціації Мисливців (або аналогічної організації в світі Solo Leveling).");
      // QuestProvider сам додасть квест і викличе notifyListeners
      return true; // Запит на генерацію був
    } else if (hasActiveRankUpQuest) {
      slog.addMessage(
          "У вас вже є активне Рангове Випробування!", MessageType.info);
    } else {
      slog.addMessage(
          "Умови для наступного Рангового Випробування ще не виконані.",
          MessageType.info);
    }
    return false;
  }

  bool increaseStat(PlayerStat stat, int amount, SystemLogProvider slog) {
    if (_isLoading) return false;
    if (_player.availableStatPoints >= amount) {
      _player.stats[stat] = (_player.stats[stat] ?? 0) + amount;
      _player.availableStatPoints -= amount;
      slog.addMessage("${PlayerModel.getStatName(stat)} збільшено на $amount.",
          MessageType.statsIncreased,
          showInSnackbar: false);
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

  // Метод для застосування бонусів до початкових характеристик
  void applyInitialStatBonuses(Map<PlayerStat, int> bonuses) {
    if (_isLoading) return;
    if (_player.initialSurveyCompleted) {
      // Застосовуємо бонуси тільки один раз
      print(
          "Initial stat bonuses already applied or survey not marked as completed yet for this logic.");
      return;
    }

    bonuses.forEach((stat, bonusAmount) {
      if (bonusAmount > 0) {
        _player.stats[stat] = (_player.stats[stat] ?? 0) + bonusAmount;
        print(
            "Applied +$bonusAmount bonus to ${PlayerModel.getStatName(stat)} from survey.");
      }
    });
    // _savePlayerData() буде викликаний в setInitialSurveyCompleted(true)
    // або можна викликати тут, якщо setInitialSurveyCompleted не викликається одразу після
    // Але в нашому випадку викликається, тому можна не дублювати.
    notifyListeners(); // Повідомити про зміну статів
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
