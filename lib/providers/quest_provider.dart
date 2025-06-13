// lib/providers/quest_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quest_model.dart';
import '../models/player_model.dart'; // Для PlayerStat, PlayerProvider не потрібен прямо тут
import 'player_provider.dart'; // Потрібен для нарахування нагород

class QuestProvider with ChangeNotifier {
  List<QuestModel> _activeQuests = [];
  List<QuestModel> _completedQuests = [];
  bool _isLoading = true;

  List<QuestModel> get activeQuests => _activeQuests;
  List<QuestModel> get completedQuests => _completedQuests;
  bool get isLoading => _isLoading;

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
      if (lastGenerationDate == todayDateOnly) {
        shouldGenerate = false; // Вже генерували сьогодні
        print("Daily quests already generated today.");
      }
    }

    if (shouldGenerate) {
      print(
          "Generating daily quests for ${todayDateOnly.toIso8601String()}...");
      // Видаляємо старі (невиконані) щоденні квести, якщо потрібно
      _activeQuests.removeWhere(
          (quest) => quest.type == QuestType.daily && !quest.isCompleted);

      // Приклади щоденних квестів (поки що хардкод)
      // Тут в майбутньому буде логіка Gemini API або більш розумна генерація
      final dailyQuests = [
        QuestModel(
            title: "Ранкова Розминка",
            description:
                "Виконай 10 віджимань, 20 присідань та 5 хвилин розтяжки.",
            xpReward:
                20 + (playerProvider.player.level * 2), // Динамічна нагорода
            difficulty: QuestDifficulty.E,
            type: QuestType.daily,
            statRewards: {PlayerStat.stamina: 1}),
        QuestModel(
            title: "Ментальна Концентрація",
            description:
                "Присвяти 15 хвилин медитації або читанню корисної книги.",
            xpReward: 15 + (playerProvider.player.level * 2),
            difficulty: QuestDifficulty.E,
            type: QuestType.daily,
            statRewards: {PlayerStat.intelligence: 1}),
        QuestModel(
            title: "Дослідження Оточення",
            description:
                "Пройдись новим маршрутом або відвідай місце, де давно не був (мінімум 30 хвилин).",
            xpReward: 25 + (playerProvider.player.level * 3),
            difficulty: QuestDifficulty.D,
            type: QuestType.daily,
            statRewards: {PlayerStat.perception: 1}),
      ];

      for (var quest in dailyQuests) {
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
          addQuest(quest);
        }
      }

      await prefs.setString(
          _lastDailyQuestGenerationKey, todayDateOnly.toIso8601String());
      print("Daily quests generated and saved. Next generation tomorrow.");
      _saveQuests(); // Зберігаємо нові квести
      notifyListeners();
    }
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
