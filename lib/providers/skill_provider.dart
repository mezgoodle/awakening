import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../models/skill_model.dart';
import '../models/player_model.dart';
import '../repositories/catalog_repository.dart';
import '../services/app_logger_service.dart';

class SkillProvider with ChangeNotifier {
  final CatalogRepository _catalogRepository;
  final AppLoggerService _logger = AppLoggerService();

  List<SkillModel> _allSkills = [];
  bool _isLoading = true;

  List<SkillModel> get allSkills => _allSkills;
  bool get isLoading => _isLoading;

  SkillProvider({CatalogRepository? catalogRepository})
      : _catalogRepository = catalogRepository ?? CatalogRepository() {
    loadAllSkills();
  }

  Future<void> loadAllSkills() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allSkills = await _catalogRepository.fetchSkills();
      _logger.writeLog(
        message: "Loaded ${_allSkills.length} skills from catalog.",
        severity: LogSeverity.info,
      );
    } catch (e, stack) {
      _logger.writeLog(
        message: "Error loading skills from catalog: $e",
        severity: LogSeverity.error,
        error: e,
        stackTrace: stack,
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

    for (final requirement in skill.statRequirements.entries) {
      if ((player.stats[requirement.key] ?? 0) < requirement.value) {
        return false;
      }
    }
    return true;
  }
}
