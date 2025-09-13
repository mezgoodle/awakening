import 'package:awakening/services/cloud_logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/skill_model.dart';
import '../models/player_model.dart';
import 'package:collection/collection.dart';

class SkillProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final CloudLoggerService _logger = CloudLoggerService();

  List<SkillModel> _allSkills = [];
  bool _isLoading = true;

  List<SkillModel> get allSkills => _allSkills;
  bool get isLoading => _isLoading;

  SkillProvider() {
    _loadAllSkillsFromFirestore();
  }

  Future<void> _loadAllSkillsFromFirestore() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('skills').get();
      _allSkills = snapshot.docs.map((doc) {
        final data = doc.data();

        final statReqs = (data['statRequirements'] as Map<String, dynamic>?)
            ?.map((key, value) =>
                MapEntry(PlayerStat.values.byName(key), value as int));

        final effects = (data['effects'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
                SkillEffectType.values.byName(key), (value as num).toDouble()));

        final duration = data['durationSeconds'] != null
            ? Duration(seconds: (data['durationSeconds'] as num).toInt())
            : null;
        final cooldown = data['cooldownSeconds'] != null
            ? Duration(seconds: (data['cooldownSeconds'] as num).toInt())
            : null;
        final mpCost =
            data['mpCost'] != null ? (data['mpCost'] as num).toDouble() : null;

        return SkillModel(
          id: data['id'] as String,
          name: data['name'] as String,
          description: data['description'] as String,
          iconPath:
              data['iconPath'] as String? ?? 'assets/icons/skills/default.svg',
          skillType: SkillType.values.byName(data['skillType'] as String),
          levelRequirement: data['levelRequirement'] as int? ?? 1,
          skillPointCost: data['skillPointCost'] as int? ?? 1,
          statRequirements: statReqs ?? {},
          effects: effects ?? {},
          mpCost: mpCost,
          duration: duration,
          cooldown: cooldown,
        );
      }).toList();
      _logger.writeLog(
        message: "Loaded ${_allSkills.length} skills from Firestore.",
        severity: CloudLogSeverity.info,
      );
    } catch (e) {
      _logger.writeLog(
        message: "Error loading skills from Firestore",
        severity: CloudLogSeverity.error,
        payload: {
          'error': e.toString(),
        },
      );
      _allSkills = [];
    }

    _isLoading = false;
    notifyListeners();
  }

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
