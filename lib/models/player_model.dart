import 'dart:math';
import 'quest_model.dart';

// Перелік для можливих характеристик
enum PlayerStat {
  strength, // Сила
  agility, // Спритність
  intelligence, // Інтелект
  perception, // Сприйняття
  stamina, // Витривалість
}

enum PhysicalActivity {
  pullUps,
  pushUps,
  runningDurationInMin,
  regularExercise,
}

class PlayerModel {
  String playerName;
  int level;
  int xp;
  late int xpToNextLevel;
  Map<PlayerStat, int> stats;
  int availableStatPoints;
  Map<PhysicalActivity, dynamic>? baselinePhysicalPerformance;
  bool initialSurveyCompleted;
  late QuestDifficulty playerRank;

  late int maxHp;
  late int currentHp;
  late int maxMp;
  late int currentMp;

  static const int baseHpPerLevel = 10;
  static const int hpPerStaminaPoint = 5;
  static const int baseMpPerLevel = 5;
  static const int mpPerIntelligencePoint = 3;

  PlayerModel({
    this.playerName = "Мисливець",
    this.level = 1,
    this.xp = 0,
    Map<PlayerStat, int>? initialStats,
    this.availableStatPoints = 0,
    this.baselinePhysicalPerformance,
    this.initialSurveyCompleted = false,
    this.playerRank = QuestDifficulty.F,
    int? loadedCurrentHp,
    int? loadedCurrentMp,
  }) : stats = initialStats ??
            {
              PlayerStat.strength: 5,
              PlayerStat.agility: 5,
              PlayerStat.intelligence: 5,
              PlayerStat.perception: 5,
              PlayerStat.stamina: 5,
            } {
    xpToNextLevel = calculateXpForLevel(level);

    _calculateAndUpdateHpMp();

    currentHp = loadedCurrentHp ?? maxHp;
    currentMp = loadedCurrentMp ?? maxMp;

    currentHp = min(currentHp, maxHp);
    currentMp = min(currentMp, maxMp);
  }

  // Метод для розрахунку та оновлення maxHp/maxMp
  // Викликатиметься при підвищенні рівня або зміні статів, що впливають на HP/MP
  void _calculateAndUpdateHpMp() {
    int stamina = stats[PlayerStat.stamina] ?? 0;
    int intelligence = stats[PlayerStat.intelligence] ?? 0;

    maxHp = (level * baseHpPerLevel) +
        (stamina * hpPerStaminaPoint) +
        50; // +50 базове HP
    maxMp = (level * baseMpPerLevel) +
        (intelligence * mpPerIntelligencePoint) +
        20; // +20 базове MP

    // При оновленні максимальних значень, поточні не повинні їх перевищувати.
    // Якщо ми збільшуємо максимальне HP/MP, поточне може залишитися тим самим або теж збільшитися.
    // Зазвичай при левелапі HP/MP повністю відновлюються.
  }

  // Метод, що викликається при підвищенні рівня (з PlayerProvider)
  void onLevelUp() {
    int oldMaxHp = maxHp;
    int oldMaxMp = maxMp;

    _calculateAndUpdateHpMp(); // Перераховуємо максимальні значення

    // Повністю відновлюємо HP/MP при підвищенні рівня
    // Або можна додавати різницю: currentHp += (maxHp - oldMaxHp);
    currentHp = maxHp;
    currentMp = maxMp;
  }

  // Метод, що викликається при зміні характеристик (з PlayerProvider)
  void onStatsChanged() {
    int oldMaxHp = maxHp;
    int oldMaxMp = maxMp;
    _calculateAndUpdateHpMp();

    // Зберігаємо відсоток поточного HP/MP і застосовуємо до нового max
    // Щоб при збільшенні стаміни не відбувалося повного відновлення, а лише збільшення max
    // і пропорційне збільшення current (якщо воно не було повним)
    double hpPercentage = (oldMaxHp > 0) ? currentHp / oldMaxHp : 1.0;
    double mpPercentage = (oldMaxMp > 0) ? currentMp / oldMaxMp : 1.0;

    currentHp = (maxHp * hpPercentage).round();
    currentMp = (maxMp * mpPercentage).round();

    // Переконуємося, що не перевищили нові максимальні значення
    currentHp = min(currentHp, maxHp);
    currentMp = min(currentMp, maxMp);
    // І що не менше 0
    currentHp = max(0, currentHp);
    currentMp = max(0, currentMp);
  }

  // Методи для зміни поточних HP/MP (поки не використовуються активно)
  void takeDamage(int amount) {
    currentHp = max(0, currentHp - amount);
  }

  void restoreHp(int amount) {
    currentHp = min(maxHp, currentHp + amount);
  }

  void useMp(int amount) {
    currentMp = max(0, currentMp - amount);
  }

  void restoreMp(int amount) {
    currentMp = min(maxMp, currentMp + amount);
  }

  // Метод для розрахунку рангу гравця на основі рівня
  static QuestDifficulty calculateRankByLevel(int level) {
    if (level < 5) return QuestDifficulty.F; // Додали F-ранг для початківців
    if (level < 10) return QuestDifficulty.E;
    if (level < 20) return QuestDifficulty.D;
    if (level < 30) return QuestDifficulty.C;
    if (level < 40) return QuestDifficulty.B;
    if (level < 50) return QuestDifficulty.A;
    return QuestDifficulty.S;
  }

  static int calculateXpForLevel(int level) {
    if (level <= 0) return 100; // Базове значення для невалідних рівнів
    if (level == 1) return 100; // Початкове XP для 2-го рівня
    // Формула: (level^1.8 * 75) + ((level-1) * 150)
    return (pow(level, 1.8) * 75 + (level - 1) * 150).round();
  }

  // Метод для зручного отримання назви характеристики (для UI)
  static String getStatName(PlayerStat stat) {
    switch (stat) {
      case PlayerStat.strength:
        return "Сила";
      case PlayerStat.agility:
        return "Спритність";
      case PlayerStat.intelligence:
        return "Інтелект";
      case PlayerStat.perception:
        return "Сприйняття";
      case PlayerStat.stamina:
        return "Витривалість";
      default:
        return "";
    }
  }

  // Конвертація в JSON
  Map<String, dynamic> toJson() {
    return {
      'playerName': playerName,
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpToNextLevel,
      'stats': stats.map((key, value) => MapEntry(key.name, value)),
      'availableStatPoints': availableStatPoints,
      'baselinePhysicalPerformance': baselinePhysicalPerformance?.map(
        (key, value) => MapEntry(key.name, value),
      ),
      'initialSurveyCompleted': initialSurveyCompleted,
      'playerRank': playerRank.name,
      'maxHp': maxHp,
      'currentHp': currentHp,
      'maxMp': maxMp,
      'currentMp': currentMp,
    };
  }

  // Створення з JSON
  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    // Конвертація рядкових ключів статів назад в PlayerStat
    Map<PlayerStat, int> loadedStats =
        (json['stats'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        PlayerStat.values.byName(key), // PlayerStat.values.byName(stringKey)
        value as int,
      ),
    );

    Map<PhysicalActivity, dynamic>? loadedBaselinePerformance;
    if (json['baselinePhysicalPerformance'] != null) {
      loadedBaselinePerformance = (json['baselinePhysicalPerformance']
              as Map<String, dynamic>)
          .map(
        (key, value) {
          try {
            return MapEntry(PhysicalActivity.values.byName(key), value);
          } catch (e) {
            // Обробка можливої помилки, якщо enum змінився, а дані старі
            print(
                "Warning: Could not parse PhysicalActivity key '$key' from saved data.");
            return MapEntry(PhysicalActivity.pullUps,
                null); // Повертаємо щось, що потім можна відфільтрувати
          }
        },
      )..removeWhere((key, value) =>
          value == null &&
          key ==
              PhysicalActivity.pullUps); // Видаляємо, якщо ключ не розпарсився
      if (loadedBaselinePerformance.isEmpty) loadedBaselinePerformance = null;
    }

    int loadedLevel =
        json['level'] as int; // Отримуємо рівень для розрахунку рангу

    return PlayerModel(
      playerName: json['playerName'] as String? ?? "Мисливець",
      level: loadedLevel,
      xp: json['xp'] as int,
      initialStats: loadedStats,
      playerRank: json['playerRank'] != null
          ? QuestDifficulty.values.byName(json['playerRank'] as String)
          : QuestDifficulty.F,
      availableStatPoints: json['availableStatPoints'] as int,
      baselinePhysicalPerformance: loadedBaselinePerformance,
      initialSurveyCompleted: json['initialSurveyCompleted'] as bool? ?? false,
      loadedCurrentHp: json['currentHp'] as int?,
      loadedCurrentMp: json['currentMp'] as int?,
    );
  }
}
