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

  const SkillModel({
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

  factory SkillModel.fromFirestore(Map<String, dynamic> data) {
    final statReqs = (data['statRequirements'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(PlayerStat.values.byName(key), value as int),
    );

    final effects = (data['effects'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(
        SkillEffectType.values.byName(key),
        (value as num).toDouble(),
      ),
    );

    final duration = data['durationSeconds'] != null
        ? Duration(seconds: (data['durationSeconds'] as num).toInt())
        : null;
    final cooldown = data['cooldownSeconds'] != null
        ? Duration(seconds: (data['cooldownSeconds'] as num).toInt())
        : null;
    final mpCost =
        data['mpCost'] != null ? (data['mpCost'] as num).toDouble() : null;

    SkillType skillType = SkillType.passive;
    if (data['skillType'] != null) {
      try {
        skillType = SkillType.values.byName(data['skillType'] as String);
      } catch (_) {}
    }

    return SkillModel(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Unknown Skill',
      description: data['description'] as String? ?? '',
      iconPath: data['iconPath'] as String? ?? 'assets/icons/skills/default.svg',
      skillType: skillType,
      levelRequirement: data['levelRequirement'] as int? ?? 1,
      skillPointCost: data['skillPointCost'] as int? ?? 1,
      statRequirements: statReqs ?? {},
      effects: effects ?? {},
      mpCost: mpCost,
      duration: duration,
      cooldown: cooldown,
    );
  }
}
