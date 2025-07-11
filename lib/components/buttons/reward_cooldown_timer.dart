import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/middleware/ad_middleware.dart';
import 'package:septima_biblia/redux/store.dart';

// ViewModel para obter os dados de cooldown do Redux
class _CooldownViewModel {
  final DateTime? lastAdTime;
  final DateTime? firstAdInWindow;
  final int adsToday;
  final int adsInWindow;
  final int userCoins;

  _CooldownViewModel({
    this.lastAdTime,
    this.firstAdInWindow,
    required this.adsToday,
    required this.adsInWindow,
    required this.userCoins,
  });

  static _CooldownViewModel fromStore(Store<AppState> store) {
    return _CooldownViewModel(
      lastAdTime: store.state.userState.lastRewardedAdWatchTime,
      firstAdInWindow: store.state.userState.firstAdIn6HourWindowTimestamp,
      adsToday: store.state.userState.rewardedAdsWatchedToday,
      adsInWindow: store.state.userState.adsWatchedIn6HourWindow,
      userCoins: store.state.userState.userCoins,
    );
  }

  // Otimização para reconstruir o widget apenas quando os dados relevantes mudam
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CooldownViewModel &&
          runtimeType == other.runtimeType &&
          lastAdTime == other.lastAdTime &&
          firstAdInWindow == other.firstAdInWindow &&
          adsToday == other.adsToday &&
          adsInWindow == other.adsInWindow &&
          userCoins == other.userCoins;

  @override
  int get hashCode =>
      lastAdTime.hashCode ^
      firstAdInWindow.hashCode ^
      adsToday.hashCode ^
      adsInWindow.hashCode ^
      userCoins.hashCode;
}

// O Widget Stateful que gerencia o temporizador
class RewardCooldownTimer extends StatefulWidget {
  const RewardCooldownTimer({super.key});

  @override
  State<RewardCooldownTimer> createState() => _RewardCooldownTimerState();
}

class _RewardCooldownTimerState extends State<RewardCooldownTimer> {
  Timer? _timer;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // Força uma reconstrução a cada segundo se houver tempo restante
        // A lógica de cálculo real estará no método build
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Função para calcular o tempo restante e a razão do bloqueio
  Map<String, dynamic> _calculateCooldownState(_CooldownViewModel vm) {
    final now = DateTime.now();

    // 1. Limite diário atingido
    if (vm.lastAdTime != null &&
        now.day == vm.lastAdTime!.day &&
        vm.adsToday >= MAX_ADS_PER_DAY) {
      // Calcula o tempo até a meia-noite
      final nextDay = DateTime(now.year, now.month, now.day + 1);
      return {'isBlocked': true, 'timeRemaining': nextDay.difference(now)};
    }

    // 2. Cooldown de 60 segundos
    if (vm.lastAdTime != null &&
        now.difference(vm.lastAdTime!) < ADS_COOLDOWN_DURATION) {
      return {
        'isBlocked': true,
        'timeRemaining': ADS_COOLDOWN_DURATION - now.difference(vm.lastAdTime!)
      };
    }

    // 3. Limite da janela de 6 horas
    if (vm.firstAdInWindow != null &&
        now.difference(vm.firstAdInWindow!) <= SIX_HOUR_WINDOW_DURATION) {
      if (vm.adsInWindow >= MAX_ADS_PER_SIX_HOUR_WINDOW) {
        final windowEndTime = vm.firstAdInWindow!.add(SIX_HOUR_WINDOW_DURATION);
        return {
          'isBlocked': true,
          'timeRemaining': windowEndTime.difference(now)
        };
      }
    }

    // 4. Sem bloqueio
    return {'isBlocked': false, 'timeRemaining': Duration.zero};
  }

  // Função para formatar a duração de forma compacta
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes.remainder(60)}m";
    }
    if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s";
    }
    // Adiciona +1 para não mostrar "0s"
    return "${duration.inSeconds + 1}s";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StoreConnector<AppState, _CooldownViewModel>(
      converter: (store) => _CooldownViewModel.fromStore(store),
      distinct: true,
      builder: (context, vm) {
        // Se já atingiu o limite de moedas, não mostra nada
        if (vm.userCoins >= MAX_COINS_LIMIT) {
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Icon(Icons.check_circle,
                color: theme.colorScheme.primary.withOpacity(0.7), size: 22),
          );
        }

        final cooldownState = _calculateCooldownState(vm);
        final bool isBlocked = cooldownState['isBlocked'];
        final Duration timeRemaining = cooldownState['timeRemaining'];

        // Se estiver bloqueado e o tempo restante for positivo
        if (isBlocked && timeRemaining.inSeconds > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              _formatDuration(timeRemaining),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          );
        }

        // Se não estiver bloqueado, mostra o botão de adicionar
        return IconButton(
          icon: Icon(Icons.add_circle_outline,
              color: theme.colorScheme.primary, size: 24),
          tooltip: 'Ganhar Moedas',
          onPressed: () => StoreProvider.of<AppState>(context, listen: false)
              .dispatch(RequestRewardedAdAction()),
        );
      },
    );
  }
}
