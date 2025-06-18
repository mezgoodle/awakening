// lib/providers/quest_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/player_model.dart'; // Для PlayerStat, PlayerProvider не потрібен прямо тут
import 'player_provider.dart'; // Потрібен для нарахування нагород
import '../services/gemini_quest_service.dart'; // Імпортуємо наш сервіс

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

  void completeQuest(String questId, PlayerProvider playerProvider) {
    final questIndex = _activeQuests.indexWhere((q) => q.id == questId);
    if (questIndex != -1) {
      QuestModel quest = _activeQuests[questIndex];

      // Нараховуємо нагороди
      playerProvider.addXp(quest.xpReward);
      if (quest.statRewards != null) {
        quest.statRewards!.forEach((stat, amount) {
          playerProvider.increaseStat(stat, amount);
        });
      }

      // Позначаємо як виконаний і переміщуємо
      quest.isCompleted = true;
      quest.completedAt = DateTime.now();
      _completedQuests.add(quest);
      _activeQuests.removeAt(questIndex);

      _saveQuests();
      notifyListeners();
      print("Quest '${quest.title}' completed!");
    }
  }

  // Метод для генерації щоденних квестів (поки що хардкод)
  // PlayerProvider потрібен, щоб адаптувати складність/нагороди під рівень гравця в майбутньому
  Future<void> generateDailyQuestsIfNeeded(
      PlayerProvider playerProvider) async {
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
        // Додаткова перевірка, чи є вже щоденні
        shouldGenerate = false;
        print("Daily quests already exist or generated today.");
      }
    }

    if (shouldGenerate) {
      print(
          "Generating daily quests for ${todayDateOnly.toIso8601String()}...");
      _activeQuests.removeWhere(
          (quest) => quest.type == QuestType.daily && !quest.isCompleted);

      _isGeneratingQuest = true;
      notifyListeners(); // Повідомити UI про початок генерації

      List<QuestModel> newDailyQuests = [];
      // Спробуємо згенерувати 2-3 щоденних завдання через Gemini
      // Можна додати різні targetStat для різноманітності
      List<PlayerStat?> dailyTargets = [
        PlayerStat.stamina,
        PlayerStat.intelligence,
        null
      ]; // null для загального

      for (int i = 0; i < 2; i++) {
        // Згенеруємо 2 щоденних
        QuestModel? generatedQuest = await _geminiService.generateQuest(
            player: playerProvider.player,
            questType: QuestType.daily,
            targetStat: dailyTargets[i % dailyTargets.length], // Чергуємо цілі
            customPromptInstruction:
                "Це має бути завдання, яке можна виконувати щодня для підтримки форми або розвитку навичок.");
        if (generatedQuest != null) {
          newDailyQuests.add(generatedQuest);
        } else {
          // Якщо Gemini не зміг, додамо хардкодний варіант
          print("Gemini failed to generate daily quest, adding fallback.");
          newDailyQuests.add(_getFallbackDailyQuest(playerProvider.player, i));
        }
      }

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
        }
      }

      if (newDailyQuests.isNotEmpty) {
        await prefs.setString(
            _lastDailyQuestGenerationKey, todayDateOnly.toIso8601String());
        print("Daily quests processing finished.");
      }
      _isGeneratingQuest = false;
      // notifyListeners(); // addQuest вже викликає notifyListeners, тому тут не завжди потрібно,
      // але якщо були помилки і нічого не додалось, то UI не оновить _isGeneratingQuest
      // Тому краще викликати для гарантії оновлення стану завантаження.
      notifyListeners();
    }
  }

  // Метод для отримання запасного щоденного квесту, якщо Gemini не спрацював
  QuestModel _getFallbackDailyQuest(PlayerModel player, int index) {
    List<QuestModel> fallbacks = [
      QuestModel(
        title: "Ранкова Енергія",
        description:
            "Розпочни день з короткої 10-хвилинної зарядки або прогулянки на свіжому повітрі. Це пробудить твою внутрішню силу.",
        xpReward: 15 + (player.level * 2),
        difficulty: QuestDifficulty.E,
        type: QuestType.daily,
        statRewards: {PlayerStat.stamina: 1},
      ),
      QuestModel(
        title: "Година Концентрації",
        description:
            "Присвяти одну годину глибокій роботі над важливим завданням без відволікань. Відточи свій фокус.",
        xpReward: 25 + (player.level * 3),
        difficulty: QuestDifficulty.D,
        type: QuestType.daily,
        statRewards: {PlayerStat.intelligence: 1},
      ),
    ];
    return fallbacks[index % fallbacks.length];
  }

  // Метод для генерації одного завдання на вимогу
  Future<QuestModel?> fetchAndAddGeneratedQuest({
    required PlayerProvider playerProvider,
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
    } else {
      print("Failed to generate a new quest using Gemini API.");
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
