// lib/redux/middleware/ad_middleware.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NOVO

const int COINS_PER_REWARDED_AD = 10;
const int MAX_COINS_LIMIT = 100;
const int MAX_ADS_PER_DAY = 12;
const Duration ADS_COOLDOWN_DURATION = Duration(seconds: 10);
const Duration SIX_HOUR_WINDOW_DURATION = Duration(hours: 6); // NOVO
const int MAX_ADS_PER_SIX_HOUR_WINDOW = 3; // NOVO

// Chaves para SharedPreferences
const String _prefsFirstAdIn6HourWindowKey =
    'firstAdIn6HourWindowTimestamp'; //NOVO
const String _prefsAdsWatchedIn6HourWindowKey =
    'adsWatchedIn6HourWindow'; //NOVO

List<Middleware<AppState>> createAdMiddleware() {
  final adHelper = AdHelper();
  final firestoreService = FirestoreService();

  adHelper.loadRewardedAd(onUserEarnedReward: (RewardItem reward) {
    print(
        "AdHelper (init load): Recompensa inicial. ${reward.amount} ${reward.type}");
  });

  return [
    TypedMiddleware<AppState, RequestRewardedAdAction>(
            _handleRequestRewardedAd(adHelper, firestoreService))
        .call,
    TypedMiddleware<AppState, LoadAdLimitDataAction>(_handleLoadAdLimitData)
        .call, // NOVO
  ];
}

// NOVO: Handler para carregar dados do SharedPreferences
void Function(Store<AppState>, LoadAdLimitDataAction, NextDispatcher)
    _handleLoadAdLimitData = (Store<AppState> store,
        LoadAdLimitDataAction action, NextDispatcher next) async {
  next(action);
  try {
    final prefs = await SharedPreferences.getInstance();
    final String? timestampString =
        prefs.getString(_prefsFirstAdIn6HourWindowKey);
    final DateTime? firstAdTimestamp =
        timestampString != null ? DateTime.tryParse(timestampString) : null;
    final int adsInWindowCount =
        prefs.getInt(_prefsAdsWatchedIn6HourWindowKey) ?? 0;

    store.dispatch(AdLimitDataLoadedAction(
      firstAdTimestamp: firstAdTimestamp,
      adsInWindowCount: adsInWindowCount,
    ));
    print(
        "AdMiddleware: Dados de limite de anúncio (6h) carregados do SharedPreferences: Timestamp: $firstAdTimestamp, Contagem: $adsInWindowCount");
  } catch (e) {
    print(
        "AdMiddleware: Erro ao carregar dados de limite de anúncio do SharedPreferences: $e");
    // Despacha com valores padrão em caso de erro para garantir que o estado não fique inconsistente
    store.dispatch(
        AdLimitDataLoadedAction(firstAdTimestamp: null, adsInWindowCount: 0));
  }
};

// Função para salvar os stats da janela de 6h no SharedPreferences
Future<void> _saveAdWindowStatsToPrefs(DateTime? timestamp, int count) async {
  //NOVO
  try {
    final prefs = await SharedPreferences.getInstance();
    if (timestamp != null) {
      await prefs.setString(
          _prefsFirstAdIn6HourWindowKey, timestamp.toIso8601String());
    } else {
      await prefs.remove(_prefsFirstAdIn6HourWindowKey);
    }
    await prefs.setInt(_prefsAdsWatchedIn6HourWindowKey, count);
    print(
        "AdMiddleware: Stats da janela de 6h salvos no SharedPreferences. Timestamp: $timestamp, Count: $count");
  } catch (e) {
    print(
        "AdMiddleware: Erro ao salvar stats da janela de 6h no SharedPreferences: $e");
  }
}

void Function(Store<AppState>, RequestRewardedAdAction, NextDispatcher)
    _handleRequestRewardedAd(
        AdHelper adHelper, FirestoreService firestoreService) {
  return (Store<AppState> store, RequestRewardedAdAction action,
      NextDispatcher next) async {
    next(action);

    final BuildContext? currentContext = navigatorKey.currentContext;
    final userState = store.state.userState; // Mais fácil de acessar
    final userId = userState.userId;
    final userCoins = userState.userCoins;
    final lastAdTime = userState.lastRewardedAdWatchTime;
    final adsToday = userState.rewardedAdsWatchedToday;

    // NOVOS DADOS DO ESTADO
    final firstAdIn6HourWindow = userState.firstAdIn6HourWindowTimestamp;
    final adsWatchedIn6HourWindow = userState.adsWatchedIn6HourWindow;

    if (userId == null) {
      print("AdMiddleware: Usuário não logado.");
      return;
    }

    if (userCoins >= MAX_COINS_LIMIT) {
      print("AdMiddleware: Limite máximo de moedas atingido.");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
              content: Text('Você já atingiu o limite máximo de moedas!')),
        );
      }
      return;
    }

    final now = DateTime.now();
    String blockReason = "";

    // Verificação de limite diário
    if (lastAdTime != null &&
        now.year == lastAdTime.year &&
        now.month == lastAdTime.month &&
        now.day == lastAdTime.day &&
        adsToday >= MAX_ADS_PER_DAY) {
      blockReason = "Você atingiu o limite de anúncios por hoje.";
    }
    // Verificação de cooldown individual
    else if (lastAdTime != null &&
        now.difference(lastAdTime) < ADS_COOLDOWN_DURATION) {
      final remainingTime = ADS_COOLDOWN_DURATION - now.difference(lastAdTime);
      blockReason =
          "Aguarde ${remainingTime.inMinutes + 1} minutos para assistir outro anúncio.";
    }
    // Verificação do limite da janela de 6 horas (NOVO)
    else if (firstAdIn6HourWindow != null &&
        now.difference(firstAdIn6HourWindow) <= SIX_HOUR_WINDOW_DURATION) {
      // Estamos dentro de uma janela de 6 horas ativa
      if (adsWatchedIn6HourWindow >= MAX_ADS_PER_SIX_HOUR_WINDOW) {
        final windowEndTime =
            firstAdIn6HourWindow.add(SIX_HOUR_WINDOW_DURATION);
        final remainingWindowTime = windowEndTime.difference(now);
        blockReason =
            "Limite de $MAX_ADS_PER_SIX_HOUR_WINDOW anúncios a cada ${SIX_HOUR_WINDOW_DURATION.inHours}h atingido. Tente novamente em ${remainingWindowTime.inHours}h ${remainingWindowTime.inMinutes.remainder(60)}min.";
      }
    }

    if (blockReason.isNotEmpty) {
      print("AdMiddleware: Não pode assistir anúncio. Razão: $blockReason");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(blockReason)),
        );
      }
      return;
    }

    adHelper.showRewardedAd(onUserEarnedReward: (RewardItem reward) async {
      print(
          "AdMiddleware: Recompensa ganha! Amount: ${reward.amount}, Type: ${reward.type}");

      int coinsAwarded = COINS_PER_REWARDED_AD;
      int currentCoins =
          store.state.userState.userCoins; // Pega o valor mais recente
      int coinsThatCanBeAdded = MAX_COINS_LIMIT - currentCoins;

      if (coinsThatCanBeAdded <= 0) {
        print("AdMiddleware: Usuário já no limite de moedas.");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(content: Text('Você já está no limite de moedas!')),
          );
        }
        return;
      }

      int finalCoinsToAdd = (coinsAwarded > coinsThatCanBeAdded)
          ? coinsThatCanBeAdded
          : coinsAwarded;
      int newTotalCoins = currentCoins + finalCoinsToAdd;
      DateTime adWatchedTime = DateTime.now();

      store.dispatch(RewardedAdWatchedAction(finalCoinsToAdd, adWatchedTime));

      // ATUALIZAR STATS DA JANELA DE 6 HORAS (NOVO)
      DateTime? newFirstAdInWindowTimestamp;
      int newAdsWatchedInWindow;

      final currentFirstAdInWindow =
          store.state.userState.firstAdIn6HourWindowTimestamp;
      final currentAdsInWindow = store.state.userState.adsWatchedIn6HourWindow;

      if (currentFirstAdInWindow == null ||
          adWatchedTime.difference(currentFirstAdInWindow) >
              SIX_HOUR_WINDOW_DURATION) {
        // Começa uma nova janela
        newFirstAdInWindowTimestamp = adWatchedTime;
        newAdsWatchedInWindow = 1;
      } else {
        // Continua na janela existente
        newFirstAdInWindowTimestamp = currentFirstAdInWindow;
        newAdsWatchedInWindow = currentAdsInWindow + 1;
      }

      store.dispatch(UpdateAdWindowStatsAction(
          firstAdTimestamp: newFirstAdInWindowTimestamp,
          adsInWindowCount: newAdsWatchedInWindow));
      // Salva no SharedPreferences
      await _saveAdWindowStatsToPrefs(
          newFirstAdInWindowTimestamp, newAdsWatchedInWindow);

      try {
        // O reducer de RewardedAdWatchedAction já deve ter atualizado adsToday
        int adsWatchedTodayForFirestore =
            store.state.userState.rewardedAdsWatchedToday;

        await firestoreService.updateUserCoinsAndAdStats(
          userId, // Sabemos que não é nulo aqui
          newTotalCoins,
          adWatchedTime,
          adsWatchedTodayForFirestore,
        );
        print(
            "AdMiddleware: Moedas e estatísticas de anúncio (diário) atualizadas no Firestore.");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Você ganhou $finalCoinsToAdd moedas!')),
          );
        }
      } catch (e) {
        print(
            "AdMiddleware: Erro ao atualizar moedas/stats (diário) no Firestore: $e");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text(
                    'Erro ao salvar sua recompensa. Tente novamente mais tarde.')),
          );
        }
        // Considerar reverter a atualização otimista da janela de 6h se a do Firestore falhar?
        // Por ora, mantemos simples. A janela de 6h é local.
      }
    }, onAdFailedToShow: () {
      print("AdMiddleware: Falha ao mostrar o anúncio.");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
              content: Text(
                  'Não foi possível carregar o anúncio. Tente mais tarde.')),
        );
      }
    });
  };
}
