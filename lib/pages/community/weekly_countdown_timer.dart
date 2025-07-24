// lib/pages/community/weekly_countdown_timer.dart

import 'dart:async';
import 'package:flutter/material.dart';

class WeeklyCountdownTimer extends StatefulWidget {
  const WeeklyCountdownTimer({super.key});

  @override
  State<WeeklyCountdownTimer> createState() => _WeeklyCountdownTimerState();
}

class _WeeklyCountdownTimerState extends State<WeeklyCountdownTimer> {
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    // Inicia um timer que atualiza a UI a cada segundo
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _calculateTimeRemaining();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Calcula o tempo restante até a próxima meia-noite de Domingo.
  void _calculateTimeRemaining() {
    final now = DateTime.now();
    // O dia da semana vai de 1 (Segunda) a 7 (Domingo).
    // Queremos encontrar o próximo Domingo (dia 7).
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday <= 0) {
      // Se hoje é Domingo ou já passou, adiciona 7 dias para pegar o próximo.
      daysUntilSunday += 7;
    }

    // Calcula a data exata da próxima meia-noite de Domingo
    final nextSunday = DateTime(now.year, now.month, now.day + daysUntilSunday);

    setState(() {
      _timeRemaining = nextSunday.difference(now);
    });
  }

  /// Formata a duração em um formato legível: "DD : HH : MM : SS"
  String _formatDuration(Duration duration) {
    // Garante que a duração nunca seja negativa
    if (duration.isNegative) return "00 : 00 : 00 : 00";

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final days = twoDigits(duration.inDays);
    final hours = twoDigits(duration.inHours.remainder(24));
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return "$days : $hours : $minutes : $seconds";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countdownText = _formatDuration(_timeRemaining);
    final timeLabels = ['DIAS', 'HORAS', 'MINUTOS', 'SEGUNDOS'];
    final timeValues = countdownText.split(' : ');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.cardColor.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Column(
          children: [
            Text(
              "O ranking reinicia em:",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (index) {
                return Column(
                  children: [
                    Text(
                      timeValues[index],
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeLabels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7)),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
