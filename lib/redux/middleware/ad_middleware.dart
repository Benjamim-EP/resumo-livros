// lib/redux/middleware/ad_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/main.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NOVO
import 'package:septima_biblia/services/ad_helper_admob.dart'; // <<< Importe o novo helper
import 'package:google_mobile_ads/google_mobile_ads.dart'
    hide AppState; // <<< Importe o pacote do AdMob

const int COINS_PER_REWARDED_AD = 10;
const int MAX_COINS_LIMIT = 100;
const int MAX_ADS_PER_DAY = 12;
const Duration ADS_COOLDOWN_DURATION = Duration(seconds: 60);
const Duration SIX_HOUR_WINDOW_DURATION = Duration(hours: 6); // NOVO
const int MAX_ADS_PER_SIX_HOUR_WINDOW = 3; // NOVO

const String _prefsGuestCoinsKey = 'guest_user_coins';
const String _prefsGuestLastAdTimeKey = 'guest_last_ad_time';
const String _prefsGuestAdsTodayKey = 'guest_ads_today';

// Chaves para SharedPreferences
const String _prefsFirstAdIn6HourWindowKey =
    'firstAdIn6HourWindowTimestamp'; //NOVO
const String _prefsAdsWatchedIn6HourWindowKey =
    'adsWatchedIn6HourWindow'; //NOVO

List<Middleware<AppState>> createAdMiddleware() {
  final adHelper = AdHelperAdMob(); // <<< Use a nova classe
  final firestoreService = FirestoreService();

  // Pré-carrega o primeiro anúncio recompensado ao iniciar o app
  adHelper.loadRewardedAd(
    onAdLoaded: () =>
        print("AdMiddleware: Anúncio recompensado pré-carregado com sucesso."),
    onAdFailedToLoad: () =>
        print("AdMiddleware: Falha ao pré-carregar anúncio recompensado."),
  );

  return [
    TypedMiddleware<AppState, RequestRewardedAdAction>(
            _handleRequestRewardedAd(adHelper, firestoreService))
        .call,
    TypedMiddleware<AppState, LoadAdLimitDataAction>(_handleLoadAdLimitData)
        .call,
  ];
}

// Função para salvar dados do CONVIDADO no SharedPreferences
Future<void> _saveGuestAdStatsToPrefs(
    int coins, DateTime lastAdTime, int adsToday) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsGuestCoinsKey, coins);
    await prefs.setInt(guestUserCoinsPrefsKey, coins);
    await prefs.setString(
        _prefsGuestLastAdTimeKey, lastAdTime.toIso8601String());
    await prefs.setInt(_prefsGuestAdsTodayKey, adsToday);
    print("AdMiddleware: Stats de convidado salvos no SharedPreferences.");
  } catch (e) {
    print("AdMiddleware: Erro ao salvar stats de convidado: $e");
  }
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
        AdHelperAdMob adHelper, FirestoreService firestoreService) {
  return (Store<AppState> store, RequestRewardedAdAction action,
      NextDispatcher next) async {
    next(action);

    final BuildContext? currentContext = navigatorKey.currentContext;
    final userState = store.state.userState;
    final userId = userState.userId;
    final userCoins = userState.userCoins;
    final lastAdTime = userState.lastRewardedAdWatchTime;
    final adsToday = userState.rewardedAdsWatchedToday;
    final isGuest = userState.isGuestUser;
    final firstAdIn6HourWindow = userState.firstAdIn6HourWindowTimestamp;
    final adsWatchedIn6HourWindow = userState.adsWatchedIn6HourWindow;

    if (userId == null && !isGuest) {
      print(
          "AdMiddleware: Usuário nem logado, nem convidado. Ação de recompensa cancelada.");
      return;
    }

    if (userCoins >= MAX_COINS_LIMIT) {
      print("AdMiddleware (AdMob): Limite máximo de moedas atingido.");
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

    // 1. Verificação de limite diário
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
          "AdMiddleware (AdMob): Não pode assistir anúncio. Razão: $blockReason");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(blockReason)),
        );
      }
      return;
    }

    // A chamada ao AdHelper para mostrar o anúncio
    adHelper.showRewardedAd(
      onUserEarnedReward: (RewardItem reward) async {
        print(
            "AdMiddleware (AdMob): Recompensa ganha! Quantidade: ${reward.amount}, Tipo: ${reward.type}");

        int coinsAwarded =
            reward.amount.toInt(); // A quantidade vem do AdMob agora
        int currentCoinsInState = store.state.userState.userCoins;
        int coinsThatCanBeAdded = MAX_COINS_LIMIT - currentCoinsInState;

        if (coinsThatCanBeAdded <= 0) {
          if (currentContext != null && currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                  content: Text('Você já está no limite de moedas!')),
            );
          }
          return;
        }

        int finalCoinsToAdd = (coinsAwarded > coinsThatCanBeAdded)
            ? coinsThatCanBeAdded
            : coinsAwarded;
        DateTime adWatchedTime = DateTime.now();

        store.dispatch(RewardedAdWatchedAction(finalCoinsToAdd, adWatchedTime));

        DateTime? newFirstAdInWindowTimestamp;
        int newAdsWatchedInWindow;
        final currentFirstAdInWindow =
            store.state.userState.firstAdIn6HourWindowTimestamp;
        final currentAdsInWindow =
            store.state.userState.adsWatchedIn6HourWindow;

        if (currentFirstAdInWindow == null ||
            adWatchedTime.difference(currentFirstAdInWindow) >
                SIX_HOUR_WINDOW_DURATION) {
          newFirstAdInWindowTimestamp = adWatchedTime;
          newAdsWatchedInWindow = 1;
        } else {
          newFirstAdInWindowTimestamp = currentFirstAdInWindow;
          newAdsWatchedInWindow = currentAdsInWindow + 1;
        }

        store.dispatch(UpdateAdWindowStatsAction(
            firstAdTimestamp: newFirstAdInWindowTimestamp,
            adsInWindowCount: newAdsWatchedInWindow));

        await _saveAdWindowStatsToPrefs(
            newFirstAdInWindowTimestamp, newAdsWatchedInWindow);

        int newTotalCoins = store.state.userState.userCoins;
        int adsWatchedTodayForPersistence =
            store.state.userState.rewardedAdsWatchedToday;

        if (userId != null) {
          try {
            await firestoreService.updateUserCoinsAndAdStats(
              userId,
              newTotalCoins,
              adWatchedTime,
              adsWatchedTodayForPersistence,
            );
            print(
                "AdMiddleware (AdMob): Moedas e estatísticas de anúncio atualizadas no Firestore.");
          } catch (e) {
            print(
                "AdMiddleware (AdMob): Erro ao atualizar moedas/stats no Firestore: $e");
            // Reverte a mudança otimista no Redux
            store.dispatch(
                RewardedAdWatchedAction(-finalCoinsToAdd, adWatchedTime));
            if (currentContext != null && currentContext.mounted) {
              ScaffoldMessenger.of(currentContext).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Erro ao salvar sua recompensa. Tente novamente mais tarde.')),
              );
            }
            return;
          }
        } else if (isGuest) {
          await _saveGuestAdStatsToPrefs(
              newTotalCoins, adWatchedTime, adsWatchedTodayForPersistence);
        }

        if (currentContext != null && currentContext.mounted) {
          CustomNotificationService.showSuccess(
            currentContext,
            'Você ganhou $finalCoinsToAdd moedas!',
          );
        }
      },
      onAdFailedToShow: () {
        print("AdMiddleware (AdMob): Falha ao exibir o anúncio.");
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
