import 'dart:math';
import 'dart:async';

import 'package:awakening/models/item_model.dart';
import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/providers/item_provider.dart';
import 'package:awakening/providers/quest_provider.dart';
import 'package:awakening/services/cloud_logger_service.dart';
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

  final CloudLoggerService _logger = CloudLoggerService();

  Map<PlayerStat, int>? _modifiedStats;
  final Map<String, DateTime> _skillCooldowns = {};
  int? _modifiedMaxHp;
  int? _modifiedMaxMp;

  Map<PlayerStat, int> get finalStats => _modifiedStats ?? player.stats;
  int get finalMaxHp => _modifiedMaxHp ?? player.maxHp;
  int get finalMaxMp => _modifiedMaxMp ?? player.maxMp;

  SkillProvider? _skillProvider;

  ItemProvider? _itemProvider;

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

  PlayerProvider(this._auth, SkillProvider? skillProvider, this._itemProvider,
      PlayerModel? initialPlayer) {
    _skillProvider = skillProvider;
    _player = initialPlayer;
    _uid = _auth?.currentUser?.uid;
    if (_uid != null) {
      _loadPlayerData();
    } else {
      _isLoading = false;
    }
  }

  void update(
    FirebaseAuth? auth,
    SkillProvider? skillProvider,
    ItemProvider? itemProvider,
    PlayerModel? newPlayer,
  ) {
    _skillProvider = skillProvider;
    _itemProvider = itemProvider;
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

  DateTime? getSkillCooldownEndTime(String skillId) {
    return _skillCooldowns[skillId];
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
        _logger.writeLog(
            message: "Player data for UID $_uid loaded from Firestore.",
            payload: {
              'action': 'load_player_data',
              'uid': _uid,
              'player': _player!.toJson(),
            });
      } else {
        _player = PlayerModel();
        _logger.writeLog(
            message: "No player data in Firestore for UID $_uid, creating new player.",
            payload: {
              'action': 'create_new_player',
              'uid': _uid,
            });
        await _savePlayerData();
      }
    } catch (e) {
      _logger.writeLog(
          message:
              "Error loading player data from Firestore: $e. Creating new player.",
          severity: CloudLogSeverity.warning);
      _player = PlayerModel();
      await _savePlayerData();
    }

    if (_player != null) {
      _calculateFinalStats();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _calculateFinalStats() {
    if (_player == null || _skillProvider == null) return;

    _modifiedStats = Map.from(_player!.stats);
    double maxHpMultiplier = 1.0;
    double maxMpMultiplier = 1.0;

    for (String skillId in _player!.learnedSkillIds) {
      final skill = _skillProvider!.getSkillById(skillId);
      if (skill != null && skill.skillType == SkillType.passive) {
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
            default:
              break;
          }
        });
      }
    }

    _player!.activeBuffs.removeWhere((skillId, endTimeString) {
      return DateTime.parse(endTimeString).isBefore(DateTime.now());
    });

    for (String skillId in _player!.activeBuffs.keys) {
      final skill = _skillProvider!.getSkillById(skillId);
      if (skill != null && skill.skillType == SkillType.activeBuff) {
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
  }

  Future<void> _savePlayerData() async {
    if (_playerDocRef == null || _player == null) {
      _logger.writeLog(
        message:
            "Player data not ready for saving yet (no UID or player model).",
        severity: CloudLogSeverity.warning,
      );
      return;
    }
    try {
      await _playerDocRef!.set(_player!.toJson());
      _logger.writeLog(
        message: "Player data for UID $_uid saved to Firestore.",
        payload: {
          'action': 'save_player_data',
          'uid': _uid,
        },
      );
    } catch (e) {
      _logger.writeLog(
        message: "Error saving player data to Firestore: $e",
        severity: CloudLogSeverity.error,
        payload: {
          'action': 'save_player_data_error',
          'uid': _uid,
          'error': e.toString(),
        },
      );
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
      _calculateFinalStats();

      slog?.addMessage("Рівень підвищено! Новий рівень: ${_player!.level}",
          MessageType.levelUp);
      int pointsGained = _player!.availableStatPoints - oldAvailablePoints;
      if (pointsGained > 0) {
        slog?.addMessage("Отримано $pointsGained оч. характеристик!",
            MessageType.statsIncreased);
      }
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
        _calculateFinalStats();
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

  bool activateSkill(String skillId, SystemLogProvider slog) {
    if (_player == null || _skillProvider == null) return false;

    final skill = _skillProvider!.getSkillById(skillId);
    if (skill == null || skill.skillType != SkillType.activeBuff) return false;

    if (!_player!.learnedSkillIds.contains(skillId)) return false;

    if (_player!.activeBuffs.containsKey(skillId)) {
      slog.addMessage(
          "Ефект '${skill.name}' вже активний.", MessageType.warning);
      return false;
    }

    final cooldownEndTime = _skillCooldowns[skillId];
    if (cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now())) {
      slog.addMessage(
          "Навичка '${skill.name}' перезаряджається.", MessageType.warning);
      return false;
    }

    final mpCost = skill.mpCost?.toInt() ?? 0;
    if (_player!.currentMp < mpCost) {
      slog.addMessage(
          "Недостатньо MP для '${skill.name}'.", MessageType.warning);
      return false;
    }

    _player!.useMp(mpCost);

    final buffEndTime =
        DateTime.now().add(skill.duration ?? const Duration(seconds: 0));
    _player!.activeBuffs[skillId] = buffEndTime.toIso8601String();

    if (skill.cooldown != null) {
      _skillCooldowns[skillId] = DateTime.now().add(skill.cooldown!);
    }

    slog.addMessage("Активовано: '${skill.name}'!", MessageType.info);

    _calculateFinalStats();
    _savePlayerData();
    notifyListeners();
    return true;
  }

  bool spendStatPoint(
      PlayerStat stat, int amountToSpend, SystemLogProvider slog) {
    if (_isLoading || _player == null) return false;
    if (_player!.availableStatPoints >= amountToSpend && amountToSpend > 0) {
      _player!.stats[stat] = (_player!.stats[stat] ?? 0) + amountToSpend;
      _player!.availableStatPoints -= amountToSpend;
      _calculateFinalStats();
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
      if (_player!.initialSurveyCompleted) {
        return;
      }
    }

    bool statsAffectingHpMpChanged = false;
    bonuses.forEach((stat, bonusAmount) {
      if (bonusAmount > 0) {
        _player!.stats[stat] = (_player!.stats[stat] ?? 0) + bonusAmount;
        if (stat == PlayerStat.stamina || stat == PlayerStat.intelligence) {
          statsAffectingHpMpChanged = true;
        }
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
        _logger.writeLog(
          message: "Player document for UID $_uid deleted from Firestore.",
          payload: {'action': 'delete_player_document', 'uid': _uid},
        );
      } catch (e) {
        _logger.writeLog(
          message: "Error deleting player document: $e",
          severity: CloudLogSeverity.error,
          payload: {
            'action': 'delete_player_document_error',
            'uid': _uid,
            'error': e.toString(),
          },
        );
      }
    }
    _player = PlayerModel();
    _isLoading = false;
    _justLeveledUp = false;
    await _savePlayerData();
    notifyListeners();
    _logger.writeLog(
      message: "Player data has been reset locally and saved.",
      payload: {'action': 'reset_player_data', 'uid': _uid},
    );
  }

  void awardNewRank(QuestDifficulty newRank, SystemLogProvider slog) {
    if (_player!.playerRank.index < newRank.index) {
      _player!.playerRank = newRank;
      slog.addMessage(
          "Ранг Мисливця підвищено! Новий ранг: ${QuestModel.getQuestDifficultyName(_player!.playerRank)}",
          MessageType.rankUp);
      _savePlayerData();
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
      final nextIndex =
          min(currentRank.index + 1, QuestDifficulty.values.length - 1);
      final targetRankForChallenge = QuestDifficulty.values[nextIndex];

      if (targetRankForChallenge.index > nextPotentialRankByLevel.index) {
        slog.addMessage(
            "Рівень ${player.level} недостатній для випробування на ранг ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}.",
            MessageType.info);
        return false;
      }

      slog.addMessage(
          "Запит на Випробування на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг...",
          MessageType.info);

      if (_itemProvider != null) {
        await questProvider.fetchAndAddGeneratedQuest(
            playerProvider: playerProvider,
            itemProvider: _itemProvider!,
            slog: slog,
            questType: QuestType.rankUpChallenge,
            customInstruction:
                "Це дуже важливе Рангове Випробування для гравця ${playerProvider.player.playerName} (Рівень: ${playerProvider.player.level}, Поточний Ранг: ${QuestModel.getQuestDifficultyName(currentRank)}) для переходу на ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Ранг. Завдання має бути унікальним, складним (відповідати рангу ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}), епічним та перевіряти навички мисливця. Наприклад, перемогти міні-боса, зачистити невелике підземелля (описово), знайти рідкісний артефакт або врятувати когось. Вкажи в описі, що це офіційне випробування від Асоціації Мисливців (або аналогічної організації в світі Solo Leveling).");
        return true;
      } else {
        slog.addMessage("ItemProvider недоступний для створення квесту.",
            MessageType.error);
        return false;
      }
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

  void addItemToInventory(String itemId, int quantity) {
    if (_player == null || _itemProvider == null) return;

    final templateItem = _itemProvider!.getItemById(itemId);
    if (templateItem == null) {
      _logger.writeLog(
        message: "Attempted to add non-existent item: $itemId",
        severity: CloudLogSeverity.warning,
        payload: {
          'action': 'add_non_existent_item_warning',
          'itemId': itemId,
          'quantity': quantity,
          'uid': _uid
        },
      );
      return;
    }

    // Шукаємо, чи є вже такий предмет в інвентарі (якщо він stackable)
    final existingItemIndex = _player!.inventory.indexWhere(
        (item) => item['itemId'] == itemId && templateItem.isStackable);

    if (existingItemIndex != -1) {
      final existingItemData = _player!.inventory[existingItemIndex];
      final newQuantity = (existingItemData['quantity'] as int) + quantity;
      _player!.inventory[existingItemIndex] = {
        'itemId': itemId,
        'quantity': newQuantity
      };
    } else {
      _player!.inventory.add({'itemId': itemId, 'quantity': quantity});
    }

    _logger.writeLog(
      message: "Added $quantity x $itemId to inventory for player $_uid.",
      payload: {
        'action': 'add_item_to_inventory',
        'itemId': itemId,
        'quantity': quantity,
        'uid': _uid
      },
    );
    _savePlayerData();
    notifyListeners();
  }

  void useItem(String itemId, SystemLogProvider slog) {
    if (_player == null || _itemProvider == null) return;

    final itemIndex =
        _player!.inventory.indexWhere((item) => item['itemId'] == itemId);
    if (itemIndex == -1) return;

    final templateItem = _itemProvider!.getItemById(itemId);
    if (templateItem == null) return;

    // Застосовуємо ефекти
    bool itemUsed = false;
    templateItem.effects.forEach((effect, value) {
      switch (effect) {
        case ItemEffectType.restoreHp:
          restorePlayerHp(value.toInt());
          itemUsed = true;
          slog.addMessage("Відновлено ${value.toInt()} HP.", MessageType.info);
          break;
        case ItemEffectType.restoreMp:
          restorePlayerMp(value.toInt());
          itemUsed = true;
          slog.addMessage("Відновлено ${value.toInt()} MP.", MessageType.info);
          break;
        // ... інші ефекти
        default:
          break;
      }
    });

    // Якщо предмет був використаний (витратний матеріал), зменшуємо кількість
    if (itemUsed && templateItem.type == ItemType.potion) {
      final itemData = _player!.inventory[itemIndex];
      final newQuantity = (itemData['quantity'] as int) - 1;

      if (newQuantity <= 0) {
        _player!.inventory.removeAt(itemIndex);
      } else {
        _player!.inventory[itemIndex] = {
          'itemId': itemId,
          'quantity': newQuantity
        };
      }
    }

    _savePlayerData();
    notifyListeners();
  }
}
