import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';

class GeminiQuestService {
  final GenerativeModel _model;

  GeminiQuestService()
      : _model = GenerativeModel(
            model: 'gemini-2.0-flash-001',
            apiKey: dotenv.env['GEMINI_API_KEY']!,
            safetySettings: [
              SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
              SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
              SafetySetting(
                  HarmCategory.sexuallyExplicit, HarmBlockThreshold.high),
              SafetySetting(
                  HarmCategory.dangerousContent, HarmBlockThreshold.high),
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
    final playerName =
        player.playerName == "Мисливець" ? "гравець" : player.playerName;
    final playerRankName = QuestModel.getQuestDifficultyName(player.playerRank);

    String baselinePerformancePrompt = "";
    if (player.baselinePhysicalPerformance != null &&
        player.baselinePhysicalPerformance!.isNotEmpty) {
      baselinePerformancePrompt +=
          "\n\nБазові фізичні показники гравця (за результатами самооцінки):";
      player.baselinePhysicalPerformance!.forEach((activity, value) {
        String activityName = "";
        switch (activity) {
          case PhysicalActivity.pullUps:
            activityName = "Максимум підтягувань";
            break;
          case PhysicalActivity.pushUps:
            activityName = "Максимум віджимань";
            break;
          case PhysicalActivity.runningDurationInMin:
            activityName = "Тривалість бігу (хв)";
            break;
          case PhysicalActivity.regularExercise:
            activityName = "Регулярно займається спортом";
            break;
        }
        baselinePerformancePrompt += "\n- $activityName: $value";
      });
      baselinePerformancePrompt +=
          "\nВраховуй ці показники при генерації фізичних завдань (на Силу, Спритність, Витривалість), щоб вони були складними, але досяжними. Якщо, наприклад, гравець вказав 0 підтягувань, не давай завдання на підтягування, а запропонуй підготовчі вправи (наприклад, австралійські підтягування, негативні підтягування або вправи для зміцнення спини/рук). Адаптуй кількість повторень/тривалість до цих показників.";
    }

    String targetStatFocusPrompt = "";
    if (targetStat != null) {
      targetStatFocusPrompt = """

ЗАВДАННЯ СПЕЦІАЛЬНО ДЛЯ РОЗВИТКУ ХАРАКТЕРИСТИКИ: ${PlayerModel.getStatName(targetStat)}.
ПОТОЧНЕ ЗНАЧЕННЯ ЦІЄЇ ХАРАКТЕРИСТИКИ У ГРАВЦЯ: ${player.stats[targetStat] ?? 'N/A'}.
Адаптуй складність, опис та тип активності відповідно до цього значення та назви характеристики.
Наприклад, для Інтелекту це може бути читання, вивчення, розв'язування задач. Для Спритності - вправи на координацію, швидкість.
Для Сприйняття - завдання на уважність, спостережливість. Для Витривалості - кардіо. Для Сили - силові вправи.
Якщо значення характеристики низьке (наприклад, 1-5 для статів, які починаються з 5), завдання має бути для початківців.
Якщо високе (наприклад, 15+), завдання може бути більш просунутим.
Нагорода XP та складність (Ранг) також мають відображати це.
""";
    }

    String hpCostInstruction = "";
    if (questType !=
            QuestType
                .daily && // Не застосовуємо вартість HP до щоденних завдань для простоти
        (targetStat == PlayerStat.strength ||
            targetStat == PlayerStat.stamina ||
            targetStat == PlayerStat.agility ||
            (customPromptInstruction != null &&
                (customPromptInstruction.toLowerCase().contains("фізичн") ||
                    customPromptInstruction
                        .toLowerCase()
                        .contains("тренуван"))))) {
      hpCostInstruction = """

Додаткова інструкція щодо HP:
Якщо це завдання є фізично складним або вимагає значних зусиль (наприклад, інтенсивне тренування, подолання фізичних перешкод, бій з уявним супротивником), і його ранг складності D або вище, АБО якщо ранг завдання вищий за поточний Ранг Мисливця ($playerRankName), ти МОЖЕШ (але не зобов'язаний, роби це для приблизно 20-30% таких завдань) додати невелику "вартість здоров'я за зусилля".
Якщо додаєш вартість здоров'я, включи в JSON відповідь поле:
"hpCostOnCompletion": integer (наприклад, від 3 до ${(player.maxHp * 0.1).round().clamp(5, 20)}, тобто не більше 10% від максимального HP гравця, але в розумних межах 5-20)
Це значення буде віднято від HP гравця ПІСЛЯ успішного виконання завдання. В описі завдання це згадувати не потрібно, це буде системний ефект. Якщо вартості здоров'я немає, не додавай це поле або встанови null.
Уникай додавання hpCostOnCompletion для завдань типу "Щоденне".
""";
    }

    final prompt = """
Згенеруй ігрове завдання для рольової гри на Android в стилі аніме "Solo Leveling" (Підняття рівня наодинці).
Завдання має бути реалістичним для виконання в реальному житті, але описане в термінах ігрового світу.
Фокусуйся на саморозвитку, фізичних або інтелектуальних вправах, дослідженні або корисних звичках.

Інформація про гравця:
Ім'я: $playerName
Рівень: ${player.level}
Ранг Мисливця: $playerRankName 
Сила: ${player.stats[PlayerStat.strength]}
Спритність: ${player.stats[PlayerStat.agility]}
Інтелект: ${player.stats[PlayerStat.intelligence]}
Сприйняття: ${player.stats[PlayerStat.perception]}
Витривалість: ${player.stats[PlayerStat.stamina]}
$baselinePerformancePrompt

Параметри для генерації завдання:
Тип завдання: ${QuestModel.getQuestTypeName(questType)}
${customPromptInstruction != null ? '\nДодаткова інструкція: $customPromptInstruction' : ''}
$targetStatFocusPrompt 
$hpCostInstruction
Завдання повинно бути унікальним та цікавим.
Воно повинно містити:
1.  Назва (коротка, інтригуюча, в стилі Solo Leveling, 3-5 слів).
2.  Опис (детальніше, що потрібно зробити гравцю, 2-4 речення. Опис має бути практичним, що гравець може зробити в реальності).
3.  Ранг складності (F, E, D, C, B, A, S). Цей ранг має ВІДПОВІДАТИ $playerRankName рангу гравця.
4.  Нагорода XP (ціле число). Адаптуй до рівня гравця та рангу завдання.
    Приклади XP для рівня ${player.level} та рангу $playerRankName:
    - Ранг F: ${10 + player.level * 2}-${20 + player.level * 3} XP (якщо гравець F рангу)
    - Ранг E: ${20 + player.level * 3}-${35 + player.level * 4} XP (якщо гравець E рангу)
    - Ранг D: ${35 + player.level * 4}-${50 + player.level * 5} XP (якщо гравець D рангу)
    - Ранг C: ${50 + player.level * 5}-${75 + player.level * 6} XP (якщо гравець C рангу)
    Якщо є фокусна характеристика (targetStat) і її значення у гравця високе, XP може бути трохи більшим для відповідного рангу. Якщо низьке - трохи меншим.
5.  Фокусна характеристика (опціонально, але ОБОВ'ЯЗКОВО якщо передано targetStat для генерації): назва характеристики (strength, agility, intelligence, perception, stamina), на яку завдання має найбільший вплив. Має збігатися з переданим targetStat, якщо він був.

Надай відповідь ТІЛЬКИ у форматі JSON об'єкту з такими полями (використовуй подвійні лапки для ключів та рядкових значень):
"title": "string",
"description": "string",
"difficulty": "string (F, E, D, C, B, A, S)",
"xpReward": integer,
"targetStat": "stat_name_english" (або null, але має бути заповнено, якщо завдання генерується для конкретного targetStat)
"hpCostOnCompletion": integer (або null)

Приклад бажаного JSON (не копіюй його, це лише приклад структури):
{
  "title": "Тренування Тіні",
  "description": "Твій показник віджимань - ${player.baselinePhysicalPerformance?[PhysicalActivity.pushUps] ?? 'невідомий'}. Спробуй виконати 3 підходи по ${((player.baselinePhysicalPerformance?[PhysicalActivity.pushUps] as int? ?? 10) * 0.6).round()} віджимань. Кожен рух має бути чітким.",
  "difficulty": "E",
  "xpReward": 30,
  "targetStat": "strength",
  "hpCostOnCompletion": 5
}
Переконайся, що назва характеристики в targetStat є однією з: strength, agility, intelligence, perception, stamina.
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
      if (jsonResponse['difficulty'] != null) {
        try {
          difficulty = QuestDifficulty.values
              .byName(jsonResponse['difficulty'].toString().toUpperCase());
        } catch (e) {
          print(
              "Gemini API: Invalid difficulty value: ${jsonResponse['difficulty']}. Defaulting to player rank: ${player.playerRank.name}.");
          difficulty = player
              .playerRank; // Якщо Gemini помилився з рангом, ставимо ранг гравця
        }
      } else {
        print(
            "Gemini API: No difficulty provided. Defaulting to player rank: ${player.playerRank.name}.");
        difficulty = player.playerRank; // Якщо Gemini не надав ранг
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
          jsonResponse['targetStat'] is String &&
          (jsonResponse['targetStat'] as String).isNotEmpty) {
        try {
          parsedTargetStat = PlayerStat.values
              .byName(jsonResponse['targetStat'].toString().toLowerCase());
        } catch (e) {
          print(
              "Gemini API: Invalid targetStat value: ${jsonResponse['targetStat']}. Setting to null.");
        }
      }

      int? hpCost = jsonResponse['hpCostOnCompletion'] as int?;
      if (hpCost != null) {
        if (hpCost < 0) hpCost = 0;
        hpCost = hpCost.clamp(0, (player.maxHp * 0.1).round());
        if (hpCost == 0) hpCost = null;
      }

      return QuestModel(
        title: jsonResponse['title'],
        description: jsonResponse['description'],
        xpReward: (jsonResponse['xpReward'] as num).toInt(),
        difficulty: difficulty,
        type: questType, // Тип, який ми передали для генерації
        targetStat: parsedTargetStat ?? targetStat,
        hpCostOnCompletion: hpCost,
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
