import 'dart:math';

import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/providers/quest_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quest_model.dart';
import 'system_log_provider.dart';
import 'skill_provider.dart';
import '../models/skill_model.dart';

class PlayerProvider with ChangeNotifier {
  PlayerModel? _player;
  bool _isLoading = true;
  bool _justLeveledUp = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth? _auth;
  String? _uid;

  Map<PlayerStat, int>? _modifiedStats;
  int? _modifiedMaxHp;
  int? _modifiedMaxMp;

  Map<PlayerStat, int> get finalStats => _modifiedStats ?? player.stats;
  int get finalMaxHp => _modifiedMaxHp ?? player.maxHp;
  int get finalMaxMp => _modifiedMaxMp ?? player.maxMp;

  SkillProvider? _skillProvider;

  PlayerModel get player {
    _player ??= PlayerModel();
    return _player!;
  }

  String? getUserId() {
    return _uid;
  }

  bool get isLoading => _isLoading;
  bool get justLeveledUp {
    if (_justLeveledUp) {
      _justLeveledUp = false;
      return true;
    }
    return false;
  }

  PlayerProvider(
      this._auth, SkillProvider? skillProvider, PlayerModel? initialPlayer) {
    _skillProvider = skillProvider;
    _player = initialPlayer;
    _uid = _auth?.currentUser?.uid;
    if (_uid != null) {
      _loadPlayerData();
    } else {
      _isLoading = false;
    }
  }

  void update(FirebaseAuth? auth, SkillProvider? skillProvider,
      PlayerModel? newPlayer) {
    _skillProvider = skillProvider;
    if (auth?.currentUser?.uid != _uid) {
      _uid = auth?.currentUser?.uid;
      if (_uid != null) {
        _isLoading = true;
        notifyListeners();
        _loadPlayerData();
      } else {
        _player = null;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  DocumentReference? get _playerDocRef {
    if (_uid == null) return null;
    return _firestore.collection('players').doc(_uid);
  }

  Future<void> _loadPlayerData() async {
    if (_playerDocRef == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      DocumentSnapshot playerSnapshot = await _playerDocRef!.get();
      if (playerSnapshot.exists && playerSnapshot.data() != null) {
        _player = PlayerModel.fromJson(
            playerSnapshot.data()! as Map<String, dynamic>);
        print("Player data for UID $_uid loaded from Firestore.");
      } else {
        _player = PlayerModel();
        print(
            "No player data in Firestore for UID $_uid, creating new player.");
        await _savePlayerData();
      }
    } catch (e) {
      print(
          "Error loading player data from Firestore: $e. Creating new player.");
      _player = PlayerModel();
      await _savePlayerData();
    }

    if (_player != null) {
      _applyPassiveSkillBonuses();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _applyPassiveSkillBonuses() {
    if (_player == null || _skillProvider == null) return;

    _modifiedStats = Map.from(_player!.stats);

    double maxHpMultiplier = 1.0;
    double maxMpMultiplier = 1.0;
    double xpGainMultiplier = 1.0;

    for (String skillId in _player!.learnedSkillIds) {
      final skill = _skillProvider!.getSkillById(skillId);
      if (skill == null) {
        print("Warning: Learned skill $skillId not found in skill provider");
        continue;
      }
      if (skill.skillType == SkillType.passive) {
        skill.effects.forEach((effectType, value) {
          switch (effectType) {
            case SkillEffectType.addStrength:
              _modifiedStats![PlayerStat.strength] =
                  (_modifiedStats![PlayerStat.strength] ?? 0) + value.toInt();
              break;
            case SkillEffectType.addStamina:
              _modifiedStats![PlayerStat.stamina] =
                  (_modifiedStats![PlayerStat.stamina] ?? 0) + value.toInt();
              break;
            case SkillEffectType.multiplyMaxHp:
              maxHpMultiplier *= (1 + value / 100.0);
              break;
            case SkillEffectType.multiplyMaxMp:
              maxMpMultiplier *= (1 + value / 100.0);
              break;
            case SkillEffectType.multiplyXpGain:
              xpGainMultiplier *= (1 + value / 100.0);
              break;
            default:
              break;
          }
        });
      }
    }

    int stamina = _modifiedStats![PlayerStat.stamina] ?? 0;
    int intelligence = _modifiedStats![PlayerStat.intelligence] ?? 0;
    _modifiedMaxHp = (((_player!.level * PlayerModel.baseHpPerLevel) +
                (stamina * PlayerModel.hpPerStaminaPoint) +
                50) *
            maxHpMultiplier)
        .round();
    _modifiedMaxMp = (((_player!.level * PlayerModel.baseMpPerLevel) +
                (intelligence * PlayerModel.mpPerIntelligencePoint) +
                20) *
            maxMpMultiplier)
        .round();

    _player!.currentHp = min(_player!.currentHp, _modifiedMaxHp!);
    _player!.currentMp = min(_player!.currentMp, _modifiedMaxMp!);

    print(
        "Passive skill bonuses applied. Final Strength: ${_modifiedStats![PlayerStat.strength]}");
  }

  Future<void> _savePlayerData() async {
    if (_playerDocRef == null || _player == null) {
      print("Player data not ready for saving yet (no UID or player model).");
      return;
    }
    try {
      await _playerDocRef!.set(_player!.toJson());
      print("Player data for UID $_uid saved to Firestore.");
    } catch (e) {
      print("Error saving player data to Firestore: $e");
    }
  }

  void addXp(int amount, SystemLogProvider slog) {
    if (_isLoading || _player == null) return;
    _player!.xp += amount;
    _checkLevelUp(slog);
    _savePlayerData();
    if (_justLeveledUp || amount > 0) {
      notifyListeners();
    }
  }

  void _checkLevelUp(SystemLogProvider? slog) {
    if (_player == null) return;
    bool leveledUpThisCheck = false;
    QuestDifficulty oldRank = _player!.playerRank; // Зберігаємо старий ранг
    int oldAvailablePoints = _player!.availableStatPoints;

    while (_player!.xp >= _player!.xpToNextLevel) {
      _player!.xp -= _player!.xpToNextLevel;
      _player!.level++;
      _player!.xpToNextLevel = PlayerModel.calculateXpForLevel(_player!.level);
      _player!.availableStatPoints += 3;
      if (_player!.level % 5 == 0) {
        _player!.availableSkillPoints += 1;
        slog?.addMessage("Отримано 1 очко навичок!", MessageType.info);
      }
      leveledUpThisCheck = true;
    }

    if (leveledUpThisCheck) {
      _justLeveledUp = true;
      _player!.onLevelUp();
      _applyPassiveSkillBonuses();

      slog?.addMessage("Рівень підвищено! Новий рівень: ${_player!.level}",
          MessageType.levelUp);
      int pointsGained = _player!.availableStatPoints - oldAvailablePoints;
      if (pointsGained > 0) {
        slog?.addMessage("Отримано $pointsGained оч. характеристик!",
            MessageType.statsIncreased);
      }
      // Логіка зміни рангу тепер в awardNewRank або requestRankUpChallenge
      // _checkForAvailableRankUpChallenge();
    }
  }

  bool learnSkill(String skillId, SystemLogProvider slog) {
    if (_player == null || _skillProvider == null) return false;

    final skill = _skillProvider!.getSkillById(skillId);
    if (skill == null) return false;

    if (_player!.learnedSkillIds.contains(skillId)) {
      slog.addMessage(
          "Навичка '${skill.name}' вже вивчена.", MessageType.warning);
      return false;
    }

    if (_skillProvider!
        .canLearnSkill(_player!, skillId, _player!.availableSkillPoints)) {
      _player!.availableSkillPoints -= skill.skillPointCost;
      _player!.learnedSkillIds.add(skillId);
      if (skill.skillType == SkillType.passive) {
        _applyPassiveSkillBonuses();
      }

      slog.addMessage("Вивчено навичку: '${skill.name}'!", MessageType.levelUp);
      _savePlayerData();
      notifyListeners();
      return true;
    } else {
      slog.addMessage("Недостатньо умов для вивчення навички '${skill.name}'.",
          MessageType.warning);
      return false;
    }
  }

  bool spendStatPoint(
      PlayerStat stat, int amountToSpend, SystemLogProvider slog) {
    if (_isLoading || _player == null) return false;
    if (_player!.availableStatPoints >= amountToSpend && amountToSpend > 0) {
      _player!.stats[stat] = (_player!.stats[stat] ?? 0) + amountToSpend;
      _player!.availableStatPoints -= amountToSpend;
      _applyPassiveSkillBonuses();
      if (stat == PlayerStat.stamina || stat == PlayerStat.intelligence) {
        _player!.onStatsChanged();
      }
      slog.addMessage(
          "${PlayerModel.getStatName(stat)} збільшено на $amountToSpend. Поточне значення: ${_player!.stats[stat]}",
          MessageType.statsIncreased);
      _savePlayerData();
      notifyListeners();
      return true;
    }
    slog.addMessage("Недостатньо очок.", MessageType.warning);
    return false;
  }

  void setPlayerName(String name) {
    if (_isLoading || name.trim().isEmpty) return;
    _player!.playerName = name.trim();
    _savePlayerData();
    notifyListeners();
  }

  void updateBaselinePerformance(Map<PhysicalActivity, dynamic> performance) {
    if (_isLoading) return;
    _player!.baselinePhysicalPerformance = Map.from(performance);
    _savePlayerData();
    notifyListeners();
  }

  void applyInitialStatBonuses(Map<PlayerStat, int> bonuses) {
    if (_isLoading || _player!.initialSurveyCompleted) {
      if (_player!.initialSurveyCompleted)
        print("Initial stat bonuses already applied.");
      return;
    }

    bool statsAffectingHpMpChanged = false;
    bonuses.forEach((stat, bonusAmount) {
      if (bonusAmount > 0) {
        _player!.stats[stat] = (_player!.stats[stat] ?? 0) + bonusAmount;
        if (stat == PlayerStat.stamina || stat == PlayerStat.intelligence) {
          statsAffectingHpMpChanged = true;
        }
        print(
            "Applied +$bonusAmount bonus to ${PlayerModel.getStatName(stat)} from survey.");
      }
    });

    if (statsAffectingHpMpChanged) {
      _player!.onStatsChanged();
    }

    _savePlayerData();
    notifyListeners();
  }

  void setInitialSurveyCompleted(bool completed) {
    if (_isLoading) return;
    _player!.initialSurveyCompleted = completed;
    _savePlayerData();
    notifyListeners();
  }

  void takePlayerDamage(int amount) {
    if (_isLoading) return;
    _player!.takeDamage(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerHp(int amount) {
    if (_isLoading) return;
    _player!.restoreHp(amount);
    _savePlayerData();
    notifyListeners();
  }

  void usePlayerMp(int amount) {
    if (_isLoading) return;
    _player!.useMp(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerMp(int amount) {
    if (_isLoading) return;
    _player!.restoreMp(amount);
    _savePlayerData();
    notifyListeners();
  }

  Future<void> resetPlayerData() async {
    if (_playerDocRef != null) {
      try {
        await _playerDocRef!.delete();
        print("Player document for UID $_uid deleted from Firestore.");
      } catch (e) {
        print("Error deleting player document: $e");
      }
    }
    _player = PlayerModel();
    _isLoading = false;
    _justLeveledUp = false;
    await _savePlayerData();
    notifyListeners();
    print("Player data has been reset in Firestore.");
  }

  void awardNewRank(QuestDifficulty newRank, SystemLogProvider slog) {
    if (_player!.playerRank.index < newRank.index) {
      // Перевіряємо, чи новий ранг дійсно вищий
      _player!.playerRank = newRank;
      slog.addMessage(
          "Ранг Мисливця підвищено! Новий ранг: ${QuestModel.getQuestDifficultyName(_player!.playerRank)}",
          MessageType.rankUp);
      print("RANK UP! Awarded new rank: ${_player!.playerRank.name}");
      _savePlayerData(); // Зберігаємо зміни
      notifyListeners();
      // _checkForAvailableRankUpChallenge(); // Перевіряємо, чи доступний наступний ранг-ап
    }
  }

  Future<bool> requestRankUpChallenge(QuestProvider questProvider,
      SystemLogProvider slog, PlayerProvider playerProvider) async {
    if (_isLoading) return false;

    QuestDifficulty currentRank = _player!.playerRank;
    QuestDifficulty nextPotentialRankByLevel =
        PlayerModel.calculateRankByLevel(_player!.level);
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
