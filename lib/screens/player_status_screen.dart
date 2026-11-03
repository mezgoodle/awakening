import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../models/quest_model.dart';
import '../providers/player_provider.dart';
import '../providers/quest_provider.dart';
import '../providers/system_log_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/rank_extensions.dart';
import '../widgets/active_buff_chip.dart';
import 'system_log_screen.dart';

class PlayerStatusScreen extends StatefulWidget {
  const PlayerStatusScreen({super.key});

  @override
  State<PlayerStatusScreen> createState() => _PlayerStatusScreenState();
}

class _PlayerStatusScreenState extends State<PlayerStatusScreen> {
  void _showLevelUpSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'LEVEL UP! You have gained power.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showEditNameDialog(
      BuildContext context, PlayerProvider playerProvider) async {
    final TextEditingController nameController =
        TextEditingController(text: playerProvider.player.playerName);
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Change Hunter Name'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: "Enter hunter name"),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name cannot be empty';
                  }
                  if (value.trim().length > 20) {
                    return 'Name is too long (max 20 characters)';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  playerProvider.setPlayerName(nameController.text.trim());
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hunter name updated!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildResourceBar(String label, int currentValue, int maxValue,
      Color barColor, IconData icon) {
    final double percentage =
        maxValue > 0 ? (currentValue / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: barColor, size: 18),
            const SizedBox(width: 8),
            Text(
              '$label: $currentValue / $maxValue',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: FractionallySizedBox(
            widthFactor: percentage,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final questProvider = context.read<QuestProvider>();
    final systemLogProvider = context.read<SystemLogProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (playerProvider.consumeLevelUpEvent() && mounted) {
        _showLevelUpSnackBar(context);
      }
    });

    if (playerProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player Status')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final player = playerProvider.player;
    final finalStats = playerProvider.finalStats;
    final finalMaxHp = playerProvider.finalMaxHp;
    final finalMaxMp = playerProvider.finalMaxMp;

    final QuestDifficulty nextPotentialRank =
        PlayerModel.calculateRankByLevel(player.level);
    final bool canChallengeNextRank =
        nextPotentialRank.index > player.playerRank.index &&
            !questProvider.activeQuests
                .any((q) => q.type == QuestType.rankUpChallenge);

    final themeProvider = Provider.of<ThemeProvider>(context);
    final rankColor = player.playerRank.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hunter Status'),
        actions: [
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            tooltip: 'Toggle Theme',
            onPressed: () => themeProvider.toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'System Log',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SystemLogScreen(),
                ),
              );
            },
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Progress (Debug)',
              onPressed: () async {
                final bool? confirmReset = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext ctx) {
                    return AlertDialog(
                      title: const Text('Reset Player Progress?'),
                      content: const Text(
                        'Are you sure you want to reset hunter progress? This action cannot be undone.',
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Reset'),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ],
                    );
                  },
                );
                if (confirmReset == true) {
                  await playerProvider.resetPlayerData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Player progress reset.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: <Widget>[
            _buildInfoCard(
              'Hunter Name:',
              player.playerName,
              actionWidget: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit Name',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditNameDialog(context, playerProvider),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      "Hunter Rank:",
                      style: TextStyle(fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: rankColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: rankColor, width: 1.5),
                      ),
                      child: Text(
                        player.playerRank.rankName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: rankColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildInfoCard('Level:', '${player.level}'),
            const SizedBox(height: 12),
            _buildActiveBuffsSection(player),
            const SizedBox(height: 12),
            _buildResourceBar(
              "HP",
              player.currentHp,
              finalMaxHp,
              Colors.redAccent[400]!,
              Icons.favorite_rounded,
            ),
            const SizedBox(height: 12),
            _buildResourceBar(
              "MP",
              player.currentMp,
              finalMaxMp,
              Colors.blueAccent[400]!,
              Icons.flash_on_rounded,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'XP: ${player.xp} / ${player.xpToNextLevel}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (playerProvider.xpMultiplier > 1.0)
                  Text(
                    '(${playerProvider.xpMultiplier.toStringAsFixed(1)}x XP)',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (player.xpToNextLevel > 0)
                  ? (player.xp / player.xpToNextLevel).clamp(0.0, 1.0)
                  : 0.0,
              backgroundColor: Colors.grey[800],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stats:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (player.availableStatPoints > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Points available: ${player.availableStatPoints}',
                      style: TextStyle(
                        color: Colors.lightBlueAccent[100],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...finalStats.entries.map((entry) {
              final baseValue = player.stats[entry.key] ?? 0;
              final finalValue = entry.value;
              final bonus = finalValue - baseValue;
              final slog = context.read<SystemLogProvider>();
              return _buildStatRow(
                PlayerModel.getStatName(entry.key),
                entry.value,
                context,
                bonus: bonus,
                canIncrease: player.availableStatPoints > 0,
                onIncrease: () {
                  playerProvider.spendStatPoint(entry.key, 1, slog);
                },
              );
            }),
            const SizedBox(height: 24),
            if (canChallengeNextRank)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: Text(
                    'Challenge for ${QuestDifficulty.values[player.playerRank.index + 1].rankName}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: questProvider.isGeneratingQuest
                      ? null
                      : () async {
                          await playerProvider.requestRankUpChallenge(
                            questProvider,
                            systemLogProvider,
                          );
                        },
                ),
              ),
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent),
                  ),
                  onPressed: () {
                    final slog = context.read<SystemLogProvider>();
                    playerProvider.addXp(250, slog);
                  },
                  child: const Text('Add 250 XP (Debug)'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBuffsSection(PlayerModel player) {
    if (player.activeBuffs.isEmpty) return const SizedBox.shrink();

    final List<Widget> buffWidgets = player.activeBuffs.entries.map((entry) {
      return ActiveBuffChip(
        key: ValueKey(entry.key),
        skillId: entry.key,
        endTimeString: entry.value,
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Buffs:',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: buffWidgets,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, {Widget? actionWidget}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: const TextStyle(fontSize: 16)),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actionWidget != null) ...[
                  const SizedBox(width: 8),
                  actionWidget,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
    String statName,
    int statValue,
    BuildContext context, {
    int bonus = 0,
    bool canIncrease = false,
    VoidCallback? onIncrease,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            '$statName:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 16),
          ),
          Row(
            children: [
              Text(
                '$statValue',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (bonus > 0)
                Text(
                  ' (+$bonus)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent[400],
                      ),
                ),
              if (canIncrease && onIncrease != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: IconButton(
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: Colors.lightBlueAccent[100],
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Increase $statName',
                    onPressed: onIncrease,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
