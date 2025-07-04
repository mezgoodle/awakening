import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/skill_model.dart';
import '../models/player_model.dart';

class SkillProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      // Конвертуємо кожен документ в SkillModel
      _allSkills = snapshot.docs.map((doc) {
        final data = doc.data();

        // Потрібна конвертація для вкладених Map-ів
        final statReqs = (data['statRequirements'] as Map<String, dynamic>?)
            ?.map((key, value) =>
                MapEntry(PlayerStat.values.byName(key), value as int));

        final effects = (data['effects'] as Map<String, dynamic>?)?.map(
            (key, value) =>
                MapEntry(SkillEffectType.values.byName(key), value as double));

        // Конвертація тривалості та перезарядки з секунд
        final duration = data['durationSeconds'] != null
            ? Duration(seconds: data['durationSeconds'])
            : null;
        final cooldown = data['cooldownSeconds'] != null
            ? Duration(seconds: data['cooldownSeconds'])
            : null;

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
          mpCost: data['mpCost'] as double?,
          duration: duration,
          cooldown: cooldown,
        );
      }).toList();

      print("Loaded ${_allSkills.length} skills from Firestore.");
    } catch (e) {
      print("Error loading skills from Firestore: $e");
      _allSkills = []; // Якщо помилка, список буде порожнім
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
