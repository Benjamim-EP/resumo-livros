// lib/redux/middleware/ad_middleware.dart
import 'package:flutter/material.dart'; // Para ScaffoldMessenger
import 'package:google_mobile_ads/google_mobile_ads.dart'
    hide AppState; // <<< MODIFICAÇÃO AQUI
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
// Abaixo, 'AppState' se referirá ao seu AppState definido em store.dart
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/services/ad_helper.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/main.dart'; // Para navigatorKey

const int COINS_PER_REWARDED_AD = 10;
const int MAX_COINS_LIMIT = 100;
const int MAX_ADS_PER_DAY = 5; // Exemplo: Limite de 5 anúncios por dia
const Duration ADS_COOLDOWN_DURATION =
    Duration(hours: 1); // Exemplo: Cooldown de 1 hora

List<Middleware<AppState>> createAdMiddleware() {
  final adHelper = AdHelper();
  final firestoreService = FirestoreService();

  // Carrega um anúncio na inicialização do middleware (e após ser dispensado)
  // O callback onUserEarnedReward será definido ao mostrar o anúncio
  adHelper.loadRewardedAd(onUserEarnedReward: (RewardItem reward) {
    // Agora RewardItem é reconhecido
    // Este callback é mais um placeholder para o load inicial.
    // A lógica real de recompensa acontece no _handleRequestRewardedAd.
    print(
        "AdHelper (init load): Recompensa inicial, normalmente não deve ser chamada aqui. ${reward.amount} ${reward.type}");
  });

  return [
    TypedMiddleware<AppState, RequestRewardedAdAction>(
        _handleRequestRewardedAd(adHelper, firestoreService)),
  ];
}

void Function(Store<AppState>, RequestRewardedAdAction, NextDispatcher)
    _handleRequestRewardedAd(
        AdHelper adHelper, FirestoreService firestoreService) {
  return (Store<AppState> store, RequestRewardedAdAction action,
      NextDispatcher next) async {
    next(action);

    final BuildContext? currentContext = navigatorKey.currentContext;
    final userId = store.state.userState.userId;
    final userCoins = store.state.userState.userCoins;
    final lastAdTime = store.state.userState.lastRewardedAdWatchTime;
    final adsToday = store.state.userState.rewardedAdsWatchedToday;

    if (userId == null) {
      print("AdMiddleware: Usuário não logado. Não pode mostrar anúncio.");
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
    bool canWatchAd = true;
    String blockReason = "";

    if (lastAdTime != null &&
        now.difference(lastAdTime) < ADS_COOLDOWN_DURATION) {
      canWatchAd = false;
      final remainingTime = ADS_COOLDOWN_DURATION - now.difference(lastAdTime);
      blockReason =
          "Aguarde ${remainingTime.inMinutes + 1} minutos para assistir outro anúncio.";
    } else if (lastAdTime != null &&
        (now.year > lastAdTime.year ||
            now.month > lastAdTime.month ||
            now.day > lastAdTime.day)) {
      // É um novo dia, adsToday será resetado pelo reducer ao despachar RewardedAdWatchedAction
      // Aqui só verificamos se, apesar de ser um novo dia, o adsToday do estado (que ainda reflete o dia anterior) já atingiu o limite.
      // Esta condição pode ser simplificada se o reset do adsToday for confiável e ocorrer antes desta verificação.
      // Por agora, a lógica no reducer é mais importante para o reset.
    } else if (adsToday >= MAX_ADS_PER_DAY) {
      canWatchAd = false;
      blockReason = "Você atingiu o limite de anúncios por hoje.";
    }

    if (!canWatchAd) {
      print("AdMiddleware: Não pode assistir anúncio. Razão: $blockReason");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text(blockReason)),
        );
      }
      return;
    }

    adHelper.showRewardedAd(onUserEarnedReward: (RewardItem reward) async {
      // Agora RewardItem é reconhecido
      print(
          "AdMiddleware: Recompensa ganha pelo usuário! Amount: ${reward.amount}, Type: ${reward.type}");

      int coinsAwarded = COINS_PER_REWARDED_AD;
      int currentCoins = store.state.userState.userCoins;
      int coinsThatCanBeAdded = MAX_COINS_LIMIT - currentCoins;

      if (coinsThatCanBeAdded <= 0) {
        print(
            "AdMiddleware: Usuário já no limite de moedas, nenhuma moeda adicionada.");
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

      try {
        // O reducer atualiza o estado local de adsToday, que é então salvo.
        int adsWatchedTodayForFirestore =
            store.state.userState.rewardedAdsWatchedToday;

        await firestoreService.updateUserCoinsAndAdStats(
          userId,
          newTotalCoins,
          adWatchedTime,
          adsWatchedTodayForFirestore,
        );
        print(
            "AdMiddleware: Moedas e estatísticas de anúncio atualizadas no Firestore.");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(content: Text('Você ganhou $finalCoinsToAdd moedas!')),
          );
        }
      } catch (e) {
        print("AdMiddleware: Erro ao atualizar moedas/stats no Firestore: $e");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text(
                    'Erro ao salvar sua recompensa. Tente novamente mais tarde.')),
          );
        }
      }
    }, onAdFailedToShow: () {
      print(
          "AdMiddleware: Falha ao mostrar o anúncio (callback de showRewardedAd).");
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
