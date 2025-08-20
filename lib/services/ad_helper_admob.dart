// lib/services/ad_helper_admob.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Callback para quando o usuário ganha a recompensa
typedef OnUserEarnedRewardCallback = void Function(RewardItem reward);

class AdHelperAdMob {
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Retorna IDs de TESTE se estiver em modo de depuração
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    // Retorna seus IDs de PRODUÇÃO se estiver em modo de lançamento (release)
    if (Platform.isAndroid) {
      // SEU ID DE ANÚNCIO PREMIADO DE PRODUÇÃO
      return 'ca-app-pub-4468465791620075/1119371825';
    } else if (Platform.isIOS) {
      // Quando você criar para iOS, coloque o ID aqui
      return 'ca-app-pub-SEU_PUBLISHER_ID_IOS/SEU_AD_UNIT_ID_IOS_REWARDED';
    } else {
      throw UnsupportedError('Plataforma não suportada');
    }
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Retorna IDs de TESTE se estiver em modo de depuração
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    // Retorna seus IDs de PRODUÇÃO se estiver em modo de lançamento (release)
    if (Platform.isAndroid) {
      // <<< SUBSTITUA AQUI PELO SEU ID DE ANÚNCIO INTERSTICIAL >>>
      return 'ca-app-pub-4468465791620075/8351796915';
    } else if (Platform.isIOS) {
      // Quando você criar para iOS, coloque o ID aqui
      return 'ca-app-pub-SEU_PUBLISHER_ID_IOS/SEU_AD_UNIT_ID_IOS_INTERSTITIAL';
    } else {
      throw UnsupportedError('Plataforma não suportada');
    }
  }

  // --- Lógica para Anúncios Recompensados ---
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  void loadRewardedAd({
    required VoidCallback onAdLoaded, // Adicionado para feedback
    required VoidCallback onAdFailedToLoad,
  }) {
    if (_isRewardedAdLoading || _rewardedAd != null) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('AdHelperAdMob: Anúncio recompensado carregado.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
          onAdLoaded();
        },
        onAdFailedToLoad: (LoadAdError error) {
          print(
              'AdHelperAdMob: Falha ao carregar anúncio recompensado: $error');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          onAdFailedToLoad();
        },
      ),
    );
  }

  void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdFailedToShow,
  }) {
    if (_rewardedAd == null) {
      print(
          'AdHelperAdMob: Tentou mostrar anúncio recompensado, mas era nulo. Tentando carregar...');
      onAdFailedToShow();
      loadRewardedAd(
          onAdLoaded: () {
            print(
                "AdHelperAdMob: Anúncio carregado sob demanda, mas o usuário precisará tentar novamente.");
          },
          onAdFailedToLoad: () {});
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {},
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _rewardedAd = null;
        // Pré-carrega o próximo anúncio
        loadRewardedAd(onAdLoaded: () {}, onAdFailedToLoad: () {});
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('AdHelperAdMob: Falha ao exibir anúncio: $error');
        ad.dispose();
        _rewardedAd = null;
        onAdFailedToShow();
        loadRewardedAd(onAdLoaded: () {}, onAdFailedToLoad: () {});
      },
    );

    _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      onUserEarnedReward(reward);
    });
    _rewardedAd = null; // O anúncio só pode ser usado uma vez
  }

  // --- Lógica para Anúncios Intersticiais ---
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          print('AdHelperAdMob: Falha ao carregar intersticial: $error');
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Pré-carrega o próximo
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // Tenta carregar de novo
        },
      );
      await _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      print(
          "AdHelperAdMob: Intersticial não estava pronto. Carregando para a próxima vez.");
      loadInterstitialAd();
    }
  }
}
