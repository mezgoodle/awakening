// lib/screens/player_status_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/player_model.dart'; // Для доступу до PlayerStat та getStatName

class PlayerStatusScreen extends StatelessWidget {
  const PlayerStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Отримуємо доступ до PlayerProvider
    // 'watch' означає, що віджет буде перебудовуватись при змінах в PlayerProvider
    final playerProvider = context.watch<PlayerProvider>();
    final player = playerProvider.player;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статус Гравця'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          // ListView, якщо контенту буде більше ніж екран
          children: <Widget>[
            _buildInfoCard(
                'Ім\'я Гравця:', 'Джин Ву (Тимчасово)'), // Поки що хардкод
            const SizedBox(height: 16),
            _buildInfoCard('Рівень:', '${player.level}'),
            const SizedBox(height: 8),
            Text(
              'Досвід: ${player.xp} / ${player.xpToNextLevel}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: player.xp / player.xpToNextLevel,
              backgroundColor: Colors.grey[700],
              // valueColor анімацію не потрібно, бо ThemeData вже налаштувала колір
            ),
            const SizedBox(height: 24),
            Text(
              'Характеристики:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...player.stats.entries.map((entry) {
              // ... - spread оператор для списку віджетів
              return _buildStatRow(
                  PlayerModel.getStatName(
                      entry.key), // Використовуємо наш метод
                  entry.value,
                  context);
            }).toList(),
            const SizedBox(height: 24),
            _buildInfoCard('Доступні очки:', '${player.availableStatPoints}'),

            // Тимчасова кнопка для тестування додавання XP
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                // Викликаємо метод з провайдера
                playerProvider.addXp(15); // Додаємо 15 XP для тесту
              },
              child: const Text('Додати 15 XP (Тест)'),
            ),
            // Тут можна буде додати кнопки для переходу до списку завдань тощо.
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      color: const Color(0xFF2A2A2A), // Трохи світліший фон для карток
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.white70)),
            Text(value,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String statName, int statValue, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('$statName:',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 16)),
          Text('$statValue',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
