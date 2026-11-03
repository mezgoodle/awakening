import 'package:flutter/material.dart';
import '../models/quest_model.dart';

extension QuestDifficultyExtension on QuestDifficulty {
  String get rankName => '$name-Rank';

  Color get color {
    switch (this) {
      case QuestDifficulty.S:
        return Colors.redAccent[700]!;
      case QuestDifficulty.A:
        return Colors.orangeAccent[700]!;
      case QuestDifficulty.B:
        return Colors.amber[700]!;
      case QuestDifficulty.C:
        return Colors.lightGreenAccent[700]!;
      case QuestDifficulty.D:
        return Colors.lightBlueAccent[400]!;
      case QuestDifficulty.E:
        return Colors.grey[500]!;
      case QuestDifficulty.F:
        return Colors.grey[700]!;
    }
  }
}

extension QuestTypeExtension on QuestType {
  String get displayName {
    switch (this) {
      case QuestType.daily:
        return 'Daily';
      case QuestType.weekly:
        return 'Weekly';
      case QuestType.milestone:
        return 'Milestone';
      case QuestType.generated:
        return 'Generated';
      case QuestType.story:
        return 'Story';
      case QuestType.rankUpChallenge:
        return 'Rank Up Challenge';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestType.daily:
        return Icons.wb_sunny_outlined;
      case QuestType.weekly:
        return Icons.calendar_view_week_outlined;
      case QuestType.milestone:
        return Icons.flag_outlined;
      case QuestType.generated:
        return Icons.auto_awesome_outlined;
      case QuestType.story:
        return Icons.menu_book_outlined;
      case QuestType.rankUpChallenge:
        return Icons.workspace_premium_outlined;
    }
  }
}
