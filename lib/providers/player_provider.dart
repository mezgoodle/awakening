import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item_model.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import '../models/skill_model.dart';
import '../models/system_message_model.dart';
import '../repositories/player_repository.dart';
import '../services/app_logger_service.dart';
import 'item_provider.dart';
import 'quest_provider.dart';
import 'skill_provider.dart';
import 'system_log_provider.dart';

class PlayerProvider with ChangeNotifier {
  PlayerModel? _player;
  bool _isLoading = true;
  bool _hasLevelUpEvent = false;

  final PlayerRepository _playerRepository;
  final FirebaseAuth? _auth;
  String? _uid;

  final AppLoggerService _logger = AppLoggerService();

  Map<PlayerStat, int>? _modifiedStats;
  int? _modifiedMaxHp;
  int? _modifiedMaxMp;
  double _xpMultiplier = 1.0;
  double _mpCostReduction = 0.0;
  double _cooldownReduction = 0.0;

  SkillProvider? _skillProvider;
  ItemProvider? _itemProvider;

  Map<PlayerStat, int> get finalStats => _modifiedStats ?? player.stats;
  int get finalMaxHp => _modifiedMaxHp ?? player.maxHp;
  int get finalMaxMp => _modifiedMaxMp ?? player.maxMp;
  double get xpMultiplier => _xpMultiplier;

  PlayerModel get player {
    _player ??= PlayerModel();
    return _player!;
  }

  String? getUserId() => _uid;
  bool get isLoading => _isLoading;

  bool consumeLevelUpEvent() {
    if (_hasLevelUpEvent) {
      _hasLevelUpEvent = false;
      return true;
    }
    return false;
  }

  PlayerProvider(
    this._auth,
    SkillProvider? skillProvider,
    this._itemProvider,
    PlayerModel? initialPlayer, {
    PlayerRepository? playerRepository,
  })  : _playerRepository = playerRepository ?? PlayerRepository(),
        _skillProvider = skillProvider,
        _player = initialPlayer {
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
  ) {
    final prevSkillLoading = _skillProvider?.isLoading;
    _skillProvider = skillProvider;
    _itemProvider = itemProvider;

    final newUid = auth?.currentUser?.uid;
    if (newUid != _uid) {
      _uid = newUid;
      if (_uid != null) {
        _isLoading = true;
        notifyListeners();
        _loadPlayerData();
      } else {
        _player = null;
        _isLoading = false;
        notifyListeners();
      }
    } else if (prevSkillLoading == true &&
        skillProvider != null &&
        !skillProvider.isLoading &&
        _player != null) {
      // Recalculate stats once skills catalog has finished loading
      _calculateFinalStats();
      notifyListeners();
    }
  }

  DateTime? getSkillCooldownEndTime(String skillId) {
    if (_player == null) return null;
    final endTimeStr = _player!.skillCooldowns[skillId];
    if (endTimeStr == null) return null;
    return DateTime.tryParse(endTimeStr);
  }

  Future<void> _loadPlayerData() async {
    if (_uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final loaded = await _playerRepository.fetchPlayer(_uid!);
      if (loaded != null) {
        _player = loaded;
        _logger.writeLog(
          message: "Player data for UID $_uid loaded.",
          payload: {
            "name": _player!.playerName,
            "level": _player!.level,
            "xp": _player!.xp,
          },
        );
      } else {
        _player = PlayerModel();
        _logger.writeLog(
          message: "No existing player in Firestore for UID $_uid. Created initial profile.",
        );
        await _savePlayerData();
      }
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error loading player data: $e",
        severity: LogSeverity.warning,
        error: e,
        stackTrace: stack,
      );
      _player = PlayerModel();
      await _savePlayerData();
    }

    if (_player != null) {
      _cleanExpiredBuffsAndCooldowns();
      _calculateFinalStats();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _cleanExpiredBuffsAndCooldowns() {
    if (_player == null) return;
    final now = DateTime.now();

    _player!.activeBuffs.removeWhere((skillId, endTimeString) {
      final endTime = DateTime.tryParse(endTimeString);
      return endTime == null || endTime.isBefore(now);
    });

    _player!.skillCooldowns.removeWhere((skillId, endTimeString) {
      final endTime = DateTime.tryParse(endTimeString);
      return endTime == null || endTime.isBefore(now);
    });
  }

  void _calculateFinalStats() {
    if (_player == null) return;
    _cleanExpiredBuffsAndCooldowns();

    _modifiedStats = Map.from(_player!.stats);
    double maxHpMultiplier = 1.0;
    double maxMpMultiplier = 1.0;
    _xpMultiplier = 1.0;
    _mpCostReduction = 0.0;
    _cooldownReduction = 0.0;

    void applyEffect(SkillEffectType effectType, double value) {
      switch (effectType) {
        case SkillEffectType.addStrength:
          _modifiedStats![PlayerStat.strength] =
              (_modifiedStats![PlayerStat.strength] ?? 0) + value.toInt();
          break;
        case SkillEffectType.addAgility:
          _modifiedStats![PlayerStat.agility] =
              (_modifiedStats![PlayerStat.agility] ?? 0) + value.toInt();
          break;
        case SkillEffectType.addIntelligence:
          _modifiedStats![PlayerStat.intelligence] =
              (_modifiedStats![PlayerStat.intelligence] ?? 0) + value.toInt();
          break;
        case SkillEffectType.addPerception:
          _modifiedStats![PlayerStat.perception] =
              (_modifiedStats![PlayerStat.perception] ?? 0) + value.toInt();
          break;
        case SkillEffectType.addStamina:
          _modifiedStats![PlayerStat.stamina] =
              (_modifiedStats![PlayerStat.stamina] ?? 0) + value.toInt();
          break;
        case SkillEffectType.multiplyMaxHp:
          maxHpMultiplier *= (1.0 + value / 100.0);
          break;
        case SkillEffectType.multiplyMaxMp:
          maxMpMultiplier *= (1.0 + value / 100.0);
          break;
        case SkillEffectType.multiplyXpGain:
          _xpMultiplier *= (1.0 + value / 100.0);
          break;
        case SkillEffectType.reduceMpCost:
          _mpCostReduction = min(0.9, _mpCostReduction + (value / 100.0));
          break;
        case SkillEffectType.reduceCooldown:
          _cooldownReduction = min(0.9, _cooldownReduction + (value / 100.0));
          break;
      }
    }

    if (_skillProvider != null && !_skillProvider!.isLoading) {
      // 1. Passive skills
      for (final skillId in _player!.learnedSkillIds) {
        final skill = _skillProvider!.getSkillById(skillId);
        if (skill != null && skill.skillType == SkillType.passive) {
          skill.effects.forEach(applyEffect);
        }
      }

      // 2. Active buffs
      for (final skillId in _player!.activeBuffs.keys) {
        final skill = _skillProvider!.getSkillById(skillId);
        if (skill != null && skill.skillType == SkillType.activeBuff) {
          skill.effects.forEach(applyEffect);
        }
      }
    }

    final int stamina = _modifiedStats![PlayerStat.stamina] ?? 0;
    final int intelligence = _modifiedStats![PlayerStat.intelligence] ?? 0;

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
    if (_uid == null || _player == null) return;
    try {
      await _playerRepository.savePlayer(_uid!, _player!);
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error saving player data: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
    }
  }

  void addXp(int amount, SystemLogProvider slog) {
    if (_isLoading || _player == null) return;
    final int effectiveXp = (amount * _xpMultiplier).round();
    _player!.xp += effectiveXp;
    _checkLevelUp(slog);
    _savePlayerData();
    notifyListeners();
  }

  void _checkLevelUp(SystemLogProvider? slog) {
    if (_player == null) return;
    bool leveledUpThisCheck = false;
    final int oldAvailablePoints = _player!.availableStatPoints;

    while (_player!.xp >= _player!.xpToNextLevel) {
      _player!.xp -= _player!.xpToNextLevel;
      _player!.level++;
      _player!.xpToNextLevel = PlayerModel.calculateXpForLevel(_player!.level);
      _player!.availableStatPoints += 3;
      if (_player!.level % 5 == 0) {
        _player!.availableSkillPoints += 1;
        slog?.addMessage("Received 1 skill point!", MessageType.info);
      }
      leveledUpThisCheck = true;
    }

    if (leveledUpThisCheck) {
      _hasLevelUpEvent = true;
      _player!.onLevelUp();
      _calculateFinalStats();

      slog?.addMessage(
        "Level up! Reached Level ${_player!.level}!",
        MessageType.levelUp,
      );
      final int pointsGained = _player!.availableStatPoints - oldAvailablePoints;
      if (pointsGained > 0) {
        slog?.addMessage(
          "Gained $pointsGained stat points!",
          MessageType.statsIncreased,
        );
      }
    }
  }

  bool learnSkill(String skillId, SystemLogProvider slog) {
    if (_player == null || _skillProvider == null) return false;

    final skill = _skillProvider!.getSkillById(skillId);
    if (skill == null) return false;

    if (_player!.learnedSkillIds.contains(skillId)) {
      slog.addMessage(
        "Skill '${skill.name}' is already learned.",
        MessageType.warning,
      );
      return false;
    }

    if (_skillProvider!
        .canLearnSkill(_player!, skillId, _player!.availableSkillPoints)) {
      _player!.availableSkillPoints -= skill.skillPointCost;
      _player!.learnedSkillIds.add(skillId);
      if (skill.skillType == SkillType.passive) {
        _calculateFinalStats();
      }

      slog.addMessage("Learned skill: '${skill.name}'!", MessageType.levelUp);
      _savePlayerData();
      notifyListeners();
      return true;
    } else {
      slog.addMessage(
        "Requirements not met to learn '${skill.name}'.",
        MessageType.warning,
      );
      return false;
    }
  }

  bool activateSkill(String skillId, SystemLogProvider slog) {
    if (_player == null || _skillProvider == null) return false;

    final skill = _skillProvider!.getSkillById(skillId);
    if (skill == null || skill.skillType != SkillType.activeBuff) return false;
    if (!_player!.learnedSkillIds.contains(skillId)) return false;

    _cleanExpiredBuffsAndCooldowns();

    if (_player!.activeBuffs.containsKey(skillId)) {
      slog.addMessage(
        "Skill '${skill.name}' is already active.",
        MessageType.warning,
      );
      return false;
    }

    final cooldownEndTime = getSkillCooldownEndTime(skillId);
    if (cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now())) {
      slog.addMessage(
        "Skill '${skill.name}' is still on cooldown.",
        MessageType.warning,
      );
      return false;
    }

    final baseMpCost = skill.mpCost?.toInt() ?? 0;
    final effectiveMpCost = (baseMpCost * (1.0 - _mpCostReduction)).round();

    if (_player!.currentMp < effectiveMpCost) {
      slog.addMessage(
        "Not enough MP to activate '${skill.name}'.",
        MessageType.warning,
      );
      return false;
    }

    _player!.useMp(effectiveMpCost);

    final buffDuration = skill.duration ?? const Duration(seconds: 0);
    final buffEndTime = DateTime.now().add(buffDuration);
    _player!.activeBuffs[skillId] = buffEndTime.toIso8601String();

    if (skill.cooldown != null) {
      final effectiveCooldownSeconds =
          (skill.cooldown!.inSeconds * (1.0 - _cooldownReduction)).round();
      final cooldownEndTime =
          DateTime.now().add(Duration(seconds: effectiveCooldownSeconds));
      _player!.skillCooldowns[skillId] = cooldownEndTime.toIso8601String();
    }

    slog.addMessage("Activated skill: '${skill.name}'!", MessageType.info);

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
        "${PlayerModel.getStatName(stat)} increased by $amountToSpend. Total: ${_player!.stats[stat]}",
        MessageType.statsIncreased,
      );
      _savePlayerData();
      notifyListeners();
      return true;
    }
    slog.addMessage("Not enough stat points available.", MessageType.warning);
    return false;
  }

  void setPlayerName(String name) {
    if (_isLoading || name.trim().isEmpty) return;
    _player!.playerName = name.trim();
    _savePlayerData();
    notifyListeners();
  }

  void updateBaselinePerformance(Map<PhysicalActivity, dynamic> performance) {
    if (_isLoading || _player == null) return;
    _player!.baselinePhysicalPerformance = Map.from(performance);
    _savePlayerData();
    notifyListeners();
  }

  void takePlayerDamage(int amount) {
    if (_isLoading || _player == null) return;
    _player!.takeDamage(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerHp(int amount) {
    if (_isLoading || _player == null) return;
    _player!.restoreHp(amount, maxAllowedHp: finalMaxHp);
    _savePlayerData();
    notifyListeners();
  }

  void usePlayerMp(int amount) {
    if (_isLoading || _player == null) return;
    _player!.useMp(amount);
    _savePlayerData();
    notifyListeners();
  }

  void restorePlayerMp(int amount) {
    if (_isLoading || _player == null) return;
    _player!.restoreMp(amount, maxAllowedMp: finalMaxMp);
    _savePlayerData();
    notifyListeners();
  }

  Future<void> resetPlayerData() async {
    if (_uid != null) {
      try {
        await _playerRepository.deletePlayer(_uid!);
      } catch (e) {
        _logger.writeLog(
          message: "Error deleting player document: $e",
          severity: LogSeverity.error,
        );
      }
    }
    _player = PlayerModel();
    _isLoading = false;
    _hasLevelUpEvent = false;
    await _savePlayerData();
    _calculateFinalStats();
    notifyListeners();
  }

  void awardNewRank(QuestDifficulty newRank, SystemLogProvider slog) {
    if (_player != null && _player!.playerRank.index < newRank.index) {
      _player!.playerRank = newRank;
      slog.addMessage(
        "Rank upgraded! New Rank: ${QuestModel.getQuestDifficultyName(_player!.playerRank)}",
        MessageType.rankUp,
      );
      _savePlayerData();
      notifyListeners();
    }
  }

  Future<bool> requestRankUpChallenge(
      QuestProvider questProvider, SystemLogProvider slog) async {
    if (_isLoading || _player == null) return false;

    final QuestDifficulty currentRank = _player!.playerRank;
    final QuestDifficulty nextPotentialRank =
        PlayerModel.calculateRankByLevel(_player!.level);
    final bool hasActiveRankUpQuest = questProvider.activeQuests
        .any((q) => q.type == QuestType.rankUpChallenge);

    if (nextPotentialRank.index > currentRank.index && !hasActiveRankUpQuest) {
      final nextIndex =
          min(currentRank.index + 1, QuestDifficulty.values.length - 1);
      final targetRankForChallenge = QuestDifficulty.values[nextIndex];

      if (targetRankForChallenge.index > nextPotentialRank.index) {
        slog.addMessage(
          "Level ${_player!.level} is not sufficient for ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Rank challenge.",
          MessageType.info,
        );
        return false;
      }

      slog.addMessage(
        "Requesting Rank Up Challenge for ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Rank...",
        MessageType.info,
      );

      if (_itemProvider != null) {
        await questProvider.fetchAndAddGeneratedQuest(
          playerProvider: this,
          itemProvider: _itemProvider!,
          slog: slog,
          questType: QuestType.rankUpChallenge,
          customInstruction:
              "Official Hunter Association Rank Promotion Trial for ${_player!.playerName} from ${QuestModel.getQuestDifficultyName(currentRank)}-Rank to ${QuestModel.getQuestDifficultyName(targetRankForChallenge)}-Rank. Epic, demanding, and definitive test of Hunter competence.",
        );
        return true;
      } else {
        slog.addMessage(
          "Item catalog unavailable to generate challenge.",
          MessageType.error,
        );
        return false;
      }
    } else if (hasActiveRankUpQuest) {
      slog.addMessage(
        "You already have an active Rank Up Challenge!",
        MessageType.info,
      );
    } else {
      slog.addMessage(
        "Requirements for the next Rank Up Challenge are not yet met (Level: ${_player!.level}, Current Rank: ${_player!.playerRank.name}).",
        MessageType.info,
      );
    }
    return false;
  }

  void addItemToInventory(String itemId, int quantity) {
    if (_player == null || _itemProvider == null) return;

    final templateItem = _itemProvider!.getItemById(itemId);
    final isStackable = templateItem?.isStackable ?? true;

    final existingIndex = _player!.inventory.indexWhere(
        (entry) => entry.itemId == itemId && isStackable);

    if (existingIndex != -1) {
      final existing = _player!.inventory[existingIndex];
      _player!.inventory[existingIndex] = QuestItemReward(
        itemId: itemId,
        quantity: existing.quantity + quantity,
      );
    } else {
      _player!.inventory.add(QuestItemReward(
        itemId: itemId,
        quantity: quantity,
      ));
    }

    _logger.writeLog(
      message: "Added $quantity x $itemId to player inventory.",
    );
    _savePlayerData();
    notifyListeners();
  }

  void useItem(String itemId, SystemLogProvider slog) {
    if (_player == null || _itemProvider == null) return;

    final itemIndex =
        _player!.inventory.indexWhere((entry) => entry.itemId == itemId);
    if (itemIndex == -1) return;

    final templateItem = _itemProvider!.getItemById(itemId);
    if (templateItem == null) return;

    bool itemUsed = false;
    templateItem.effects.forEach((effect, value) {
      switch (effect) {
        case ItemEffectType.restoreHp:
          restorePlayerHp(value.toInt());
          itemUsed = true;
          slog.addMessage("Restored ${value.toInt()} HP.", MessageType.info);
          break;
        case ItemEffectType.restoreMp:
          restorePlayerMp(value.toInt());
          itemUsed = true;
          slog.addMessage("Restored ${value.toInt()} MP.", MessageType.info);
          break;
        case ItemEffectType.restoreHpPercent:
          final amount = (finalMaxHp * (value / 100.0)).round();
          restorePlayerHp(amount);
          itemUsed = true;
          slog.addMessage(
              "Restored $amount HP (${value.toInt()}%).", MessageType.info);
          break;
        case ItemEffectType.restoreMpPercent:
          final amount = (finalMaxMp * (value / 100.0)).round();
          restorePlayerMp(amount);
          itemUsed = true;
          slog.addMessage(
              "Restored $amount MP (${value.toInt()}%).", MessageType.info);
          break;
      }
    });

    if (itemUsed && templateItem.type == ItemType.potion) {
      final currentEntry = _player!.inventory[itemIndex];
      final newQuantity = currentEntry.quantity - 1;
      if (newQuantity <= 0) {
        _player!.inventory.removeAt(itemIndex);
      } else {
        _player!.inventory[itemIndex] = QuestItemReward(
          itemId: itemId,
          quantity: newQuantity,
        );
      }
    }

    _savePlayerData();
    notifyListeners();
  }
}
