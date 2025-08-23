import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/skill_provider.dart';

class ActiveBuffChip extends StatefulWidget {
  final String skillId;
  final String endTimeString;

  const ActiveBuffChip({
    super.key,
    required this.skillId,
    required this.endTimeString,
  });

  @override
  State<ActiveBuffChip> createState() => _ActiveBuffChipState();
}

class _ActiveBuffChipState extends State<ActiveBuffChip> {
  Timer? _timer;
  late Duration _remainingTime;

  @override
  void initState() {
    super.initState();
    _updateRemainingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final isTimeUp = _updateRemainingTime();
      setState(() {});

      if (isTimeUp) {
        timer.cancel();
      }
    });
  }

  bool _updateRemainingTime() {
    final endTime = DateTime.parse(widget.endTimeString);
    final remaining = endTime.difference(DateTime.now());
    _remainingTime = remaining.isNegative ? Duration.zero : remaining;
    return remaining.isNegative;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skill = context.read<SkillProvider>().getSkillById(widget.skillId);
    if (skill == null) {
      return const SizedBox.shrink();
    }

    final minutes = _remainingTime.inMinutes.toString();
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Chip(
      avatar: const Icon(Icons.arrow_upward_rounded,
          color: Colors.greenAccent, size: 18),
      label: Text(
        '${skill.name} ($minutes:$seconds)',
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white.withOpacity(0.15),
      shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
    );
  }
}
