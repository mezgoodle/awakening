import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/models/quest_model.dart';
import 'package:awakening/models/player_model.dart';

void main() {
  group('QuestModel', () {
    test('getQuestTypeName returns correct names', () {
      expect(QuestModel.getQuestTypeName(QuestType.daily), "Щоденне");
      expect(QuestModel.getQuestTypeName(QuestType.weekly), "Щотижневе");
      expect(QuestModel.getQuestTypeName(QuestType.milestone), "Віха");
      expect(QuestModel.getQuestTypeName(QuestType.generated), "Згенероване");
      expect(QuestModel.getQuestTypeName(QuestType.story), "Сюжетне");
      expect(QuestModel.getQuestTypeName(QuestType.rankUpChallenge), "Рангове Випробування");
    });

    test('getQuestDifficultyName returns correct names', () {
      expect(QuestModel.getQuestDifficultyName(QuestDifficulty.F), "F");
      expect(QuestModel.getQuestDifficultyName(QuestDifficulty.A), "A");
      expect(QuestModel.getQuestDifficultyName(QuestDifficulty.S), "S");
    });

    test('toJson and fromJson work correctly', () {
      final quest = QuestModel(
        title: 'Test Quest',
        description: 'Test Description',
        xpReward: 100,
        type: QuestType.generated,
        difficulty: QuestDifficulty.C,
        targetStat: PlayerStat.intelligence,
        isCompleted: true,
        hpCostOnCompletion: 10,
        itemRewards: [{'itemId': 'potion', 'quantity': 1}],
      );

      final json = quest.toJson();
      final newQuest = QuestModel.fromJson(json);

      expect(newQuest.title, quest.title);
      expect(newQuest.description, quest.description);
      expect(newQuest.xpReward, quest.xpReward);
      expect(newQuest.type, quest.type);
      expect(newQuest.difficulty, quest.difficulty);
      expect(newQuest.targetStat, quest.targetStat);
      expect(newQuest.isCompleted, quest.isCompleted);
      expect(newQuest.hpCostOnCompletion, quest.hpCostOnCompletion);
      expect(newQuest.itemRewards?.length, quest.itemRewards?.length);
      expect(newQuest.itemRewards?[0]['itemId'], quest.itemRewards?[0]['itemId']);
    });
  });
}
