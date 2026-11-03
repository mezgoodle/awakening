import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/models/item_model.dart';
import 'package:awakening/models/player_model.dart';
import 'package:awakening/models/quest_model.dart';

void main() {
  group('PlayerModel Tests', () {
    test('Initial level and default stats calculation', () {
      final player = PlayerModel();

      expect(player.level, 1);
      expect(player.xp, 0);
      expect(player.playerRank, QuestDifficulty.F);
      expect(player.stats[PlayerStat.strength], 5);
      expect(player.stats[PlayerStat.stamina], 5);

      // maxHp = level*10 + stamina*5 + 50 = 10 + 25 + 50 = 85
      expect(player.maxHp, 85);
      expect(player.currentHp, 85);

      // maxMp = level*5 + intelligence*3 + 20 = 5 + 15 + 20 = 40
      expect(player.maxMp, 40);
      expect(player.currentMp, 40);
    });

    test('Rank progression by level', () {
      expect(PlayerModel.calculateRankByLevel(1), QuestDifficulty.F);
      expect(PlayerModel.calculateRankByLevel(5), QuestDifficulty.E);
      expect(PlayerModel.calculateRankByLevel(10), QuestDifficulty.D);
      expect(PlayerModel.calculateRankByLevel(20), QuestDifficulty.C);
      expect(PlayerModel.calculateRankByLevel(30), QuestDifficulty.B);
      expect(PlayerModel.calculateRankByLevel(40), QuestDifficulty.A);
      expect(PlayerModel.calculateRankByLevel(50), QuestDifficulty.S);
    });

    test('Serialization and deserialization', () {
      final player = PlayerModel(
        playerName: 'Sung Jin-Woo',
        level: 10,
        xp: 150,
        playerRank: QuestDifficulty.D,
        initialInventory: const [
          QuestItemReward(itemId: 'potion_health_small', quantity: 3),
        ],
      );

      final json = player.toJson();
      final restored = PlayerModel.fromJson(json);

      expect(restored.playerName, 'Sung Jin-Woo');
      expect(restored.level, 10);
      expect(restored.xp, 150);
      expect(restored.playerRank, QuestDifficulty.D);
      expect(restored.inventory.length, 1);
      expect(restored.inventory.first.itemId, 'potion_health_small');
      expect(restored.inventory.first.quantity, 3);
    });
  });

  group('QuestModel Tests', () {
    test('Quest creation and serialization', () {
      final quest = QuestModel(
        title: 'Daily Shadow Training',
        description: 'Complete 50 push-ups.',
        xpReward: 35,
        type: QuestType.daily,
        difficulty: QuestDifficulty.E,
        targetStat: PlayerStat.strength,
        itemRewards: const [
          QuestItemReward(itemId: 'potion_health_small', quantity: 1),
        ],
      );

      final json = quest.toJson();
      final restored = QuestModel.fromJson(json);

      expect(restored.title, 'Daily Shadow Training');
      expect(restored.xpReward, 35);
      expect(restored.type, QuestType.daily);
      expect(restored.difficulty, QuestDifficulty.E);
      expect(restored.targetStat, PlayerStat.strength);
      expect(restored.itemRewards?.length, 1);
      expect(restored.itemRewards?.first.itemId, 'potion_health_small');
    });
  });

  group('InventoryItem Tests', () {
    test('Effects summary formatting', () {
      const item = InventoryItem(
        itemId: 'potion_super',
        name: 'Super Elixir',
        description: 'Restores HP and MP.',
        type: ItemType.potion,
        iconPath: 'assets/icons/items/health-potion.svg',
        quantity: 2,
        effects: {
          ItemEffectType.restoreHp: 50,
          ItemEffectType.restoreMpPercent: 20,
        },
      );

      expect(item.effectsSummary, contains('Restores 50 HP'));
      expect(item.effectsSummary, contains('Restores 20% Max MP'));
    });
  });
}
