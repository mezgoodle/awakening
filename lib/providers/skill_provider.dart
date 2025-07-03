import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../models/skill_model.dart';
import '../models/player_model.dart';

class SkillProvider with ChangeNotifier {
  final List<SkillModel> _allSkills = [
    SkillModel(
      id: 'passive_toughness_1',
      name: 'Фізична Закалка I',
      description: 'Ваше тіло стає міцнішим. +5% до максимального HP.',
      skillType: SkillType.passive,
      levelRequirement: 5,
      statRequirements: {PlayerStat.stamina: 10},
      effects: {SkillEffectType.multiplyMaxHp: 5.0},
    ),
    SkillModel(
      id: 'passive_focus_1',
      name: 'Ментальний Фокус I',
      description: 'Ваш розум стає гострішим. +5% до максимального MP.',
      skillType: SkillType.passive,
      levelRequirement: 5,
      statRequirements: {PlayerStat.intelligence: 10},
      effects: {SkillEffectType.multiplyMaxMp: 5.0},
    ),
    SkillModel(
      id: 'passive_swift_learner_1',
      name: 'Швидке Навчання I',
      description: 'Ви швидше засвоюєте досвід. +5% до отримуваного XP.',
      skillType: SkillType.passive,
      levelRequirement: 8,
      statRequirements: {PlayerStat.intelligence: 15},
      effects: {SkillEffectType.multiplyXpGain: 5.0},
    ),
    SkillModel(
      id: 'passive_brute_force_1',
      name: 'Груба Сила I',
      description: 'Базова сила зростає. +2 до характеристики Сила.',
      skillType: SkillType.passive,
      levelRequirement: 10,
      statRequirements: {PlayerStat.strength: 20},
      skillPointCost: 2,
      effects: {SkillEffectType.addStrength: 2.0},
    ),
    SkillModel(
      id: 'active_buff_might_1',
      name: 'Посилення I',
      description:
          'На короткий час ви наповнюєтесь силою. +5 до Сили на 10 хвилин.',
      skillType: SkillType.activeBuff,
      levelRequirement: 2,
      statRequirements: {PlayerStat.strength: 2, PlayerStat.intelligence: 2},
      skillPointCost: 1,
      mpCost: 15.0,
      duration: const Duration(minutes: 10),
      cooldown: const Duration(hours: 1),
      effects: {SkillEffectType.addStrength: 5.0},
    ),
  ];

  List<SkillModel> get allSkills => _allSkills;

  SkillModel? getSkillById(String id) {
    return _allSkills.firstWhereOrNull((skill) => skill.id == id);
  }

  bool canLearnSkill(
      PlayerModel player, String skillId, int availableSkillPoints) {
    final skill = getSkillById(skillId);
    if (skill == null) return false;

    if (availableSkillPoints < skill.skillPointCost) return false;

    if (player.level < skill.levelRequirement) return false;

    for (var requirement in skill.statRequirements.entries) {
      if ((player.stats[requirement.key] ?? 0) < requirement.value) {
        return false;
      }
    }
    return true;
  }
}
