import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/models/player_model.dart';
import 'package:awakening/models/quest_model.dart';
import 'package:awakening/models/skill_model.dart';
import 'package:awakening/models/system_message_model.dart';

void main() {
  group('PlayerModel', () {
    test('should create player with default values', () {
      final player = PlayerModel();
      expect(player.playerName, equals("Мисливець"));
      expect(player.level, equals(1));
      expect(player.stats[PlayerStat.strength], equals(5));
      expect(player.maxHp, greaterThan(0));
      expect(player.maxMp, greaterThan(0));
    });
  });

  group('QuestModel', () {
    test('should create quest with required fields', () {
      final quest = QuestModel(
        title: 'Test Quest',
        description: 'A quest for testing',
        xpReward: 100,
        type: QuestType.daily,
        difficulty: QuestDifficulty.F,
      );
      expect(quest.title, equals('Test Quest'));
      expect(quest.isCompleted, isFalse);
      expect(quest.xpReward, equals(100));
    });
  });

  group('SkillModel', () {
    test('should create skill with required fields', () {
      final skill = SkillModel(
        id: 'skill1',
        name: 'Test Skill',
        description: 'A skill for testing',
        skillType: SkillType.passive,
      );
      expect(skill.name, equals('Test Skill'));
      expect(skill.skillType, SkillType.passive);
      expect(skill.levelRequirement, equals(1));
    });
  });

  group('SystemMessageModel', () {
    test('should create system message with required fields', () {
      final msg = SystemMessageModel(
        text: 'Test message',
        type: MessageType.info,
      );
      expect(msg.text, equals('Test message'));
      expect(msg.type, MessageType.info);
      expect(msg.isRead, isFalse);
    });
  });
}
