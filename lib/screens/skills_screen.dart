import 'dart:async';
import 'package:awakening/providers/theme_provider.dart';
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
    final skillProvider = context.watch<SkillProvider>();
    final slog = context.read<SystemLogProvider>();

    if (playerProvider.isLoading || skillProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final player = playerProvider.player;
    final allSkills = skillProvider.allSkills;
    final themeProvider = Provider.of<ThemeProvider>(context);

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
        title: const Text('Skills'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Skill Points: ${player.availableSkillPoints}',
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
              'Learned Skills', learnedSkills, playerProvider, slog),
          _buildSkillSection(
              'Available to Learn', availableSkills, playerProvider, slog),
          _buildSkillSection(
              'Locked Skills', lockedSkills, playerProvider, slog),
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
        ...skills.map((skill) => SkillCard(skill: skill)).toList(),
      ],
    );
  }
}

class SkillCard extends StatefulWidget {
  final SkillModel skill;

  const SkillCard({
    super.key,
    required this.skill,
  });

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    if (_timer?.isActive ?? false) return;

    final playerProvider = context.read<PlayerProvider>();
    final player = playerProvider.player;
    if (player == null) return;

    final isBuffActive = player.activeBuffs.containsKey(widget.skill.id);
    final cooldownEndTime =
        playerProvider.getSkillCooldownEndTime(widget.skill.id);
    final isOnCooldown =
        cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now());

    if (isBuffActive || isOnCooldown) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentPlayer = context.read<PlayerProvider>().player;
        final currentBuffEndTimeString =
            currentPlayer.activeBuffs[widget.skill.id];
        final currentCooldownEndTime = context
            .read<PlayerProvider>()
            .getSkillCooldownEndTime(widget.skill.id);

        final bool buffIsStillActive = currentBuffEndTimeString != null &&
            DateTime.parse(currentBuffEndTimeString).isAfter(DateTime.now());
        final bool cooldownIsStillActive = currentCooldownEndTime != null &&
            currentCooldownEndTime.isAfter(DateTime.now());

        if (!buffIsStillActive && !cooldownIsStillActive) {
          timer.cancel();
          _timer = null;
        }

        if (mounted) {
          setState(() {});
        } else {
          timer.cancel();
          _timer = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final slog = context.read<SystemLogProvider>();
    final skillProvider = context.read<SkillProvider>();

    final player = playerProvider.player;

    final isLearned = player.learnedSkillIds.contains(widget.skill.id);
    final canLearn = !isLearned &&
        skillProvider.canLearnSkill(
            player, widget.skill.id, player.availableSkillPoints);
    final isLocked = !isLearned && !canLearn;

    final cooldownEndTime =
        playerProvider.getSkillCooldownEndTime(widget.skill.id);
    final isOnCooldown =
        cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now());

    final buffEndTimeString = player.activeBuffs[widget.skill.id];
    final isBuffActive = buffEndTimeString != null &&
        DateTime.parse(buffEndTimeString).isAfter(DateTime.now());

    _startTimerIfNeeded();

    Color borderColor = isLearned
        ? Colors.amberAccent
        : (canLearn ? Colors.greenAccent : Colors.grey[700]!);

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
                  Expanded(
                    child: Text(widget.skill.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (isLearned &&
                      widget.skill.skillType == SkillType.activeBuff &&
                      !isBuffActive &&
                      !isOnCooldown)
                    ElevatedButton(
                      onPressed: () {
                        playerProvider.activateSkill(widget.skill.id, slog);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700]),
                      child:
                          Text('Activate (${widget.skill.mpCost?.toInt()} MP)'),
                    ),
                  if (canLearn)
                    ElevatedButton(
                      onPressed: () {
                        playerProvider.learnSkill(widget.skill.id, slog);
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700]),
                      child: Text('Learn (${widget.skill.skillPointCost})'),
                    ),
                  if (isLearned &&
                      (widget.skill.skillType == SkillType.passive ||
                          isBuffActive))
                    const Icon(Icons.check_circle, color: Colors.amberAccent),
                  if (isOnCooldown && !isBuffActive)
                    const Icon(Icons.hourglass_bottom_rounded,
                        color: Colors.redAccent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.skill.description,
              ),
              const SizedBox(height: 10),
              if (isBuffActive)
                _buildTimerText('Active:', DateTime.parse(buffEndTimeString),
                    Colors.greenAccent[400]!),
              if (isOnCooldown && !isBuffActive)
                _buildTimerText(
                    'Cooldown:', cooldownEndTime, Colors.redAccent[100]!),
              if (isLocked) _buildRequirements(context, widget.skill, player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerText(String prefix, DateTime endTime, Color color) {
    final remaining = endTime.difference(DateTime.now());
    final durationToShow = remaining.isNegative ? Duration.zero : remaining;
    final minutes = durationToShow.inMinutes.toString();
    final seconds = (durationToShow.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        '$prefix $minutes:$seconds',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRequirements(
      BuildContext context, SkillModel skill, PlayerModel player) {
    final List<Widget> reqWidgets = [];
    final bool levelMet = player.level >= skill.levelRequirement;
    if (skill.levelRequirement > 1) {
      reqWidgets.add(Text(
          '• Level: ${skill.levelRequirement} (you have ${player.level})',
          style: TextStyle(
              color: levelMet ? Colors.greenAccent : Colors.redAccent)));
    }
    skill.statRequirements.forEach((stat, value) {
      final bool statMet = (player.stats[stat] ?? 0) >= value;
      reqWidgets.add(Text(
          '• ${PlayerModel.getStatName(stat)}: $value (you have ${player.stats[stat] ?? 0})',
          style: TextStyle(
              color: statMet ? Colors.greenAccent : Colors.redAccent)));
    });
    if (skill.skillPointCost > 0) {
      final bool spMet = player.availableSkillPoints >= skill.skillPointCost;
      reqWidgets.add(Text(
          '• Skill points: ${skill.skillPointCost} (you have ${player.availableSkillPoints})',
          style:
              TextStyle(color: spMet ? Colors.greenAccent : Colors.redAccent)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Requirements:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          )),
      ...reqWidgets
    ]);
  }
}
