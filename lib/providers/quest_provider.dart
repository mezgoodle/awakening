import 'dart:convert';
import 'package:awakening/models/system_message_model.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/player_model.dart';
import 'player_provider.dart';
import '../services/gemini_quest_service.dart';
import 'system_log_provider.dart';

class QuestProvider with ChangeNotifier {
  List<QuestModel> _activeQuests = [];
  List<QuestModel> _completedQuests = [];
  bool _isLoading = true;
  final GeminiQuestService _geminiService =
      GeminiQuestService(); // Створюємо екземпляр сервісу
  bool _isGeneratingQuest = false; // Прапорець для індикації завантаження

  List<QuestModel> get activeQuests => _activeQuests;
  List<QuestModel> get completedQuests => _completedQuests;
  bool get isLoading => _isLoading;
  bool get isGeneratingQuest => _isGeneratingQuest;

  static const String _activeQuestsKey = 'activeQuestsData';
  static const String _completedQuestsKey = 'completedQuestsData';
  static const String _lastDailyQuestGenerationKey =
      'lastDailyQuestGenerationDate';

  QuestProvider() {
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();

    // Завантаження активних квестів
    final String? activeQuestsString = prefs.getString(_activeQuestsKey);
    if (activeQuestsString != null) {
      try {
        final List<dynamic> activeQuestsJson = jsonDecode(activeQuestsString);
        _activeQuests = activeQuestsJson
            .map((jsonItem) =>
                QuestModel.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print("Error loading active quests: $e");
        _activeQuests = []; // Скидаємо, якщо помилка
      }
    } else {
      _activeQuests = []; // Якщо даних немає, починаємо з порожнього списку
    }

    // Завантаження виконаних квестів
    final String? completedQuestsString = prefs.getString(_completedQuestsKey);
    if (completedQuestsString != null) {
      try {
        final List<dynamic> completedQuestsJson =
            jsonDecode(completedQuestsString);
        _completedQuests = completedQuestsJson
            .map((jsonItem) =>
                QuestModel.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print("Error loading completed quests: $e");
        _completedQuests = [];
      }
    } else {
      _completedQuests = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveQuests() async {
    final prefs = await SharedPreferences.getInstance();
    final String activeQuestsString =
        jsonEncode(_activeQuests.map((q) => q.toJson()).toList());
    await prefs.setString(_activeQuestsKey, activeQuestsString);

    final String completedQuestsString =
        jsonEncode(_completedQuests.map((q) => q.toJson()).toList());
    await prefs.setString(_completedQuestsKey, completedQuestsString);
  }

  // Для додавання нових квестів (згенерованих або хардкодних)
  void addQuest(QuestModel quest) {
    // Перевірка на дублікати за ID
    if (!_activeQuests.any((q) => q.id == quest.id) &&
        !_completedQuests.any((q) => q.id == quest.id)) {
      _activeQuests.add(quest);
      _saveQuests();
      notifyListeners();
    } else {
      print("Quest with ID ${quest.id} already exists.");
    }
  }

  void completeQuest(
      String questId, PlayerProvider playerProvider, SystemLogProvider slog) {
    final questIndex = _activeQuests.indexWhere((q) => q.id == questId);
    if (questIndex != -1) {
      QuestModel quest = _activeQuests[questIndex];

      // Нараховуємо нагороди
      playerProvider.addXp(quest.xpReward, slog);
      if (quest.statRewards != null) {
        quest.statRewards!.forEach((stat, amount) {
          playerProvider.increaseStat(stat, amount, slog);
        });
      }

      // Позначаємо як виконаний і переміщуємо
      quest.isCompleted = true;
      quest.completedAt = DateTime.now();
      slog.addMessage(
          "Завдання '${quest.title}' виконано! Нагорода: ${quest.xpReward} XP.",
          MessageType.questCompleted);
      _completedQuests.add(quest);
      _activeQuests.removeAt(questIndex);

      _saveQuests();
      notifyListeners();
      print("Quest '${quest.title}' completed!");
    }
  }

  Future<void> generateDailyQuestsIfNeeded(
      PlayerProvider playerProvider, SystemLogProvider slog) async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastGenerationDateStr =
        prefs.getString(_lastDailyQuestGenerationKey);
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    bool shouldGenerate = true;
    if (lastGenerationDateStr != null) {
      final lastGenerationDate = DateTime.parse(lastGenerationDateStr);
      if (lastGenerationDate == todayDateOnly &&
          _activeQuests.any((q) => q.type == QuestType.daily)) {
        shouldGenerate = false;
        print("Daily quests already exist or generated today.");
      }
    }

    if (shouldGenerate) {
      if (playerProvider.isLoading) {
        print(
            "Player data is still loading. Skipping daily quest generation for now.");
        return;
      }

      print(
          "Generating daily quests for ${todayDateOnly.toIso8601String()}...");
      _activeQuests.removeWhere(
          (quest) => quest.type == QuestType.daily && !quest.isCompleted);

      _isGeneratingQuest = true;
      notifyListeners(); // Повідомити UI про початок генерації

      List<QuestModel> newDailyQuests = [];
      PlayerModel currentPlayer = playerProvider.player;

      // Генеруємо по одному завданню для кожної основної характеристики
      for (PlayerStat stat in PlayerStat.values) {
        print(
            "Attempting to generate daily quest for ${PlayerModel.getStatName(stat)}...");
        QuestModel? generatedQuest = await _geminiService.generateQuest(
          player: currentPlayer,
          questType: QuestType.daily,
          targetStat: stat, // Вказуємо цільову характеристику
          // customPromptInstruction: "Це щоденне завдання для підтримки та розвитку ${PlayerModel.getStatName(stat)}." // Можна додати для ясності Gemini
        );

        if (generatedQuest != null) {
          // Перевірка, чи Gemini правильно встановив targetStat
          if (generatedQuest.targetStat != stat &&
              generatedQuest.targetStat != null) {
            print(
                "Warning: Gemini generated quest for ${PlayerModel.getStatName(generatedQuest.targetStat!)} instead of ${PlayerModel.getStatName(stat)}. Using fallback.");
            newDailyQuests
                .add(_getFallbackDailyQuestForStat(stat, currentPlayer));
            slog.addMessage("Нове щоденне завдання: '${generatedQuest.title}'",
                MessageType.questAdded,
                showInSnackbar: false);
          } else if (generatedQuest.targetStat == null &&
              generatedQuest.type == QuestType.daily) {
            // Якщо Gemini не вказав targetStat для щоденного, можливо, він не зрозумів фокус
            // Хоча наш промпт тепер сильніше на це вказує
            print(
                "Warning: Gemini daily quest has no targetStat for ${PlayerModel.getStatName(stat)}. Adjusting or using fallback.");
            slog.addMessage(
                "Невдала генерація щоденного для $stat, використано резерв.",
                MessageType.warning,
                showInSnackbar: false);
            // Спробуємо "виправити" або використати fallback
            // Для простоти, поки що використовуємо fallback, якщо targetStat не встановлено або не той
            QuestModel correctedQuest = QuestModel(
                id: generatedQuest.id, // Зберігаємо ID, якщо є
                title: generatedQuest.title,
                description: generatedQuest.description,
                xpReward: generatedQuest.xpReward,
                statRewards: generatedQuest.statRewards ??
                    {stat: 1}, // Гарантуємо нагороду за цільовий стат
                type: QuestType.daily,
                difficulty: generatedQuest.difficulty,
                targetStat:
                    stat, // Примусово встановлюємо правильний targetStat
                createdAt: generatedQuest.createdAt);
            newDailyQuests.add(correctedQuest);
          } else {
            newDailyQuests.add(generatedQuest);
          }
        } else {
          print(
              "Gemini failed to generate daily quest for ${PlayerModel.getStatName(stat)}, using fallback.");
          newDailyQuests
              .add(_getFallbackDailyQuestForStat(stat, currentPlayer));
        }
      }

      int addedQuestCount = 0;
      for (var quest in newDailyQuests) {
        // Перевіряємо, чи квест з таким самим заголовком (для уникнення дублів щоденних)
        // вже існує серед активних або виконаних СЬОГОДНІ
        bool alreadyExistsToday = _activeQuests.any(
                (q) => q.title == quest.title && q.type == QuestType.daily) ||
            _completedQuests.any((q) =>
                q.title == quest.title &&
                q.type == QuestType.daily &&
                q.completedAt != null &&
                DateTime(q.completedAt!.year, q.completedAt!.month,
                        q.completedAt!.day) ==
                    todayDateOnly);
        if (!alreadyExistsToday) {
          addQuest(
              quest); // addQuest вже викликає _saveQuests і notifyListeners
          addedQuestCount++;
        }
      }

      if (addedQuestCount > 0) {
        // Зберігаємо дату, тільки якщо хоча б один квест було додано
        await prefs.setString(
            _lastDailyQuestGenerationKey, todayDateOnly.toIso8601String());
        print(
            "$addedQuestCount daily quests processed and saved. Next generation tomorrow.");
      } else {
        print(
            "No new daily quests were added (possibly all duplicates or generation failed).");
      }

      _isGeneratingQuest = false;
      notifyListeners(); // Повідомити UI про завершення генерації
    }
  }

  // Метод для отримання запасного щоденного квесту для конкретної характеристики
  QuestModel _getFallbackDailyQuestForStat(
      PlayerStat stat, PlayerModel player) {
    int xpBase = 15 + (player.level * 2);
    Map<PlayerStat, int> defaultStatReward = {stat: 1};

    switch (stat) {
      case PlayerStat.strength:
        return QuestModel(
          title: "Щоденна Сила",
          description:
              "Виконай 2 підходи по ${(player.baselinePhysicalPerformance?[PhysicalActivity.pushUps] as int? ?? 10) ~/ 2 + 3} віджимань та ${(player.baselinePhysicalPerformance?[PhysicalActivity.pullUps] as int? ?? 2) ~/ 2 + 1} підтягувань (або австралійських).",
          xpReward: xpBase + 5,
          difficulty: QuestDifficulty.E,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
      case PlayerStat.agility:
        return QuestModel(
          title: "Ранкова Гнучкість",
          description:
              "Присвяти 10 хвилин розтяжці основних груп м'язів або виконай комплекс вправ на координацію.",
          xpReward: xpBase,
          difficulty: QuestDifficulty.E,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
      case PlayerStat.intelligence:
        return QuestModel(
          title: "Ментальна Зарядка",
          description:
              "Прочитай 10 сторінок книги, що розвиває, або розв'яжи 2-3 логічні задачі/головоломки.",
          xpReward: xpBase,
          difficulty: QuestDifficulty.D,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
      case PlayerStat.perception:
        return QuestModel(
          title: "Око Мисливця",
          description:
              "Під час прогулянки або поїздки, спробуй помітити 5 дрібних деталей, на які раніше не звертав уваги. Запиши їх.",
          xpReward: xpBase - 5 > 0 ? xpBase - 5 : 5,
          difficulty: QuestDifficulty.D,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
      case PlayerStat.stamina:
        return QuestModel(
          title: "Витривалість Тіні",
          description:
              "Здійсни ${(player.baselinePhysicalPerformance?[PhysicalActivity.runningDurationInMin] as int? ?? 10) ~/ 2 + 5}-хвилинну пробіжку в помірному темпі або швидку ходьбу.",
          xpReward: xpBase + 5,
          difficulty: QuestDifficulty.E,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
      default: // На випадок, якщо додадуться нові стати
        return QuestModel(
          title: "Щоденний Розвиток",
          description:
              "Присвяти 15 хвилин будь-якій активності, що покращує тебе.",
          xpReward: xpBase,
          difficulty: QuestDifficulty.E,
          type: QuestType.daily,
          statRewards: defaultStatReward,
          targetStat: stat,
        );
    }
  }

  // Метод для генерації одного завдання на вимогу
  Future<QuestModel?> fetchAndAddGeneratedQuest({
    required PlayerProvider playerProvider,
    required SystemLogProvider slog,
    QuestType questType = QuestType.generated,
    PlayerStat? targetStat,
    String? customInstruction,
  }) async {
    if (_isGeneratingQuest) return null; // Не генерувати, якщо вже йде процес

    _isGeneratingQuest = true;
    notifyListeners();

    QuestModel? newQuest = await _geminiService.generateQuest(
      player: playerProvider.player,
      questType: questType,
      targetStat: targetStat,
      customPromptInstruction: customInstruction,
    );

    if (newQuest != null) {
      addQuest(newQuest); // addQuest викличе _saveQuests та notifyListeners
      slog.addMessage("Нове завдання: '${newQuest.title}' згенеровано!",
          MessageType.questAdded);
    } else {
      print("Failed to generate a new quest using Gemini API.");
      slog.addMessage("Не вдалося згенерувати завдання.", MessageType.error);
    }

    _isGeneratingQuest = false;
    // addQuest вже викликав notifyListeners, але якщо newQuest == null, то UI не оновить _isGeneratingQuest
    notifyListeners();
    return newQuest;
  }

  // Метод для очищення списків квестів (для тестування)
  Future<void> resetAllQuests() async {
    _activeQuests.clear();
    _completedQuests.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeQuestsKey);
    await prefs.remove(_completedQuestsKey);
    await prefs.remove(
        _lastDailyQuestGenerationKey); // Скидаємо дату генерації щоденних
    notifyListeners();
    print("All quest data has been reset.");
  }
}
