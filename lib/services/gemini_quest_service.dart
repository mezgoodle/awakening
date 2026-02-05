import 'dart:convert';
import 'package:awakening/services/cloud_logger_service.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';

class GeminiQuestService {
  final GenerativeModel _model;
  final CloudLoggerService _logger = CloudLoggerService();

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
            generationConfig: GenerationConfig(maxOutputTokens: 1024));

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
          "\nConsider these stats when generating physical quests (Strength, Agility, Stamina) to make them challenging but achievable. For example, if the player indicated 0 pull-ups, do not give a pull-up quest, but suggest preparatory exercises (e.g., Australian pull-ups, negatives, or back/arm strengthening exercises). Adapt the number of reps/duration to these stats.";
    }

    String targetStatFocusPrompt = "";
    if (targetStat != null) {
      targetStatFocusPrompt = """

QUEST SPECIFICALLY FOCUSED ON DEVELOPING STAT: ${PlayerModel.getStatName(targetStat)}.
CURRENT PLAYER VALUE FOR THIS STAT: ${player.stats[targetStat] ?? 'N/A'}.
Adapt the complexity, description, and type of activity according to this value and stat name.
For example, for Intelligence, it could be reading, studying, solving puzzles. For Agility - coordination or speed exercises.
For Perception - mindfulness or observation tasks. For Stamina - cardio. For Strength - strength exercises.
If the stat value is low (e.g., 1-5 for stats starting at 5), the quest should be for beginners.
If high (e.g., 15+), the quest can be more advanced.
XP reward and Difficulty (Rank) should also reflect this.
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
      hpCostInstruction = """

Additional instruction regarding HP:
If this quest is physically demanding or requires significant effort (e.g., intense training, overcoming physical obstacles, fighting an imaginary opponent), AND its difficulty rank is D or higher, OR if the quest rank is higher than the current Hunter Rank ($playerRankName), you MAY (but are not required to, do this for about 20-30% of such quests) add a small "health cost for effort".
If you add a health cost, include the field in the JSON response:
"hpCostOnCompletion": integer (e.g., from 3 to ${(player.maxHp * 0.1).round().clamp(5, 20)}, i.e., not more than 10% of player's max HP, but within reasonable limits 5-20)
This value will be deducted from the player's HP AFTER successful quest completion. Do not mention this in the quest description, it will be a system effect. If there is no health cost, do not add this field or set it to null.
Avoid adding hpCostOnCompletion for "Daily" type quests.
""";
    }

    String itemRewardsInstruction = "";
    if (availableItemIds.isNotEmpty) {
      final itemIdsString = availableItemIds.join(', ');

      itemRewardsInstruction = """

Additional instruction regarding item rewards:
For some quests (approximately 15-20% of cases), especially difficult ones, you can add an item reward.
If you add an item, include the field in the JSON response:
"itemRewards": [ { "itemId": "string", "quantity": integer } ]
IMPORTANT: The value for "itemId" MUST be chosen from the following list of valid IDs: [$itemIdsString].
Do not invent your own itemId.
Example: "itemRewards": [ { "itemId": "${availableItemIds.first}", "quantity": 1 } ]
If there are no item rewards, do not add this field or set it to null.
""";
    }

    final prompt = """
Generate a game quest for an Android RPG in the style of the anime "Solo Leveling".
The quest should be realistic to perform in real life but described in game world terms.
Focus on self-improvement, physical or intellectual exercises, exploration, or useful habits.

Player Information:
Name: $playerName
Level: ${player.level}
Hunter Rank: $playerRankName 
Strength: ${player.stats[PlayerStat.strength]}
Agility: ${player.stats[PlayerStat.agility]}
Intelligence: ${player.stats[PlayerStat.intelligence]}
Perception: ${player.stats[PlayerStat.perception]}
Stamina: ${player.stats[PlayerStat.stamina]}
$baselinePerformancePrompt

Parameters for quest generation:
Quest Type: ${QuestModel.getQuestTypeName(questType)}
${customPromptInstruction != null ? '\nAdditional instruction: $customPromptInstruction' : ''}
$targetStatFocusPrompt 
$hpCostInstruction
The quest must be unique and interesting.
It must contain:
1.  Title (short, intriguing, in "Solo Leveling" style, 3-5 words).
2.  Description (detailed, practical, 2-4 sentences. The description must be practical, something the player can do in reality).
3.  Difficulty Rank (F, E, D, C, B, A, S). This rank must MATCH the player's rank $playerRankName.
4.  XP Reward (integer). Adapt to the player's level and quest rank.
    XP Examples for level ${player.level} and rank $playerRankName:
    - Rank F: ${10 + player.level * 2}-${20 + player.level * 3} XP (if player is Rank F)
    - Rank E: ${20 + player.level * 3}-${35 + player.level * 4} XP (if player is Rank E)
    - Rank D: ${35 + player.level * 4}-${50 + player.level * 5} XP (if player is Rank D)
    - Rank C: ${50 + player.level * 5}-${75 + player.level * 6} XP (if player is Rank C)
    If there is a focus stat (targetStat) and the player's value is high, XP can be slightly higher for the corresponding rank. If low - slightly lower.
5.  Focus Stat (optional, but MANDATORY if targetStat is passed for generation): stat name (strength, agility, intelligence, perception, stamina) that the quest impacts the most. Must match the passed targetStat if it was present.

$itemRewardsInstruction

Provide the response ONLY in valid JSON object format with the following fields (use double quotes for keys and string values):
"title": "string",
"description": "string",
"difficulty": "string (F, E, D, C, B, A, S)",
"xpReward": integer,
"targetStat": "stat_name_english" (or null, but must be filled if the quest is generated for a specific targetStat)
"hpCostOnCompletion": integer (or null)
"itemRewards": [ { "itemId": "string", "quantity": integer } ] (or null)

Example of desired JSON (do not copy it, this is just a structure example):
{
  "title": "Shadow Training",
  "description": "Your push-up stat is ${player.baselinePhysicalPerformance?[PhysicalActivity.pushUps] ?? 'unknown'}. Try to perform 3 sets of ${((player.baselinePhysicalPerformance?[PhysicalActivity.pushUps] as int? ?? 10) * 0.6).round()} push-ups. Every movement must be precise.",
  "difficulty": "E",
  "xpReward": 30,
  "targetStat": "strength",
  "hpCostOnCompletion": 5
}
Ensure that the stat name in targetStat is one of: strength, agility, intelligence, perception, stamina.
Do not add any comments or explanations outside the JSON object. Only JSON.
""";
    // print("--- PROMPT ---");
    // print(prompt);
    // print("--------------");

    try {
      // return null;
      final response = await _model.generateContent([Content.text(prompt)]);

      // print("--- RESPONSE ---");
      // print(response.text);
      // print("----------------");

      if (response.text == null || response.text!.isEmpty) {
        _logger.writeLog(
            message: "Gemini API returned empty response",
            payload: {
              "prompt": prompt,
              "model": modelName,
            },
            severity: CloudLogSeverity.error);
        return null;
      }

      String jsonString = response.text!;
      final jsonStartIndex = jsonString.indexOf('{');
      final jsonEndIndex = jsonString.lastIndexOf('}');

      if (jsonStartIndex != -1 &&
          jsonEndIndex != -1 &&
          jsonEndIndex > jsonStartIndex) {
        jsonString = jsonString.substring(jsonStartIndex, jsonEndIndex + 1);
      } else {
        _logger.writeLog(
            message: "Gemini API returned invalid JSON response",
            payload: {
              "response": response.text,
              "prompt": prompt,
              "model": modelName,
            },
            severity: CloudLogSeverity.error);
        return null;
      }

      final Map<String, dynamic> jsonResponse = jsonDecode(jsonString);

      if (jsonResponse['title'] == null ||
          jsonResponse['description'] == null ||
          jsonResponse['difficulty'] == null ||
          jsonResponse['xpReward'] == null) {
        _logger.writeLog(
          message: "Gemini API response missing required fields",
          payload: {
            "response": jsonResponse,
            "fields": {
              "title": jsonResponse['title'],
              "description": jsonResponse['description'],
              "difficulty": jsonResponse['difficulty'],
              "xpReward": jsonResponse['xpReward'],
            },
            "prompt": prompt,
            "model": modelName,
          },
          severity: CloudLogSeverity.error,
        );
        return null;
      }

      QuestDifficulty difficulty;
      if (jsonResponse['difficulty'] != null) {
        try {
          difficulty = QuestDifficulty.values
              .byName(jsonResponse['difficulty'].toString().toUpperCase());
        } catch (e) {
          _logger.writeLog(
            message:
                "Gemini API returned invalid difficulty value: ${jsonResponse['difficulty']}",
            payload: {
              "difficulty": jsonResponse['difficulty'],
              "prompt": prompt,
              "playerRank": player.playerRank.name,
              "model": modelName,
            },
            severity: CloudLogSeverity.error,
          );
          difficulty = player.playerRank;
        }
      } else {
        _logger.writeLog(
          message:
              "Gemini API: No difficulty provided. Defaulting to player rank: ${player.playerRank.name}.",
          payload: {
            "prompt": prompt,
            "playerRank": player.playerRank.name,
            "model": modelName,
          },
          severity: CloudLogSeverity.warning,
        );
        difficulty = player.playerRank;
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
              _logger.writeLog(
                message:
                    "Gemini API: Invalid stat name '$key' in statRewards. Skipping.",
                payload: {
                  "statName": key,
                  "value": value,
                  "prompt": prompt,
                  "model": modelName,
                },
                severity: CloudLogSeverity.warning,
              );
              return const MapEntry(PlayerStat.strength, 0);
            }
          },
        )..removeWhere(
            (key, value) => value == 0 && key == PlayerStat.strength);
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
          _logger.writeLog(
            message:
                "Gemini API: Invalid targetStat value: ${jsonResponse['targetStat']}. Defaulting to null.",
            payload: {
              "targetStat": jsonResponse['targetStat'],
              "prompt": prompt,
              "model": modelName,
            },
            severity: CloudLogSeverity.warning,
          );
        }
      }

      List<Map<String, dynamic>>? itemRewards;
      if (jsonResponse['itemRewards'] != null &&
          jsonResponse['itemRewards'] is List) {
        final rawRewards = (jsonResponse['itemRewards'] as List<dynamic>);
        itemRewards = [];
        for (var itemData in rawRewards) {
          if (itemData is Map<String, dynamic> &&
              itemData['itemId'] != null &&
              availableItemIds.contains(itemData['itemId'])) {
            itemRewards.add(itemData);
          } else {
            debugPrint(
                "Warning: Gemini returned an invalid or non-existent itemId: ${itemData['itemId']}. Skipping.");
          }
        }
        if (itemRewards.isEmpty) itemRewards = null;
      }

      int? hpCost = jsonResponse['hpCostOnCompletion'] as int?;
      if (hpCost != null) {
        if (hpCost < 0) hpCost = 0;
        hpCost = hpCost.clamp(0, (player.maxHp * 0.1).round());
        if (hpCost == 0) hpCost = null;
      }

      final quest = QuestModel(
        title: jsonResponse['title'],
        description: jsonResponse['description'],
        xpReward: (jsonResponse['xpReward'] as num).toInt(),
        difficulty: difficulty,
        type: questType,
        targetStat: parsedTargetStat ?? targetStat,
        hpCostOnCompletion: hpCost,
        itemRewards: itemRewards,
      );
      _logger.writeLog(
        message: "Quest generated successfully",
        payload: {
          "message": "Quest generated successfully",
          "quest": quest.toJson(),
          "prompt": prompt,
          "model": modelName,
        },
        severity: CloudLogSeverity.info,
      );

      return quest;
    } catch (e) {
      _logger.writeLog(
        message: "Error generating quest via FirebaseAI (Gemini)",
        severity: CloudLogSeverity.error,
        payload: {
          "prompt": prompt,
          "model": modelName,
          "error": e.toString(),
        },
      );
      if (e is FirebaseAIException) {
        _logger.writeLog(
          message: "FirebaseAIException details",
          severity: CloudLogSeverity.error,
          payload: {
            "prompt": prompt,
            "model": modelName,
            "error": e.toString(),
          },
        );
      }
      return null;
    }
  }
}
