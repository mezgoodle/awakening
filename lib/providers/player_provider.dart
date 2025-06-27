// lib/providers/player_provider.dart
// Прибираємо SharedPreferences, додаємо Firestore
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/providers/quest_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Імпорт Firestore
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart'; // Для QuestDifficulty
import 'system_log_provider.dart';

class PlayerProvider with ChangeNotifier {
  late PlayerModel _player;
  bool _isLoading = true;
  bool _justLeveledUp = false;

  // Firestore instance та посилання на документ гравця
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DocumentReference _playerDocRef; // Буде ініціалізовано

  // У нас один гравець, тому ID документа може бути фіксованим
  // Або, якщо планується автентифікація, ID буде UID користувача
  static const String _playerId =
      'mainPlayerDocument'; // ID документа в Firestore

  PlayerModel get player => _player;
  bool get isLoading => _isLoading;
  bool get justLeveledUp {
    if (_justLeveledUp) {
      _justLeveledUp = false;
      return true;
    }
    return false;
  }

  PlayerProvider() {
    // Шлях: колекція 'players' -> документ з ID '_playerId'
    _playerDocRef = _firestore.collection('players').doc(_playerId);
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    _isLoading = true;
    // notifyListeners(); // Уникаємо

    try {
      DocumentSnapshot playerSnapshot = await _playerDocRef.get();
      if (playerSnapshot.exists && playerSnapshot.data() != null) {
        _player = PlayerModel.fromJson(
            playerSnapshot.data()! as Map<String, dynamic>);
        print("Player data loaded from Firestore.");
      } else {
        _player = PlayerModel(); // Створюємо нового гравця
        print("No player data in Firestore, creating new player. Saving...");
        await _savePlayerData(); // Зберігаємо нового гравця
      }
    } catch (e) {
      print(
          "Error loading player data from Firestore: $e. Creating new player.");
      _player = PlayerModel(); // Створюємо нового при помилці
      await _savePlayerData(); // Спробуємо зберегти, щоб створити документ
    }

    _isLoading = false;
    // _checkForAvailableRankUpChallenge(); // Якщо є ця логіка
    notifyListeners();
  }

  Future<void> _savePlayerData() async {
    if (_isLoading && _player == null) {
      // Запобіжник, якщо _player ще не ініціалізований
      print("Player data not ready for saving yet.");
      return;
    }
    try {
      await _playerDocRef.set(_player
          .toJson()); // set перезапише документ або створить, якщо його немає
      print("Player data saved to Firestore.");
    } catch (e) {
      print("Error saving player data to Firestore: $e");
    }
  }

  // Всі методи, що змінюють _player, тепер викликають _savePlayerData()
  void addXp(int amount, SystemLogProvider slog) {
    if (_isLoading) return;
    _player.xp += amount;
    _checkLevelUp(slog);
    _savePlayerData();
    if (_justLeveledUp || amount > 0) {
      notifyListeners();
    }
  }

  void _checkLevelUp(SystemLogProvider? slog) {
    bool leveledUpThisCheck = false;
    QuestDifficulty oldRank = _player.playerRank; // Зберігаємо старий ранг
    int oldAvailablePoints = _player.availableStatPoints;

    while (_player.xp >= _player.xpToNextLevel) {
      _player.xp -= _player.xpToNextLevel;
      _player.level++;
      _player.xpToNextLevel = PlayerModel.calculateXpForLevel(_player.level);
      _player.availableStatPoints += 3;
      leveledUpThisCheck = true;
    }

    if (leveledUpThisCheck) {
      _justLeveledUp = true;
      _player.onLevelUp(); // Оновлення HP/MP

      slog?.addMessage("Рівень підвищено! Новий рівень: ${_player.level}",
          MessageType.levelUp);
      int pointsGained = _player.availableStatPoints - oldAvailablePoints;
      if (pointsGained > 0) {
        slog?.addMessage("Отримано $pointsGained оч. характеристик!",
            MessageType.statsIncreased);
      }
      // Логіка зміни рангу тепер в awardNewRank або requestRankUpChallenge
      // _checkForAvailableRankUpChallenge();
    }
  }

  bool spendStatPoint(
      PlayerStat stat, int amountToSpend, SystemLogProvider slog) {
    if (_isLoading) return false;
    if (_player.availableStatPoints >= amountToSpend && amountToSpend > 0) {
      _player.stats[stat] = (_player.stats[stat] ?? 0) + amountToSpend;
      _player.availableStatPoints -= amountToSpend;
      if (stat == PlayerStat.stamina || stat == PlayerStat.intelligence) {
        _player.onStatsChanged();
      }
      slog.addMessage(
          "${PlayerModel.getStatName(stat)} збільшено на $amountToSpend (розподіл очок). Поточне значення: ${_player.stats[stat]}",
          MessageType.statsIncreased);
      _savePlayerData();
      notifyListeners();
      return true;
    }
    slog.addMessage(
        "Недостатньо очок для збільшення ${PlayerModel.getStatName(stat)}.",
        MessageType.warning);
    return false;
  }

  void setPlayerName(String name) {
    if (_isLoading || name.trim().isEmpty) return;
    _player.playerName = name.trim();
    _savePlayerData();
    notifyListeners();
  }

  void updateBaselinePerformance(Map<PhysicalActivity, dynamic> performance) {
    if (_isLoading) return;
    _player.baselinePhysicalPerformance = Map.from(performance);
    _savePlayerData();
    notifyListeners();
  }

  void applyInitialStatBonuses(Map<PlayerStat, int> bonuses) {
    if (_isLoading || _player.initialSurveyCompleted) {
      if (_player.initialSurveyCompleted)
        print("Initial stat bonuses already applied.");
      return;
    }

    bool statsAffectingHpMpChanged = false;
    bonuses.forEach((stat, bonusAmount) {
      if (bonusAmount > 0) {
        _player.stats[stat] = (_player.stats[stat] ?? 0) + bonusAmount;
        if (stat == PlayerStat.stamina || stat == PlayerStat.intelligence) {
          statsAffectingHpMpChanged = true;
        }
        print(
            "Applied +$bonusAmount bonus to ${PlayerModel.getStatName(stat)} from survey.");
      }
    });

    if (statsAffectingHpMpChanged) {
      _player.onStatsChanged();
    }
    // _savePlayerData() буде викликаний в setInitialSurveyCompleted
    // але для певності, якщо setInitialSurveyCompleted не викликається одразу,
    // або якщо ця логіка зміниться, краще додати збереження і тут:
    _savePlayerData();
    notifyListeners(); // Повідомити про зміну статів
  }

  void setInitialSurveyCompleted(bool completed) {
    if (_isLoading) return;
    _player.initialSurveyCompleted = completed;
    _savePlayerData();
    notifyListeners();
  }

  void takePlayerDamage(int amount) {
    if (_isLoading) return;
    _player.takeDamage(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerHp(int amount) {
    if (_isLoading) return;
    _player.restoreHp(amount);
    _savePlayerData();
    notifyListeners();
  }

  void usePlayerMp(int amount) {
    if (_isLoading) return;
    _player.useMp(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerMp(int amount) {
    if (_isLoading) return;
    _player.restoreMp(amount);
    _savePlayerData();
    notifyListeners();
  }

  Future<void> resetPlayerData() async {
    try {
      await _playerDocRef.delete(); // Видаляємо документ з Firestore
      print("Player document deleted from Firestore.");
    } catch (e) {
      print(
          "Error deleting player document from Firestore: $e (may not exist yet)");
    }
    _player = PlayerModel();
    _isLoading = false;
    _justLeveledUp = false;
    await _savePlayerData(); // Зберігаємо нового гравця (створить документ)
    // _checkForAvailableRankUpChallenge();
    notifyListeners();
    print("Player data has been reset in Firestore.");
  }

  void awardNewRank(QuestDifficulty newRank, SystemLogProvider slog) {
    if (_player.playerRank.index < newRank.index) {
      // Перевіряємо, чи новий ранг дійсно вищий
      _player.playerRank = newRank;
      slog.addMessage(
          "Ранг Мисливця підвищено! Новий ранг: ${QuestModel.getQuestDifficultyName(_player.playerRank)}",
          MessageType.rankUp);
      print("RANK UP! Awarded new rank: ${_player.playerRank.name}");
      _savePlayerData(); // Зберігаємо зміни
      notifyListeners();
      // _checkForAvailableRankUpChallenge(); // Перевіряємо, чи доступний наступний ранг-ап
    }
  }

  Future<bool> requestRankUpChallenge(QuestProvider questProvider,
      SystemLogProvider slog, PlayerProvider playerProvider) async {
    if (_isLoading) return false;

    QuestDifficulty currentRank = _player.playerRank;
    QuestDifficulty nextPotentialRankByLevel =
        PlayerModel.calculateRankByLevel(_player.level);
    bool hasActiveRankUpQuest = questProvider.activeQuests
        .any((q) => q.type == QuestType.rankUpChallenge);

    if (nextPotentialRankByLevel.index > currentRank.index &&
        !hasActiveRankUpQuest) {
      QuestDifficulty targetRankForChallenge =
          QuestDifficulty.values[currentRank.index + 1];

      if (targetRankForChallenge.index > nextPotentialRankByLevel.index) {
        print(
            "Cannot request rank up challenge yet. Level ${player.level} too low for ${QuestModel.getQuestDifficultyName(targetRankForChallenge)} rank challenge (needs level for ${QuestModel.getQuestDifficultyName(nextPotentialRankByLevel)}).");
        slog.addMessage(
            "Рівень ${player.level} недостатній для випробування на ранг ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}.",
            MessageType.info);
        return false;
      }

      slog.addMessage(
          "Запит на Випробування на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг...",
          MessageType.info);

      // Зверни увагу, що fetchAndAddGeneratedQuest також має бути асинхронним
      // і, можливо, йому теж потрібен доступ до Firestore, якщо квести будуть там зберігатися.
      // Поки що він працює з SharedPreferences для квестів.
      await questProvider.fetchAndAddGeneratedQuest(
          playerProvider: playerProvider,
          slog: slog,
          questType: QuestType.rankUpChallenge,
          customInstruction:
              "Це дуже важливе Рангове Випробування для гравця ${playerProvider.player.playerName} (Рівень: ${playerProvider.player.level}, Поточний Ранг: ${QuestModel.getQuestDifficultyName(currentRank)}) для переходу на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг. Завдання має бути унікальним, складним (відповідати рангу ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}), епічним та перевіряти навички мисливця. Наприклад, перемогти міні-боса, зачистити невелике підземелля (описово), знайти рідкісний артефакт або врятувати когось. Вкажи в описі, що це офіційне випробування від Асоціації Мисливців (або аналогічної організації в світі Solo Leveling).");
      return true;
    } else if (hasActiveRankUpQuest) {
      slog.addMessage(
          "У вас вже є активне Рангове Випробування!", MessageType.info);
    } else {
      slog.addMessage(
          "Умови для наступного Рангового Випробування ще не виконані (Рівень: ${player.level}, Поточний ранг: ${player.playerRank.name}, Макс. ранг за рівнем: ${nextPotentialRankByLevel.name}).",
          MessageType.info);
    }
    return false;
  }

  // Метод _checkForAvailableRankUpChallenge (якщо він був і потрібен)
  // Тепер він не потрібен, бо логіка перевірки винесена в requestRankUpChallenge
  // та в UI для відображення кнопки.
}
