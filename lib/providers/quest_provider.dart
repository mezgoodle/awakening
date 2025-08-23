import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quest_model.dart';
import '../models/player_model.dart';
import 'player_provider.dart';
import 'system_log_provider.dart';
import 'item_provider.dart';
import 'package:awakening/services/gemini_quest_service.dart';
import 'package:awakening/models/system_message_model.dart';
import 'package:awakening/services/cloud_logger_service.dart';

class QuestProvider with ChangeNotifier {
  List<QuestModel> _activeQuests = [];
  List<QuestModel> _completedQuests = [];
  bool _isLoading = true;
  final GeminiQuestService _geminiService = GeminiQuestService();
  bool _isGeneratingQuest = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PlayerProvider? _playerProvider;
  ItemProvider? _itemProvider;

  final CloudLoggerService _logger = CloudLoggerService();

  static const String _lastDailyQuestGenerationKey =
      'lastDailyQuestGenerationDate';

  List<QuestModel> get activeQuests => _activeQuests;
  List<QuestModel> get completedQuests => _completedQuests;
  bool get isLoading => _isLoading;
  bool get isGeneratingQuest => _isGeneratingQuest;

  QuestProvider();

  void update(PlayerProvider? playerProvider, ItemProvider? itemProvider) {
    if (playerProvider != null &&
        _playerProvider != playerProvider &&
        !playerProvider.isLoading) {
      _playerProvider = playerProvider;
      _itemProvider = itemProvider;
      _loadQuests();
    } else if (playerProvider == null) {
      _activeQuests.clear();
      _completedQuests.clear();
    }
  }

  CollectionReference? get _questsCollectionRef {
    final uid = _playerProvider?.getUserId();
    if (uid == null) return null;
    return _firestore.collection('players').doc(uid).collection('quests');
  }

  DocumentReference? get _playerDocRef {
    final uid = _playerProvider?.getUserId();
    if (uid == null) return null;
    return _firestore.collection('players').doc(uid);
  }

  Future<void> _loadQuests() async {
    if (_questsCollectionRef == null) {
      _logger.writeLog(
        message: "Cannot load quests, no user ID.",
        severity: CloudLogSeverity.error,
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final activeSnapshot = await _questsCollectionRef!
          .where('isCompleted', isEqualTo: false)
          .get();
      _activeQuests = activeSnapshot.docs
          .map(
              (doc) => QuestModel.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
      _logger.writeLog(
        message: "Loaded ${_activeQuests.length} active quests from Firestore.",
        payload: {
          "message": "Active quests loaded",
          "context": {"userId": _playerProvider?.getUserId()}
        },
      );

      final completedSnapshot = await _questsCollectionRef!
          .where('isCompleted', isEqualTo: true)
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();
      _completedQuests = completedSnapshot.docs
          .map(
              (doc) => QuestModel.fromJson(doc.data()! as Map<String, dynamic>))
          .toList();
      _logger.writeLog(
          message:
              "Loaded ${_completedQuests.length} completed quests from Firestore.",
          payload: {
            "message": "Completed quests loaded",
            "context": {"userId": _playerProvider?.getUserId()}
          });
    } catch (e) {
      _logger.writeLog(
        message: "Error loading quests from Firestore: $e",
        severity: CloudLogSeverity.error,
        payload: {
          "message": "Quest loading error",
          "context": {"userId": _playerProvider?.getUserId()}
        },
      );
      _activeQuests = [];
      _completedQuests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addQuest(QuestModel quest, SystemLogProvider slog,
      {bool showSnackbar = true}) async {
    if (_questsCollectionRef == null) return;

    _activeQuests.insert(0, quest);
    notifyListeners();
    slog.addMessage("Нове завдання: '${quest.title}'", MessageType.questAdded,
        showInSnackbar: showSnackbar);

    try {
      await _questsCollectionRef!.doc(quest.id).set(quest.toJson());
      _logger.writeLog(
        message: "Quest '${quest.title}' added to Firestore.",
        payload: {
          "message": "Quest added",
          "context": {
            "questId": quest.id,
            "questTitle": quest.title,
            "userId": _playerProvider?.getUserId()
          }
        },
      );
    } catch (e) {
      _logger.writeLog(
        message: "Error adding quest '${quest.title}' to Firestore: $e",
        severity: CloudLogSeverity.error,
        payload: {
          "message": "Quest addition error",
          "context": {
            "questId": quest.id,
            "questTitle": quest.title,
            "userId": _playerProvider?.getUserId(),
            "error": e.toString()
          }
        },
      );
      slog.addMessage(
          "Помилка збереження завдання '${quest.title}'", MessageType.error);
      _activeQuests.removeWhere((q) => q.id == quest.id);
      notifyListeners();
    }
  }

  Future<void> completeQuest(String questId, PlayerProvider playerProvider,
      SystemLogProvider slog) async {
    if (_questsCollectionRef == null) return;

    final questIndex = _activeQuests.indexWhere((q) => q.id == questId);
    if (questIndex != -1) {
      QuestModel quest = _activeQuests[questIndex];

      _activeQuests.removeAt(questIndex);
      quest.isCompleted = true;
      quest.completedAt = DateTime.now();
      _completedQuests.insert(0, quest);
      notifyListeners();

      playerProvider.addXp(quest.xpReward, slog);

      if (quest.itemRewards != null && quest.itemRewards!.isNotEmpty) {
        for (var itemData in quest.itemRewards!) {
          final itemId = itemData['itemId'] as String?;
          final quantity = itemData['quantity'] as int?;

          if (itemId != null && quantity != null && quantity > 0) {
            playerProvider.addItemToInventory(itemId, quantity);
            slog.addMessage(
                "Отримано предмет: $itemId (x$quantity)", MessageType.info,
                showInSnackbar: true);
          }
        }
      }

      if (quest.hpCostOnCompletion != null && quest.hpCostOnCompletion! > 0) {
        playerProvider.takePlayerDamage(quest.hpCostOnCompletion!);
        slog.addMessage(
            "Ви доклали значних зусиль! Втрачено ${quest.hpCostOnCompletion} HP.",
            MessageType.warning);
      }

      if (quest.type == QuestType.rankUpChallenge) {
        QuestDifficulty currentRank = playerProvider.player.playerRank;
        if (currentRank.index < QuestDifficulty.values.length - 1) {
          QuestDifficulty awardedRank =
              QuestDifficulty.values[currentRank.index + 1];
          QuestDifficulty maxRankByLevel =
              PlayerModel.calculateRankByLevel(playerProvider.player.level);
          if (awardedRank.index <= maxRankByLevel.index) {
            playerProvider.awardNewRank(awardedRank, slog);
          } else {
            slog.addMessage(
                "Неможливо присвоїти ранг ${QuestModel.getQuestDifficultyName(awardedRank)}, він вищий за максимально доступний за рівнем.",
                MessageType.warning);
          }
        }
      }

      slog.addMessage(
          "Завдання '${quest.title}' виконано! Нагорода: ${quest.xpReward} XP.",
          MessageType.questCompleted);

      try {
        await _questsCollectionRef!.doc(questId).update({
          'isCompleted': true,
          'completedAt': quest.completedAt?.toIso8601String(),
        });
        _logger.writeLog(
          message: "Quest '$questId' marked as completed in Firestore.",
          payload: {
            "message": "Quest completed",
            "context": {
              "questId": quest.id,
              "questTitle": quest.title,
              "userId": _playerProvider?.getUserId()
            }
          },
        );
      } catch (e) {
        _logger.writeLog(
          message: "Error updating quest '$questId' in Firestore: $e",
          severity: CloudLogSeverity.error,
          payload: {
            "message": "Quest update error",
            "context": {
              "questId": quest.id,
              "questTitle": quest.title,
              "userId": _playerProvider?.getUserId(),
              "error": e.toString()
            }
          },
        );
        slog.addMessage("Помилка оновлення статусу завдання '${quest.title}'",
            MessageType.error);
        _completedQuests.removeWhere((q) => q.id == questId);
        _activeQuests.insert(
            questIndex,
            quest
              ..isCompleted = false
              ..completedAt = null);
        notifyListeners();
      }
    }
  }

  Future<void> generateDailyQuestsIfNeeded(
      PlayerProvider playerProvider, SystemLogProvider slog) async {
    if (_playerDocRef == null) return;

    String? lastGenerationDateStr;
    try {
      final playerDoc = await _playerDocRef!.get();
      if (playerDoc.exists) {
        final data = playerDoc.data() as Map<String, dynamic>;
        lastGenerationDateStr = data[_lastDailyQuestGenerationKey];
      }
    } catch (e) {
      _logger.writeLog(
        message: "Could not read last daily quest generation date: $e",
        severity: CloudLogSeverity.error,
        payload: {
          "message": "Daily quest generation date read error",
          "context": {"userId": _playerProvider?.getUserId()}
        },
      );
    }

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    bool shouldGenerate = true;
    if (lastGenerationDateStr != null) {
      final lastGenerationDate = DateTime.parse(lastGenerationDateStr);
      if (lastGenerationDate.isAtSameMomentAs(todayDateOnly)) {
        shouldGenerate = false;
      }
    }

    if (shouldGenerate) {
      if (playerProvider.isLoading || (_itemProvider?.isLoading ?? true)) {
        return;
      }

      _isGeneratingQuest = true;
      notifyListeners();

      const int maxDailyQuests = 5;
      final existingDailyQuests =
          _activeQuests.where((q) => q.type == QuestType.daily).toList();
      final int questsToGenerateCount =
          maxDailyQuests - existingDailyQuests.length;

      if (questsToGenerateCount <= 0) {
        await _updateLastGenerationDate(todayDateOnly);
        _isGeneratingQuest = false;
        notifyListeners();
        return;
      }

      final Set<PlayerStat> existingQuestStats = existingDailyQuests
          .where((q) => q.targetStat != null)
          .map((q) => q.targetStat!)
          .toSet();

      final List<PlayerStat> neededQuestStats = PlayerStat.values
          .where((stat) => !existingQuestStats.contains(stat))
          .toList();

      neededQuestStats.shuffle();

      final statsToGenerateFor =
          neededQuestStats.take(questsToGenerateCount).toList();

      PlayerModel currentPlayer = playerProvider.player;
      List<Future<void>> questGenerationFutures = [];

      for (PlayerStat stat in statsToGenerateFor) {
        questGenerationFutures.add(_geminiService
            .generateQuest(
          player: currentPlayer,
          questType: QuestType.daily,
          targetStat: stat,
          availableItemIds: _itemProvider?.allItemIds ?? [],
        )
            .then((generatedQuest) async {
          if (generatedQuest != null) {
            // Переконуємося, що квест з таким ім'ям ще не існує
            if (!_activeQuests.any((q) => q.title == generatedQuest.title)) {
              await addQuest(generatedQuest, slog, showSnackbar: false);
            }
          } else {
            _logger.writeLog(
              message:
                  "Gemini failed to generate daily quest for ${stat.name}, using fallback.",
              severity: CloudLogSeverity.error,
              payload: {
                "message": "Gemini quest generation fallback",
                "context": {
                  "stat": stat.name,
                  "userId": _playerProvider?.getUserId()
                }
              },
            );

            final fallbackQuest =
                _getFallbackDailyQuestForStat(stat, currentPlayer);
            if (!_activeQuests.any((q) => q.title == fallbackQuest.title)) {
              await addQuest(fallbackQuest, slog, showSnackbar: false);
            }
          }
        }));
      }

      await Future.wait(questGenerationFutures);
      slog.addMessage("Щоденні завдання оновлено.", MessageType.info);

      await _updateLastGenerationDate(todayDateOnly);

      _isGeneratingQuest = false;
      notifyListeners();
    }
  }

  Future<void> _updateLastGenerationDate(DateTime date) async {
    if (_playerDocRef == null) return;
    try {
      await _playerDocRef!.set(
          {_lastDailyQuestGenerationKey: date.toIso8601String()},
          SetOptions(merge: true));
      // _logger.writeLog(
      //     message:
      //     "Daily quest generation date updated to ${date.toIso8601String()}",
      //     payload: {
      //       "message": "Daily quest generation date updated",
      //       "context": {"userId": _playerProvider?.getUserId(), "date": date}
      //     });
    } catch (e) {
      // _logger.writeLog(
      //   message: "Error updating daily quest generation date: $e",
      //   severity: CloudLogSeverity.error,
      //   payload: {
      //     "message": "Daily quest generation date update error",
      //     "context": {
      //       "userId": _playerProvider?.getUserId(),
      //       "error": e.toString()
      //     }
      //   },
      // );
    }
  }

  QuestModel _getFallbackDailyQuestForStat(
      PlayerStat stat, PlayerModel player) {
    int xpBase = 15 + (player.level * 2);
    switch (stat) {
      default:
        return QuestModel(
            title: "Default Daily",
            description: "Default desc",
            xpReward: xpBase,
            type: QuestType.daily,
            difficulty: QuestDifficulty.E,
            targetStat: stat);
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

    final List<String> availableItemIds = itemProvider.allItemIds;

    final newQuest = null;
    // QuestModel? newQuest = await _geminiService.generateQuest(
    //   player: playerProvider.player,
    //   questType: questType,
    //   targetStat: targetStat,
    //   customPromptInstruction: customInstruction,
    //   availableItemIds: availableItemIds,
    // );

    if (newQuest != null) {
      await addQuest(newQuest, slog); // Тепер викликаємо асинхронний метод
    } else {
      _logger.writeLog(
        message: "Failed to generate a new quest using Gemini API.",
        severity: CloudLogSeverity.error,
      );
      slog.addMessage("Не вдалося згенерувати завдання.", MessageType.error);
    }

    _isGeneratingQuest = false;
    notifyListeners();
    return newQuest;
  }

  Future<void> resetAllQuests() async {
    if (_questsCollectionRef == null) return;

    _activeQuests.clear();
    _completedQuests.clear();
    notifyListeners();

    try {
      final snapshot = await _questsCollectionRef!.get();
      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      // _logger.writeLog(
      //   message: "All quests deleted from Firestore for the user.",
      //   payload: {
      //     "message": "All quests reset",
      //     "context": {"userId": _playerProvider?.getUserId()}
      //   },
      // );
    } catch (e) {
      // _logger.writeLog(
      //   message: "Error deleting all quests from Firestore: $e",
      //   severity: CloudLogSeverity.error,
      //   payload: {
      //     "message": "Quest reset error",
      //     "context": {
      //       "userId": _playerProvider?.getUserId(),
      //       "error": e.toString()
      //     }
      //   },
      // );
    }
  }
}
