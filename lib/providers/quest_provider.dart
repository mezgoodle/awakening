import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import '../models/system_message_model.dart';
import '../repositories/player_repository.dart';
import '../repositories/quest_repository.dart';
import '../services/app_logger_service.dart';
import '../services/gemini_quest_service.dart';
import 'item_provider.dart';
import 'player_provider.dart';
import 'system_log_provider.dart';

class QuestProvider with ChangeNotifier {
  List<QuestModel> _activeQuests = [];
  List<QuestModel> _completedQuests = [];
  bool _isLoading = true;
  bool _isGeneratingQuest = false;

  final GeminiQuestService _geminiService;
  final QuestRepository _questRepository;
  final PlayerRepository _playerRepository;
  final AppLoggerService _logger = AppLoggerService();

  PlayerProvider? _playerProvider;
  ItemProvider? _itemProvider;

  List<QuestModel> get activeQuests => List.unmodifiable(_activeQuests);
  List<QuestModel> get completedQuests => List.unmodifiable(_completedQuests);
  bool get isLoading => _isLoading;
  bool get isGeneratingQuest => _isGeneratingQuest;

  QuestProvider({
    GeminiQuestService? geminiService,
    QuestRepository? questRepository,
    PlayerRepository? playerRepository,
  })  : _geminiService = geminiService ?? GeminiQuestService(),
        _questRepository = questRepository ?? QuestRepository(),
        _playerRepository = playerRepository ?? PlayerRepository();

  void update(PlayerProvider? playerProvider, ItemProvider? itemProvider) {
    _itemProvider = itemProvider;
    if (playerProvider != null &&
        _playerProvider != playerProvider &&
        !playerProvider.isLoading) {
      _playerProvider = playerProvider;
      _loadQuests();
    } else if (playerProvider == null) {
      _activeQuests = [];
      _completedQuests = [];
      notifyListeners();
    }
  }

  String? get _uid => _playerProvider?.getUserId();

  Future<void> _loadQuests() async {
    final uid = _uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _activeQuests = await _questRepository.fetchActiveQuests(uid);
      _completedQuests = await _questRepository.fetchCompletedQuests(uid);
      _sortActiveQuests();

      _logger.writeLog(
        message:
            "Loaded ${_activeQuests.length} active and ${_completedQuests.length} completed quests.",
      );
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error loading quests: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
      _activeQuests = [];
      _completedQuests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void _sortActiveQuests() {
    _activeQuests.sort((a, b) {
      if (a.type == QuestType.daily && b.type != QuestType.daily) return -1;
      if (a.type != QuestType.daily && b.type == QuestType.daily) return 1;
      final diffCompare = b.difficulty.index.compareTo(a.difficulty.index);
      if (diffCompare != 0) return diffCompare;
      return (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
    });
  }

  Future<void> addQuest(QuestModel quest, SystemLogProvider slog,
      {bool showSnackbar = true}) async {
    final uid = _uid;
    if (uid == null) return;

    _activeQuests.insert(0, quest);
    _sortActiveQuests();
    notifyListeners();

    slog.addMessage("New quest acquired: '${quest.title}'", MessageType.questAdded,
        showInSnackbar: showSnackbar);

    try {
      await _questRepository.saveQuest(uid, quest);
      _logger.writeLog(message: "Quest '${quest.title}' saved to Firestore.");
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error saving quest '${quest.title}': $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
      slog.addMessage("Failed to save quest '${quest.title}'.", MessageType.error);
      _activeQuests.removeWhere((q) => q.id == quest.id);
      notifyListeners();
    }
  }

  Future<void> completeQuest(String questId, PlayerProvider playerProvider,
      SystemLogProvider slog) async {
    final uid = _uid;
    if (uid == null) return;

    final questIndex = _activeQuests.indexWhere((q) => q.id == questId);
    if (questIndex == -1) return;

    QuestModel quest = _activeQuests[questIndex];
    _activeQuests.removeAt(questIndex);
    final completedQuest = quest.copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    _completedQuests.insert(0, completedQuest);
    notifyListeners();

    playerProvider.addXp(quest.xpReward, slog);

    if (quest.itemRewards != null && quest.itemRewards!.isNotEmpty) {
      for (final reward in quest.itemRewards!) {
        playerProvider.addItemToInventory(reward.itemId, reward.quantity);
        final itemName =
            _itemProvider?.getItemById(reward.itemId)?.name ?? reward.itemId;
        slog.addMessage(
          "Reward received: $itemName (x${reward.quantity})",
          MessageType.info,
          showInSnackbar: true,
        );
      }
    }

    if (quest.hpCostOnCompletion != null && quest.hpCostOnCompletion! > 0) {
      playerProvider.takePlayerDamage(quest.hpCostOnCompletion!);
      slog.addMessage(
        "Exerted tremendous physical effort! Lost ${quest.hpCostOnCompletion} HP.",
        MessageType.warning,
      );
    }

    if (quest.type == QuestType.rankUpChallenge) {
      final currentRank = playerProvider.player.playerRank;
      if (currentRank.index < QuestDifficulty.values.length - 1) {
        final awardedRank = QuestDifficulty.values[currentRank.index + 1];
        final maxRankByLevel =
            PlayerModel.calculateRankByLevel(playerProvider.player.level);
        if (awardedRank.index <= maxRankByLevel.index) {
          playerProvider.awardNewRank(awardedRank, slog);
        } else {
          slog.addMessage(
            "Cannot award ${QuestModel.getQuestDifficultyName(awardedRank)}-Rank: level requirement not met.",
            MessageType.warning,
          );
        }
      }
    }

    slog.addMessage(
      "Quest '${quest.title}' completed! +${quest.xpReward} XP.",
      MessageType.questCompleted,
    );

    try {
      await _questRepository.markQuestCompleted(
        uid,
        questId,
        completedQuest.completedAt ?? DateTime.now(),
      );
      _logger.writeLog(message: "Quest '$questId' marked as completed.");
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error updating quest '$questId' in Firestore: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
      slog.addMessage("Failed to update status for '${quest.title}'.", MessageType.error);
      _completedQuests.removeWhere((q) => q.id == questId);
      _activeQuests.insert(questIndex, quest);
      _sortActiveQuests();
      notifyListeners();
    }
  }

  Future<void> generateDailyQuestsIfNeeded(
      PlayerProvider playerProvider, SystemLogProvider slog) async {
    final uid = _uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final todayDateString = todayDateOnly.toIso8601String();

    final lastGen = playerProvider.player.lastDailyQuestGenerationDate;
    if (lastGen != null) {
      final lastGenDate = DateTime.tryParse(lastGen);
      if (lastGenDate != null &&
          lastGenDate.year == todayDateOnly.year &&
          lastGenDate.month == todayDateOnly.month &&
          lastGenDate.day == todayDateOnly.day) {
        slog.addMessage("Daily quests are already up to date for today.", MessageType.info);
        return;
      }
    }

    if (playerProvider.isLoading || (_itemProvider?.isLoading ?? true)) return;

    _isGeneratingQuest = true;
    notifyListeners();

    const int maxDailyQuests = 5;
    final existingDailyQuests =
        _activeQuests.where((q) => q.type == QuestType.daily).toList();
    final int questsToGenerateCount = maxDailyQuests - existingDailyQuests.length;

    if (questsToGenerateCount <= 0) {
      // Already has full daily quest roster, record the generation date
      playerProvider.player.lastDailyQuestGenerationDate = todayDateString;
      await _playerRepository.updateDailyQuestGenerationDate(uid, todayDateString);
      _isGeneratingQuest = false;
      notifyListeners();
      return;
    }

    final Set<PlayerStat> existingStats = existingDailyQuests
        .where((q) => q.targetStat != null)
        .map((q) => q.targetStat!)
        .toSet();

    final List<PlayerStat> neededStats =
        PlayerStat.values.where((stat) => !existingStats.contains(stat)).toList();
    neededStats.shuffle();

    final statsToGenerateFor = neededStats.take(questsToGenerateCount).toList();
    final currentPlayer = playerProvider.player;

    final List<Future<void>> futures = [];
    for (final stat in statsToGenerateFor) {
      futures.add(() async {
        final generatedQuest = await _geminiService.generateQuest(
          player: currentPlayer,
          questType: QuestType.daily,
          targetStat: stat,
          availableItemIds: _itemProvider?.allItemIds ?? [],
        );

        if (generatedQuest != null) {
          if (!_activeQuests.any((q) => q.title == generatedQuest.title)) {
            await addQuest(generatedQuest, slog, showSnackbar: false);
          }
        } else {
          final fallbackQuest = _getFallbackDailyQuestForStat(stat, currentPlayer);
          if (!_activeQuests.any((q) => q.title == fallbackQuest.title)) {
            await addQuest(fallbackQuest, slog, showSnackbar: false);
          }
        }
      }());
    }

    await Future.wait(futures);

    // Save generation date so quests don't regenerate infinitely
    playerProvider.player.lastDailyQuestGenerationDate = todayDateString;
    try {
      await _playerRepository.updateDailyQuestGenerationDate(uid, todayDateString);
    } catch (_) {}

    slog.addMessage("Daily quests assigned for today.", MessageType.info);
    _isGeneratingQuest = false;
    notifyListeners();
  }

  QuestModel _getFallbackDailyQuestForStat(
      PlayerStat stat, PlayerModel player) {
    final int xpBase = 15 + (player.level * 2);
    switch (stat) {
      case PlayerStat.strength:
        return QuestModel(
          title: "Shadow Conditioning: Push-ups",
          description:
              "Complete 3 sets of bodyweight push-ups focusing on steady cadence and strict posture.",
          xpReward: xpBase,
          type: QuestType.daily,
          difficulty: QuestDifficulty.E,
          targetStat: PlayerStat.strength,
        );
      case PlayerStat.agility:
        return QuestModel(
          title: "Shadow Agility: Mobility Drill",
          description:
              "Perform 15 minutes of dynamic body mobility and hip/shoulder stretching routines.",
          xpReward: xpBase,
          type: QuestType.daily,
          difficulty: QuestDifficulty.E,
          targetStat: PlayerStat.agility,
        );
      case PlayerStat.intelligence:
        return QuestModel(
          title: "Archive Research: Deep Study",
          description:
              "Dedicate 20 minutes of undisturbed focus to reading high-value non-fiction or solving analytical puzzles.",
          xpReward: xpBase,
          type: QuestType.daily,
          difficulty: QuestDifficulty.E,
          targetStat: PlayerStat.intelligence,
        );
      case PlayerStat.perception:
        return QuestModel(
          title: "Sensory Calibration: Mindful Scan",
          description:
              "Spend 15 minutes observing your immediate environment without digital distractions.",
          xpReward: xpBase,
          type: QuestType.daily,
          difficulty: QuestDifficulty.E,
          targetStat: PlayerStat.perception,
        );
      case PlayerStat.stamina:
        return QuestModel(
          title: "Endurance March: Cardio Pulse",
          description:
              "Complete a 20-minute brisk walk, light jog, or cycling session to raise cardiovascular endurance.",
          xpReward: xpBase,
          type: QuestType.daily,
          difficulty: QuestDifficulty.E,
          targetStat: PlayerStat.stamina,
        );
    }
  }

  Future<QuestModel?> fetchAndAddGeneratedQuest({
    required PlayerProvider playerProvider,
    required SystemLogProvider slog,
    required ItemProvider itemProvider,
    QuestType questType = QuestType.generated,
    PlayerStat? targetStat,
    String? customInstruction,
  }) async {
    if (_isGeneratingQuest) return null;

    _isGeneratingQuest = true;
    notifyListeners();

    final QuestModel? newQuest = await _geminiService.generateQuest(
      player: playerProvider.player,
      questType: questType,
      targetStat: targetStat,
      customPromptInstruction: customInstruction,
      availableItemIds: itemProvider.allItemIds,
    );

    if (newQuest != null) {
      await addQuest(newQuest, slog);
    } else {
      _logger.writeLog(
        message: "Failed to generate quest via Gemini API.",
        severity: LogSeverity.error,
      );
      slog.addMessage("Failed to generate quest. Please try again.", MessageType.error);
    }

    _isGeneratingQuest = false;
    notifyListeners();
    return newQuest;
  }

  Future<void> resetAllQuests() async {
    final uid = _uid;
    if (uid == null) return;

    _activeQuests.clear();
    _completedQuests.clear();
    notifyListeners();

    try {
      await _questRepository.deleteAllQuests(uid);
      _logger.writeLog(message: "All quests deleted from Firestore for user $uid.");
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error deleting all quests: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
    }
  }
}
