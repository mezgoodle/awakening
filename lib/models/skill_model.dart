import 'player_model.dart';

enum SkillType {
  passive,
  activeBuff,
  activeAction,
}

enum SkillEffectType {
  addStrength,
  addAgility,
  addIntelligence,
  addPerception,
  addStamina,

  multiplyMaxHp,
  multiplyMaxMp,
  multiplyXpGain,

  reduceMpCost,
  reduceCooldown,
}

class SkillModel {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final SkillType skillType;

  final int levelRequirement;
  final Map<PlayerStat, int> statRequirements;

  final int skillPointCost;

  final Map<SkillEffectType, double> effects;

  final double? mpCost;
  final Duration? duration;
  final Duration? cooldown;

  SkillModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconPath = 'assets/icons/skills/default.svg',
    required this.skillType,
    this.levelRequirement = 1,
    this.statRequirements = const {},
    this.skillPointCost = 1,
    this.effects = const {},
    this.mpCost,
    this.duration,
    this.cooldown,
  });
}
