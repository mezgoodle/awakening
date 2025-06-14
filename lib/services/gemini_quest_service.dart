// lib/services/gemini_quest_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';

class GeminiQuestService {
  final GenerativeModel _model;

  GeminiQuestService()
      : _model = GenerativeModel(
            model: 'gemini-1.5-flash-latest',
            apiKey: dotenv.env['GEMINI_API_KEY']!,
            // Налаштування безпеки можна залишити за замовчуванням або налаштувати
            // Тут ми дозволяємо всі категорії, але з низьким порогом для блокування,
            // щоб уникнути надто суворих обмежень для ігрового контенту,
            // але це потрібно тестувати. Для деяких тем (насилля в грі) може знадобитися
            // більш тонке налаштування або менш суворі обмеження.
            // SafetySettings для прикладу, можна почати без них, щоб побачити дефолтну поведінку.
            safetySettings: [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
              SafetySetting(
                  HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
              SafetySetting(
                  HarmCategory.dangerousContent, HarmBlockThreshold.medium),
            ],
            generationConfig: GenerationConfig(
              // temperature: 0.7, // 0.0 - 1.0. Більше значення -> більш креативно, менше -> більш детерміновано
              // topK: 40,
              // topP: 0.95,
              maxOutputTokens:
                  1024, // Максимальна кількість токенів у відповіді
              // responseMimeType: "application/json", // Якщо модель підтримує і ти впевнений у промпті
            ));

  Future<QuestModel?> generateQuest({
    required PlayerModel player,
    QuestType questType = QuestType.generated, // Тип квесту за замовчуванням
    PlayerStat? targetStat, // Можлива фокусна характеристика
    String? customPromptInstruction, // Додаткова інструкція для промпту
  }) async {
    final playerName = player.playerName == "Мисливець"
        ? "гравець"
        : player.playerName; // Узагальнення, якщо ім'я дефолтне

    final prompt = """
Згенеруй ігрове завдання для рольової гри на Android в стилі аніме "Solo Leveling" (Підняття рівня наодинці).
Завдання має бути реалістичним для виконання в реальному житті, але описане в термінах ігрового світу.
Фокусуйся на саморозвитку, фізичних або інтелектуальних вправах, дослідженні або корисних звичках.

Інформація про гравця:
Ім'я: $playerName
Рівень: ${player.level}
Сила: ${player.stats[PlayerStat.strength]}
Спритність: ${player.stats[PlayerStat.agility]}
Інтелект: ${player.stats[PlayerStat.intelligence]}
Сприйняття: ${player.stats[PlayerStat.perception]}
Витривалість: ${player.stats[PlayerStat.stamina]}

Параметри для генерації завдання:
Тип завдання: ${QuestModel.getQuestTypeName(questType)}
${targetStat != null ? 'Завдання має бути сфокусоване на розвитку характеристики: ${PlayerModel.getStatName(targetStat)}.' : 'Завдання може бути загальнорозвиваючим або фокусуватися на будь-якій доступній гравцю характеристиці.'}
${customPromptInstruction != null ? '\nДодаткова інструкція: $customPromptInstruction' : ''}

Завдання повинно бути унікальним та цікавим.
Воно повинно містити:
1.  Назва (коротка, інтригуюча, в стилі Solo Leveling, 3-5 слів).
2.  Опис (детальніше, що потрібно зробити гравцю, 2-4 речення. Опис має бути практичним, що гравець може зробити в реальності).
3.  Ранг складності (F, E, D, C, B, A, S). Ранг має відповідати рівню гравця та опису завдання. Для низьких рівнів гравця (1-10) уникай рангів A, S, якщо це не особливий квест.
4.  Нагорода XP (ціле число). Нагорода має залежати від складності та рівня гравця.
    Приклади XP для рівня ${player.level}:
    - Ранг F: ${10 + player.level * 2}-${20 + player.level * 3} XP
    - Ранг E: ${20 + player.level * 3}-${35 + player.level * 4} XP
    - Ранг D: ${35 + player.level * 4}-${50 + player.level * 5} XP
    - Ранг C: ${50 + player.level * 5}-${75 + player.level * 6} XP
    (для вищих рангів пропорційно більше)
5.  Нагорода у вигляді очок характеристик (опціонально): об'єкт JSON, де ключ - назва характеристики (strength, agility, intelligence, perception, stamina), а значення - кількість очок (зазвичай 1, рідко 2 для дуже складних завдань). Якщо нагороди в характеристиках немає, цей ключ має бути відсутнім або значенням null.
6.  Фокусна характеристика (опціонально): назва характеристики (strength, agility, intelligence, perception, stamina), на яку завдання має найбільший вплив, якщо це явно випливає з опису. Якщо ні, цей ключ має бути відсутнім або значенням null.

Надай відповідь ТІЛЬКИ у форматі JSON об'єкту з такими полями (використовуй подвійні лапки для ключів та рядкових значень):
"title": "string",
"description": "string",
"difficulty": "string (F, E, D, C, B, A, S)",
"xpReward": integer,
"statRewards": {"stat_name_english": amount, ...} (або null),
"targetStat": "stat_name_english" (або null)

Приклад бажаного JSON (не копіюй його, це лише приклад структури):
{
  "title": "Тренування Тіні",
  "description": "Щоб стати сильнішим, ти повинен відточити свої рухи. Виконай комплекс фізичних вправ: 3 підходи по 15 віджимань та 3 підходи по 20 присідань. Кожен рух має бути чітким, як удар тіні.",
  "difficulty": "E",
  "xpReward": 30,
  "statRewards": {"strength": 1, "stamina": 1},
  "targetStat": "strength"
}

Інший приклад:
{
  "title": "Пошук Знань",
  "description": "Істинна сила не лише в м'язах. Прочитай сьогодні 20 сторінок книги, яка розширює твої горизонти, або вивчи 5 нових слів іноземною мовою. Знання - це теж зброя.",
  "difficulty": "D",
  "xpReward": 45,
  "statRewards": {"intelligence": 1},
  "targetStat": "intelligence"
}

Переконайся, що назви характеристик в statRewards та targetStat є одними з: strength, agility, intelligence, perception, stamina.
Не додавай жодних коментарів або пояснень поза JSON об'єктом. Тільки JSON.
""";
    // print("--- PROMPT ---");
    // print(prompt);
    // print("--------------");

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      // print("--- RESPONSE ---");
      // print(response.text);
      // print("----------------");

      if (response.text == null || response.text!.isEmpty) {
        print("Gemini API: Empty response.");
        return null;
      }

      // Спробуємо знайти JSON у відповіді, навіть якщо є зайвий текст (хоча промпт просить тільки JSON)
      String jsonString = response.text!;
      final jsonStartIndex = jsonString.indexOf('{');
      final jsonEndIndex = jsonString.lastIndexOf('}');

      if (jsonStartIndex != -1 &&
          jsonEndIndex != -1 &&
          jsonEndIndex > jsonStartIndex) {
        jsonString = jsonString.substring(jsonStartIndex, jsonEndIndex + 1);
      } else {
        print(
            "Gemini API: No valid JSON object found in response: ${response.text}");
        return null;
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

      // Валідація та створення QuestModel
      if (jsonResponse['title'] == null ||
          jsonResponse['description'] == null ||
          jsonResponse['difficulty'] == null ||
          jsonResponse['xpReward'] == null) {
        print("Gemini API: Missing required fields in JSON response.");
        return null;
      }

      QuestDifficulty difficulty;
      try {
        difficulty = QuestDifficulty.values
            .byName(jsonResponse['difficulty'].toString().toUpperCase());
      } catch (e) {
        print(
            "Gemini API: Invalid difficulty value: ${jsonResponse['difficulty']}. Defaulting to E.");
        difficulty = QuestDifficulty
            .E; // Дефолтне значення, якщо API повернуло невалідний ранг
      }

      Map<PlayerStat, int>? statRewards;
      if (jsonResponse['statRewards'] != null &&
          jsonResponse['statRewards'] is Map) {
        statRewards = (jsonResponse['statRewards'] as Map<String, dynamic>).map(
          (key, value) {
            try {
              return MapEntry(
                  PlayerStat.values.byName(key.toLowerCase()), value as int);
            } catch (e) {
              print(
                  "Gemini API: Invalid stat name '$key' in statRewards. Skipping.");
              return MapEntry(
                  PlayerStat.strength, 0); // Placeholder, буде відфільтровано
            }
          },
        )..removeWhere((key, value) =>
            value == 0 &&
            key ==
                PlayerStat
                    .strength); // Видаляємо плейсхолдер, якщо він залишився
        if (statRewards.isEmpty) statRewards = null;
      }

      PlayerStat? parsedTargetStat;
      if (jsonResponse['targetStat'] != null &&
          jsonResponse['targetStat'] is String) {
        try {
          parsedTargetStat = PlayerStat.values
              .byName(jsonResponse['targetStat'].toString().toLowerCase());
        } catch (e) {
          print(
              "Gemini API: Invalid targetStat value: ${jsonResponse['targetStat']}. Setting to null.");
        }
      }

      return QuestModel(
        title: jsonResponse['title'],
        description: jsonResponse['description'],
        xpReward: (jsonResponse['xpReward'] as num)
            .toInt(), // API може повернути double
        difficulty: difficulty,
        type: questType, // Тип, який ми передали для генерації
        statRewards: statRewards,
        targetStat: parsedTargetStat,
      );
    } catch (e) {
      print("Error generating quest with Gemini API: $e");
      if (e is GenerativeAIException) {
        print("GenerativeAIException details: ${e.message}");
        // Можна перевірити e.promptFeedback або e.finishReason для деталей
      }
      return null;
    }
  }
}
