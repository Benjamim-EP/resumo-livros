// lib/redux/middleware/ad_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/AdHelperStartIo.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NOVO

const int COINS_PER_REWARDED_AD = 10;
const int MAX_COINS_LIMIT = 100;
const int MAX_ADS_PER_DAY = 12;
const Duration ADS_COOLDOWN_DURATION = Duration(seconds: 60);
const Duration SIX_HOUR_WINDOW_DURATION = Duration(hours: 6); // NOVO
const int MAX_ADS_PER_SIX_HOUR_WINDOW = 3; // NOVO

// Chaves para SharedPreferences
const String _prefsFirstAdIn6HourWindowKey =
    'firstAdIn6HourWindowTimestamp'; //NOVO
const String _prefsAdsWatchedIn6HourWindowKey =
    'adsWatchedIn6HourWindow'; //NOVO

List<Middleware<AppState>> createAdMiddleware() {
  final adHelper = AdHelperStartIo(); // <<< MUDANÇA
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, RequestRewardedAdAction>(
            _handleRequestRewardedAd(adHelper, firestoreService))
        .call,
    TypedMiddleware<AppState, LoadAdLimitDataAction>(_handleLoadAdLimitData)
        .call,
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
        AdHelperStartIo adHelper, FirestoreService firestoreService) {
  return (Store<AppState> store, RequestRewardedAdAction action,
      NextDispatcher next) async {
    next(action);

    final BuildContext? currentContext = navigatorKey.currentContext;
    final userState = store.state.userState;
    final userId = userState.userId;
    final userCoins = userState.userCoins;
    final lastAdTime = userState.lastRewardedAdWatchTime;
    final adsToday = userState.rewardedAdsWatchedToday;

    // Dados da janela de 6 horas
    final firstAdIn6HourWindow = userState.firstAdIn6HourWindowTimestamp;
    final adsWatchedIn6HourWindow = userState.adsWatchedIn6HourWindow;

    if (userId == null) {
      print(
          "AdMiddleware (Start.io): Usuário não logado. Ação de recompensa cancelada.");
      return;
    }

    if (userCoins >= MAX_COINS_LIMIT) {
      print("AdMiddleware (Start.io): Limite máximo de moedas atingido.");
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

    // 1. Verificação de limite diário (do dia anterior)
    if (lastAdTime != null &&
        now.year == lastAdTime.year &&
        now.month == lastAdTime.month &&
        now.day == lastAdTime.day &&
        adsToday >= MAX_ADS_PER_DAY) {
      blockReason = "Você atingiu o limite de anúncios por hoje. Volte amanhã!";
    }
    // 2. Verificação de cooldown individual
    else if (lastAdTime != null &&
        now.difference(lastAdTime) < ADS_COOLDOWN_DURATION) {
      final remainingTime = ADS_COOLDOWN_DURATION - now.difference(lastAdTime);
      blockReason =
          "Aguarde ${remainingTime.inSeconds + 1} segundos para assistir outro anúncio.";
    }
    // 3. Verificação do limite da janela de 6 horas
    else if (firstAdIn6HourWindow != null &&
        now.difference(firstAdIn6HourWindow) <= SIX_HOUR_WINDOW_DURATION) {
      if (adsWatchedIn6HourWindow >= MAX_ADS_PER_SIX_HOUR_WINDOW) {
        final windowEndTime =
            firstAdIn6HourWindow.add(SIX_HOUR_WINDOW_DURATION);
        final remainingWindowTime = windowEndTime.difference(now);
        blockReason =
            "Limite de anúncios atingido. Tente novamente em ${remainingWindowTime.inHours}h ${remainingWindowTime.inMinutes.remainder(60)}min.";
      }
    }

    if (blockReason.isNotEmpty) {
      print(
          "AdMiddleware (Start.io): Não pode assistir anúncio. Razão: $blockReason");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(blockReason)),
        );
      }
      return;
    }

    // Se passou por todas as verificações, mostra o anúncio do Start.io
    adHelper.showRewardedAd(
      // O callback a ser executado QUANDO o Start.io confirmar a recompensa
      onUserEarnedReward: () async {
        print("AdMiddleware (Start.io): Callback onUserEarnedReward acionado!");

        // --- LÓGICA DE CONCESSÃO DE RECOMPENSA (idêntica à anterior) ---
        int coinsAwarded = COINS_PER_REWARDED_AD;
        // Pega o valor mais recente das moedas do estado Redux para evitar race conditions
        int currentCoinsInState = store.state.userState.userCoins;
        int coinsThatCanBeAdded = MAX_COINS_LIMIT - currentCoinsInState;

        if (coinsThatCanBeAdded <= 0) {
          print(
              "AdMiddleware (Start.io): Usuário já no limite de moedas no momento da recompensa.");
          if (currentContext != null && currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                  content: Text('Você já está no limite de moedas!')),
            );
          }
          return; // Sai sem conceder recompensa
        }

        // Garante que não ultrapassará o limite
        int finalCoinsToAdd = (coinsAwarded > coinsThatCanBeAdded)
            ? coinsThatCanBeAdded
            : coinsAwarded;

        DateTime adWatchedTime = DateTime.now();

        // Despacha a ação para atualizar o estado do Redux otimisticamente
        store.dispatch(RewardedAdWatchedAction(finalCoinsToAdd, adWatchedTime));

        // Atualiza os stats da janela de 6 horas no Redux e no SharedPreferences
        DateTime? newFirstAdInWindowTimestamp;
        int newAdsWatchedInWindow;
        final currentFirstAdInWindow =
            store.state.userState.firstAdIn6HourWindowTimestamp;
        final currentAdsInWindow =
            store.state.userState.adsWatchedIn6HourWindow;

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

        await _saveAdWindowStatsToPrefs(
            newFirstAdInWindowTimestamp, newAdsWatchedInWindow);

        // Tenta salvar no Firestore
        try {
          int newTotalCoins = currentCoinsInState + finalCoinsToAdd;
          int adsWatchedTodayForFirestore =
              store.state.userState.rewardedAdsWatchedToday;

          await firestoreService.updateUserCoinsAndAdStats(
            userId,
            newTotalCoins,
            adWatchedTime,
            adsWatchedTodayForFirestore,
          );
          print(
              "AdMiddleware (Start.io): Moedas e estatísticas de anúncio atualizadas no Firestore.");
          if (currentContext != null && currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              SnackBar(content: Text('Você ganhou $finalCoinsToAdd moedas!')),
            );
          }
        } catch (e) {
          print(
              "AdMiddleware (Start.io): Erro ao atualizar moedas/stats no Firestore: $e");
          if (currentContext != null && currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Erro ao salvar sua recompensa. Tente novamente mais tarde.')),
            );
          }
          // Considerar reverter o estado do Redux se a escrita no Firestore falhar
        }
      },
      // O callback a ser executado se o anúncio não puder ser mostrado
      onAdFailedToShow: () {
        print("AdMiddleware (Start.io): Callback onAdFailedToShow acionado.");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text(
                    'Não foi possível carregar o anúncio. Tente mais tarde.')),
          );
        }
      },
    );
  };
}
