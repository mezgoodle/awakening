import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/models/player_model.dart';
import 'package:awakening/models/quest_model.dart';

void main() {
  group('PlayerModel', () {
    test('calculateXpForLevel calculates XP correctly', () {
      expect(PlayerModel.calculateXpForLevel(1), 100);
      expect(PlayerModel.calculateXpForLevel(2), 329);
      expect(PlayerModel.calculateXpForLevel(10), 4826);
      expect(PlayerModel.calculateXpForLevel(50), 103833);
      expect(PlayerModel.calculateXpForLevel(0), 100);
      expect(PlayerModel.calculateXpForLevel(-5), 100);
    });

    test('calculateRankByLevel determines rank correctly', () {
      expect(PlayerModel.calculateRankByLevel(1), QuestDifficulty.F);
      expect(PlayerModel.calculateRankByLevel(4), QuestDifficulty.F);
      expect(PlayerModel.calculateRankByLevel(5), QuestDifficulty.E);
      expect(PlayerModel.calculateRankByLevel(9), QuestDifficulty.E);
      expect(PlayerModel.calculateRankByLevel(10), QuestDifficulty.D);
      expect(PlayerModel.calculateRankByLevel(19), QuestDifficulty.D);
      expect(PlayerModel.calculateRankByLevel(20), QuestDifficulty.C);
      expect(PlayerModel.calculateRankByLevel(29), QuestDifficulty.C);
      expect(PlayerModel.calculateRankByLevel(30), QuestDifficulty.B);
      expect(PlayerModel.calculateRankByLevel(39), QuestDifficulty.B);
      expect(PlayerModel.calculateRankByLevel(40), QuestDifficulty.A);
      expect(PlayerModel.calculateRankByLevel(49), QuestDifficulty.A);
      expect(PlayerModel.calculateRankByLevel(50), QuestDifficulty.S);
      expect(PlayerModel.calculateRankByLevel(100), QuestDifficulty.S);
    });

    test('calculates HP and MP correctly on initialization', () {
      final player = PlayerModel(
        level: 10,
        initialStats: {
          PlayerStat.strength: 10,
          PlayerStat.agility: 10,
          PlayerStat.intelligence: 12,
          PlayerStat.perception: 10,
          PlayerStat.stamina: 15,
        },
      );

      // maxHp = (level * 10) + (stamina * 5) + 50
      // maxHp = (10 * 10) + (15 * 5) + 50 = 100 + 75 + 50 = 225
      expect(player.maxHp, 225);
      expect(player.currentHp, 225);

      // maxMp = (level * 5) + (intelligence * 3) + 20
      // maxMp = (10 * 5) + (12 * 3) + 20 = 50 + 36 + 20 = 106
      expect(player.maxMp, 106);
      expect(player.currentMp, 106);
    });

    test('correctly applies damage and healing', () {
      final player = PlayerModel(level: 1, initialStats: {PlayerStat.stamina: 10, PlayerStat.intelligence: 10}); // maxHp=110, maxMp=65

      player.takeDamage(20);
      expect(player.currentHp, 90);

      player.takeDamage(100);
      expect(player.currentHp, 0);

      player.restoreHp(30);
      expect(player.currentHp, 30);

      player.restoreHp(200);
      expect(player.currentHp, 110);

      player.useMp(15);
      expect(player.currentMp, 50);

      player.useMp(100);
      expect(player.currentMp, 0);

      player.restoreMp(25);
      expect(player.currentMp, 25);

      player.restoreMp(100);
      expect(player.currentMp, 65);
    });

    test('toJson and fromJson work correctly', () {
      final player = PlayerModel(
        playerName: 'Test Player',
        level: 5,
        xp: 500,
        initialStats: {
          PlayerStat.strength: 8,
          PlayerStat.agility: 7,
          PlayerStat.intelligence: 6,
          PlayerStat.perception: 9,
          PlayerStat.stamina: 10,
        },
        availableStatPoints: 2,
        availableSkillPoints: 1,
        initialLearnedSkillIds: ['skill1', 'skill2'],
        initialInventory: [{'itemId': 'potion', 'quantity': 5}],
        initialSurveyCompleted: true,
        playerRank: QuestDifficulty.E,
      );

      final json = player.toJson();
      final newPlayer = PlayerModel.fromJson(json);

      expect(newPlayer.playerName, player.playerName);
      expect(newPlayer.level, player.level);
      expect(newPlayer.xp, player.xp);
      expect(newPlayer.stats[PlayerStat.strength], player.stats[PlayerStat.strength]);
      expect(newPlayer.availableStatPoints, player.availableStatPoints);
      expect(newPlayer.availableSkillPoints, player.availableSkillPoints);
      expect(newPlayer.learnedSkillIds, player.learnedSkillIds);
      expect(newPlayer.inventory.length, player.inventory.length);
      expect(newPlayer.inventory[0]['itemId'], player.inventory[0]['itemId']);
      expect(newPlayer.initialSurveyCompleted, player.initialSurveyCompleted);
      expect(newPlayer.playerRank, player.playerRank);
      expect(newPlayer.maxHp, player.maxHp);
      expect(newPlayer.currentHp, player.currentHp);
      expect(newPlayer.maxMp, player.maxMp);
      expect(newPlayer.currentMp, player.currentMp);
    });
  });
}
