// lib/screens/initial_survey_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../providers/player_provider.dart';
import 'home_screen.dart'; // Для навігації після завершення

class InitialSurveyScreen extends StatefulWidget {
  const InitialSurveyScreen({super.key});

  @override
  State<InitialSurveyScreen> createState() => _InitialSurveyScreenState();
}

class _InitialSurveyScreenState extends State<InitialSurveyScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _pullUpsController = TextEditingController();
  final TextEditingController _pushUpsController = TextEditingController();
  final TextEditingController _runningController = TextEditingController();
  bool? _regularExercise;
  bool _attemptedSubmit = false; // Прапорець для відстеження спроби відправки

  int? _parseNullableInt(String value) {
    if (value.isEmpty) return 0; // Якщо порожньо, вважаємо 0 для числових полів
    return int.tryParse(value);
  }

  @override
  void dispose() {
    _pullUpsController.dispose();
    _pushUpsController.dispose();
    _runningController.dispose();
    super.dispose();
  }

  void _submitSurvey() {
    setState(() {
      _attemptedSubmit = true; // Позначаємо, що була спроба відправки
    });

    // Спочатку валідуємо форму для TextFormField
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Будь ласка, заповніть всі числові поля коректно.')),
      );
      return; // Не продовжуємо, якщо форма не валідна
    }

    // Потім перевіряємо RadioListTile
    if (_regularExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Будь ласка, дайте відповідь на питання про регулярні заняття спортом.')),
      );
      return; // Не продовжуємо, якщо радіо не обрано
    }

    // Якщо все добре, зберігаємо дані
    final performance = <PhysicalActivity, dynamic>{};

    // Використовуємо _parseNullableInt, який тепер повертає 0 для порожніх значень
    performance[PhysicalActivity.pullUps] =
        _parseNullableInt(_pullUpsController.text) ?? 0;
    performance[PhysicalActivity.pushUps] =
        _parseNullableInt(_pushUpsController.text) ?? 0;
    performance[PhysicalActivity.runningDurationInMin] =
        _parseNullableInt(_runningController.text) ?? 0;
    performance[PhysicalActivity.regularExercise] =
        _regularExercise!; // Тепер ми знаємо, що він не null

    // Розрахунок бонусів до початкових характеристик
    Map<PlayerStat, int> statBonuses = {};

    if (_regularExercise == true) {
      statBonuses[PlayerStat.stamina] =
          (statBonuses[PlayerStat.stamina] ?? 0) + 1;
      statBonuses[PlayerStat.strength] =
          (statBonuses[PlayerStat.strength] ?? 0) + 1;
    }

    int pullUps = performance[PhysicalActivity.pullUps] as int;
    int pushUps = performance[PhysicalActivity.pushUps] as int;

    if (pullUps >= 3) {
      // Якщо може підтягнутися хоча б 3 рази
      statBonuses[PlayerStat.strength] =
          (statBonuses[PlayerStat.strength] ?? 0) + 1;
    }
    if (pushUps >= 10) {
      // Якщо може віджатися 10+ разів
      statBonuses[PlayerStat.strength] =
          (statBonuses[PlayerStat.strength] ?? 0) + 1;
      statBonuses[PlayerStat.stamina] =
          (statBonuses[PlayerStat.stamina] ?? 0) + 1;
    }
    // Максимальний бонус для кожної характеристики, наприклад, +2
    statBonuses.updateAll((key, value) => value.clamp(0, 2));

    final playerProvider = context.read<PlayerProvider>();
    playerProvider.updateBaselinePerformance(performance);
    // Застосовуємо бонуси до характеристик
    playerProvider.applyInitialStatBonuses(statBonuses);
    playerProvider.setInitialSurveyCompleted(true);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Початкова Оцінка'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Ласкаво просимо, Мисливцю!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.lightBlueAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Щоб краще адаптувати ваші перші випробування, будь ласка, дайте відповідь на кілька запитань про вашу поточну фізичну форму.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _pullUpsController,
                  decoration: const InputDecoration(
                    labelText: 'Максимум підтягувань (0, якщо не можете)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.fitness_center),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Будь ласка, введіть число (можна 0)';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Введіть коректне невід\'ємне число';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _pushUpsController,
                  decoration: const InputDecoration(
                    labelText: 'Максимум віджимань від підлоги',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.accessibility_new),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Будь ласка, введіть число (можна 0)';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Введіть коректне невід\'ємне число';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _runningController,
                  decoration: const InputDecoration(
                    labelText: 'Скільки хвилин можете бігти без зупинки?',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_run),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Будь ласка, введіть число (можна 0)';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Введіть коректне невід\'ємне число';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                    'Чи займаєтесь ви регулярно спортом (принаймні 2-3 рази на тиждень)?',
                    style: Theme.of(context).textTheme.titleMedium),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Так'),
                        value: true,
                        groupValue: _regularExercise,
                        onChanged: (bool? value) {
                          setState(() {
                            _regularExercise = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Ні'),
                        value: false,
                        groupValue: _regularExercise,
                        onChanged: (bool? value) {
                          setState(() {
                            _regularExercise = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Показуємо повідомлення про помилку для RadioListTile, якщо була спроба відправки і нічого не обрано
                if (_attemptedSubmit && _regularExercise == null)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 0.0, bottom: 10.0), // Зменшив верхній відступ
                    child: Text(
                      'Будь ласка, оберіть варіант',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 20), // Зменшив відступ перед кнопкою
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward_ios),
                  label: const Text('Почати Пробудження'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  onPressed:
                      _submitSurvey, // Тепер просто викликаємо _submitSurvey
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
