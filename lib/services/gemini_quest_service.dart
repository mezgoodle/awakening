import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import 'app_logger_service.dart';

class GeminiQuestService {
  final GenerativeModel _model;
  final AppLoggerService _logger = AppLoggerService();

  static const String modelName = 'gemini-2.5-flash-lite';

  GeminiQuestService()
      : _model = FirebaseAI.googleAI().generativeModel(
          model: modelName,
          safetySettings: [
            SafetySetting(
                HarmCategory.harassment, HarmBlockThreshold.high, null),
            SafetySetting(
                HarmCategory.hateSpeech, HarmBlockThreshold.high, null),
            SafetySetting(
                HarmCategory.sexuallyExplicit, HarmBlockThreshold.high, null),
            SafetySetting(
                HarmCategory.dangerousContent, HarmBlockThreshold.high, null),
          ],
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            maxOutputTokens: 1024,
          ),
        );

  Future<QuestModel?> generateQuest({
    required PlayerModel player,
    QuestType questType = QuestType.generated,
    PlayerStat? targetStat,
    String? customPromptInstruction,
    List<String> availableItemIds = const [],
  }) async {
    final playerName =
        player.playerName == "Hunter" ? "player" : player.playerName;
    final playerRankName = QuestModel.getQuestDifficultyName(player.playerRank);

    String baselinePerformancePrompt = "";
    if (player.baselinePhysicalPerformance != null &&
        player.baselinePhysicalPerformance!.isNotEmpty) {
      baselinePerformancePrompt +=
          "\n\nBaseline player physical stats (based on self-assessment):";
      player.baselinePhysicalPerformance!.forEach((activity, value) {
        String activityName = "";
        switch (activity) {
          case PhysicalActivity.pullUps:
            activityName = "Max Pull-ups";
            break;
          case PhysicalActivity.pushUps:
            activityName = "Max Push-ups";
            break;
          case PhysicalActivity.runningDurationInMin:
            activityName = "Running Duration (min)";
            break;
          case PhysicalActivity.regularExercise:
            activityName = "Exercises Regularly";
            break;
        }
        baselinePerformancePrompt += "\n- $activityName: $value";
      });
      baselinePerformancePrompt +=
          "\nConsider these stats when generating physical quests (Strength, Agility, Stamina) to make them challenging but achievable. Adapt reps or duration appropriately.";
    }

    String targetStatFocusPrompt = "";
    if (targetStat != null) {
      targetStatFocusPrompt = """
QUEST SPECIFICALLY FOCUSED ON DEVELOPING STAT: ${PlayerModel.getStatName(targetStat)}.
CURRENT PLAYER VALUE FOR THIS STAT: ${player.stats[targetStat] ?? 'N/A'}.
Adapt the complexity, description, and activity according to this value and stat name:
- Strength: bodyweight or resistance exercises
- Agility: flexibility, coordination, speed
- Intelligence: reading, studying, problem solving
- Perception: mindfulness, observation, environmental awareness
- Stamina: cardio, endurance, walking/running
""";
    }

    String hpCostInstruction = "";
    if (questType != QuestType.daily &&
        (targetStat == PlayerStat.strength ||
            targetStat == PlayerStat.stamina ||
            targetStat == PlayerStat.agility ||
            (customPromptInstruction != null &&
                (customPromptInstruction.toLowerCase().contains("physical") ||
                    customPromptInstruction
                        .toLowerCase()
                        .contains("training"))))) {
      final maxHpCost = (player.maxHp * 0.1).round().clamp(5, 20);
      hpCostInstruction = """
Additional instruction regarding HP:
If this quest is physically demanding or requires significant effort, AND its difficulty is D or higher, you MAY add a small health cost in "hpCostOnCompletion": integer between 3 and $maxHpCost. If there is no health cost, do not add this field or set it to null.
""";
    }

    String itemRewardsInstruction = "";
    if (availableItemIds.isNotEmpty) {
      final itemIdsString = availableItemIds.join(', ');
      itemRewardsInstruction = """
Additional instruction regarding item rewards:
For some quests (approx 20% chance), you can add an item reward:
"itemRewards": [ { "itemId": "string", "quantity": 1 } ]
IMPORTANT: The value for "itemId" MUST be selected from: [$itemIdsString].
Do not invent unlisted item IDs. If no item reward, set "itemRewards" to null or omit it.
""";
    }

    final prompt = """
Generate a real-life self-improvement RPG quest in English styled like the anime "Solo Leveling".
The quest must be realistic for a person to execute in real life, but written with the epic atmosphere of a Hunter system.

Player Information:
- Name: $playerName
- Level: ${player.level}
- Hunter Rank: $playerRankName
- Strength: ${player.stats[PlayerStat.strength]}
- Agility: ${player.stats[PlayerStat.agility]}
- Intelligence: ${player.stats[PlayerStat.intelligence]}
- Perception: ${player.stats[PlayerStat.perception]}
- Stamina: ${player.stats[PlayerStat.stamina]}
$baselinePerformancePrompt

Parameters:
- Quest Type: ${QuestModel.getQuestTypeName(questType)}
${customPromptInstruction != null ? '- Custom Request: $customPromptInstruction' : ''}
$targetStatFocusPrompt
$hpCostInstruction
$itemRewardsInstruction

Requirements:
1. Title: Intriguing, Solo Leveling style, 3-5 words in English.
2. Description: Detailed, practical real-life task, 2-4 sentences in English.
3. Difficulty Rank: F, E, D, C, B, A, or S (must match player rank $playerRankName).
4. XP Reward: Realistic integer scaled to level ${player.level} (e.g. ${15 + player.level * 3} - ${30 + player.level * 4} XP).
5. Target Stat: one of "strength", "agility", "intelligence", "perception", "stamina".

Return ONLY a valid JSON object with keys:
"title": string,
"description": string,
"difficulty": string,
"xpReward": integer,
"targetStat": string or null,
"hpCostOnCompletion": integer or null,
"itemRewards": [ { "itemId": string, "quantity": integer } ] or null
""";

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text == null || response.text!.trim().isEmpty) {
        _logger.writeLog(
          message: "Gemini API returned empty response",
          severity: LogSeverity.error,
        );
        return null;
      }

      String jsonString = response.text!.trim();
      if (jsonString.startsWith('```')) {
        jsonString = jsonString
            .replaceFirst(RegExp(r'^```(json)?'), '')
            .replaceFirst(RegExp(r'```$'), '')
            .trim();
      }

      final jsonStartIndex = jsonString.indexOf('{');
      final jsonEndIndex = jsonString.lastIndexOf('}');
      if (jsonStartIndex != -1 && jsonEndIndex != -1 && jsonEndIndex > jsonStartIndex) {
        jsonString = jsonString.substring(jsonStartIndex, jsonEndIndex + 1);
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

      QuestDifficulty difficulty = player.playerRank;
      if (jsonResponse['difficulty'] != null) {
        try {
          difficulty = QuestDifficulty.values.byName(
              jsonResponse['difficulty'].toString().trim().toUpperCase());
        } catch (_) {}
      }

      PlayerStat? parsedTargetStat;
      if (jsonResponse['targetStat'] != null) {
        try {
          parsedTargetStat = PlayerStat.values.byName(
              jsonResponse['targetStat'].toString().trim().toLowerCase());
        } catch (_) {}
      }

      List<QuestItemReward>? itemRewards;
      if (jsonResponse['itemRewards'] != null && jsonResponse['itemRewards'] is List) {
        final rawRewards = jsonResponse['itemRewards'] as List<dynamic>;
        final List<QuestItemReward> validRewards = [];
        for (final item in rawRewards) {
          if (item is Map<String, dynamic> && item['itemId'] != null) {
            final id = item['itemId'].toString();
            final qty = (item['quantity'] as num?)?.toInt() ?? 1;
            if (availableItemIds.isEmpty || availableItemIds.contains(id)) {
              validRewards.add(QuestItemReward(itemId: id, quantity: qty));
            }
          }
        }
        if (validRewards.isNotEmpty) {
          itemRewards = validRewards;
        }
      }

      int? hpCost = (jsonResponse['hpCostOnCompletion'] as num?)?.toInt();
      if (hpCost != null) {
        hpCost = hpCost.clamp(0, (player.maxHp * 0.1).round());
        if (hpCost <= 0) hpCost = null;
      }

      final quest = QuestModel(
        title: jsonResponse['title'] as String? ?? 'System Quest',
        description: jsonResponse['description'] as String? ?? '',
        xpReward: (jsonResponse['xpReward'] as num?)?.toInt() ?? 25,
        difficulty: difficulty,
        type: questType,
        targetStat: parsedTargetStat ?? targetStat,
        hpCostOnCompletion: hpCost,
        itemRewards: itemRewards,
      );

      _logger.writeLog(
        message: "Quest generated successfully: ${quest.title}",
        severity: LogSeverity.info,
      );

      return quest;
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error generating quest with Gemini: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }
}
