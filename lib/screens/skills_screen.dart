// lib/screens/skills_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/skill_provider.dart';
import '../providers/system_log_provider.dart';
import '../models/skill_model.dart';
import '../models/player_model.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final skillProvider = context.read<SkillProvider>();
    final slog = context.read<SystemLogProvider>();

    if (playerProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final player = playerProvider.player;
    final allSkills = skillProvider.allSkills;

    final learnedSkills =
        allSkills.where((s) => player.learnedSkillIds.contains(s.id)).toList();
    final availableSkills = allSkills
        .where((s) =>
            !player.learnedSkillIds.contains(s.id) &&
            skillProvider.canLearnSkill(
                player, s.id, player.availableSkillPoints))
        .toList();
    final lockedSkills = allSkills
        .where((s) =>
            !player.learnedSkillIds.contains(s.id) &&
            !availableSkills.contains(s))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Навички'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Очки Навичок: ${player.availableSkillPoints}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12.0),
        children: [
          _buildSkillSection(
              'Вивчені Навички', learnedSkills, playerProvider, slog),
          _buildSkillSection(
              'Доступні для Вивчення', availableSkills, playerProvider, slog),
          _buildSkillSection(
              'Заблоковані Навички', lockedSkills, playerProvider, slog),
        ],
      ),
    );
  }

  Widget _buildSkillSection(String title, List<SkillModel> skills,
      PlayerProvider playerProvider, SystemLogProvider slog) {
    if (skills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlueAccent),
          ),
        ),
        ...skills
            .map((skill) => SkillCard(
                skill: skill, playerProvider: playerProvider, slog: slog))
            .toList(),
      ],
    );
  }
}

class SkillCard extends StatelessWidget {
  final SkillModel skill;
  final PlayerProvider playerProvider;
  final SystemLogProvider slog;

  const SkillCard({
    super.key,
    required this.skill,
    required this.playerProvider,
    required this.slog,
  });

  @override
  Widget build(BuildContext context) {
    final player = playerProvider.player;
    final bool isLearned = player.learnedSkillIds.contains(skill.id);
    final bool canLearn = !isLearned &&
        context
            .read<SkillProvider>()
            .canLearnSkill(player, skill.id, player.availableSkillPoints);
    final bool isLocked = !isLearned && !canLearn;

    Color borderColor = isLearned
        ? Colors.amberAccent
        : (canLearn ? Colors.greenAccent : Colors.grey[700]!);

    final cooldownEndTime = playerProvider.getSkillCooldownEndTime(skill.id);
    final bool isOnCooldown =
        cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now());
    final bool isBuffActive = player.activeBuffs.containsKey(skill.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Opacity(
        opacity: isLocked ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, color: borderColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(skill.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (isLearned &&
                      skill.skillType == SkillType.activeBuff &&
                      !isBuffActive &&
                      !isOnCooldown)
                    ElevatedButton(
                      onPressed: () {
                        playerProvider.activateSkill(skill.id, slog);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700]),
                      child: Text('Активувати (${skill.mpCost?.toInt()} MP)'),
                    ),
                  if (canLearn)
                    ElevatedButton(
                      onPressed: () {
                        playerProvider.learnSkill(skill.id, slog);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700]),
                      child: Text('Вивчити (${skill.skillPointCost})'),
                    ),
                  if (isLearned &&
                      (skill.skillType == SkillType.passive || isBuffActive))
                    const Icon(Icons.check_circle, color: Colors.amberAccent),
                ],
              ),
              const SizedBox(height: 8),
              Text(skill.description,
                  style: TextStyle(color: Colors.grey[300])),
              if (isLearned &&
                  skill.skillType == SkillType.activeBuff &&
                  isOnCooldown)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Перезарядка: ${cooldownEndTime.difference(DateTime.now()).inMinutes} хв. ${cooldownEndTime.difference(DateTime.now()).inSeconds % 60} сек.',
                    style: TextStyle(color: Colors.redAccent[100]),
                  ),
                ),
              const SizedBox(height: 10),
              if (isLocked) _buildRequirements(context, skill, player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirements(
      BuildContext context, SkillModel skill, PlayerModel player) {
    final List<Widget> reqWidgets = [];
    final bool levelMet = player.level >= skill.levelRequirement;
    if (skill.levelRequirement > 1) {
      reqWidgets.add(Text(
        '• Рівень: ${skill.levelRequirement} (у вас ${player.level})',
        style:
            TextStyle(color: levelMet ? Colors.greenAccent : Colors.redAccent),
      ));
    }

    skill.statRequirements.forEach((stat, value) {
      final bool statMet = (player.stats[stat] ?? 0) >= value;
      reqWidgets.add(Text(
        '• ${PlayerModel.getStatName(stat)}: $value (у вас ${player.stats[stat] ?? 0})',
        style:
            TextStyle(color: statMet ? Colors.greenAccent : Colors.redAccent),
      ));
    });

    if (skill.skillPointCost > 0) {
      final bool spMet = player.availableSkillPoints >= skill.skillPointCost;
      reqWidgets.add(Text(
        '• Очки навичок: ${skill.skillPointCost} (у вас ${player.availableSkillPoints})',
        style: TextStyle(color: spMet ? Colors.greenAccent : Colors.redAccent),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Вимоги:',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ...reqWidgets,
      ],
    );
  }
}
