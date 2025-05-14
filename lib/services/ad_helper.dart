// lib/services/ad_helper.dart
import 'dart:ui';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

typedef OnUserEarnedRewardCallback = void Function(RewardItem reward);

class AdHelper {
  static String get bannerAdUnitId {
    // Mantido como estava
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // Test ID
    } else {
      throw UnsupportedError('Plataforma não suportada para Banner Ad');
    }
  }

  static String get rewardedAdUnitId {
    // Mantido como estava
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // Test ID
    } else {
      throw UnsupportedError('Plataforma não suportada para Rewarded Ad');
    }
  }

  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;
  bool _isCurrentlyLoadingAd = false;
  OnUserEarnedRewardCallback?
      _pendingOnUserEarnedRewardCallback; // Para armazenar o callback do load inicial

  // Construtor (opcional, mas bom para clareza se você chamar load na inicialização do AdHelper)
  AdHelper() {
    // Pré-carrega um anúncio quando o AdHelper é instanciado.
    // O callback aqui é um genérico, o específico será passado ao mostrar.
    _pendingOnUserEarnedRewardCallback = (RewardItem reward) {
      print(
          "AdHelper (preload): Recompensa do anúncio pré-carregado. Amount: ${reward.amount}, Type: ${reward.type}. Esta recompensa não é concedida automaticamente.");
    };
    loadRewardedAd(onUserEarnedReward: _pendingOnUserEarnedRewardCallback!);
  }

  void loadRewardedAd(
      {required OnUserEarnedRewardCallback onUserEarnedReward}) {
    if (_isRewardedAdReady || _isCurrentlyLoadingAd) {
      print("AdHelper: Anúncio já pronto ou carregando. Abortando nova carga.");
      return;
    }

    _isCurrentlyLoadingAd = true;
    // Armazena o callback que será usado se este anúncio específico for mostrado
    // No entanto, o callback mais importante é o passado para `showRewardedAd`.
    // O _pendingOnUserEarnedRewardCallback é mais para o FullScreenContentCallback.
    _pendingOnUserEarnedRewardCallback = onUserEarnedReward;

    print("AdHelper: Carregando anúncio recompensado...");
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('AdHelper: Anúncio recompensado carregado ID: ${ad.adUnitId}');
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          _isCurrentlyLoadingAd = false;

          // Configura os callbacks de ciclo de vida do anúncio aqui.
          // O onUserEarnedReward é passado para `show()`.
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (RewardedAd ad) => print(
                'AdHelper: Anúncio ${ad.adUnitId} mostrado em tela cheia.'),
            onAdDismissedFullScreenContent: (RewardedAd ad) {
              print('AdHelper: Anúncio ${ad.adUnitId} dispensado.');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              // Tenta carregar o próximo anúncio, usando o callback pendente (ou um novo se a lógica mudar)
              if (_pendingOnUserEarnedRewardCallback != null) {
                loadRewardedAd(
                    onUserEarnedReward: _pendingOnUserEarnedRewardCallback!);
              }
            },
            onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
              print(
                  'AdHelper: Falha ao mostrar anúncio ${ad.adUnitId}: $error');
              ad.dispose();
              _rewardedAd = null;
              _isRewardedAdReady = false;
              _isCurrentlyLoadingAd = false;
              // Não tenta recarregar imediatamente aqui para evitar loops de falha.
              // O middleware pode tentar novamente se o usuário solicitar.
            },
            // onAdImpression: (RewardedAd ad) => print('AdHelper: Impressão do anúncio ${ad.adUnitId}.'),
            // onAdClicked: (RewardedAd ad) => print('AdHelper: Anúncio ${ad.adUnitId} clicado.'),
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          print(
              'AdHelper: Falha ao carregar anúncio recompensado: ${error.message}');
          _rewardedAd = null;
          _isRewardedAdReady = false;
          _isCurrentlyLoadingAd = false;
        },
      ),
    );
  }

  void showRewardedAd({
    required OnUserEarnedRewardCallback
        onUserEarnedReward, // Callback específico para ESTA exibição
    VoidCallback? onAdFailedToShow,
    VoidCallback? onAdShowed, // Callback opcional quando o anúncio é mostrado
    VoidCallback?
        onAdDismissed, // Callback opcional quando o anúncio é dispensado
  }) {
    if (_rewardedAd != null && _isRewardedAdReady) {
      print("AdHelper: Mostrando anúncio recompensado...");

      // Reconfigura o fullScreenContentCallback para esta exibição específica, se necessário,
      // especialmente para onAdDismissedFullScreenContent se a lógica de recarga precisa ser diferente.
      // No entanto, o principal é o onUserEarnedReward.
      _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          print(
              'AdHelper: Anúncio ${ad.adUnitId} mostrado em tela cheia (via showRewardedAd).');
          onAdShowed?.call();
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print(
              'AdHelper: Anúncio ${ad.adUnitId} dispensado (via showRewardedAd).');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          onAdDismissed?.call(); // Chama o callback de dispensa se fornecido
          // Tenta carregar o próximo anúncio para futuras solicitações
          if (_pendingOnUserEarnedRewardCallback != null) {
            loadRewardedAd(
                onUserEarnedReward: _pendingOnUserEarnedRewardCallback!);
          }
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print(
              'AdHelper: Falha ao mostrar anúncio ${ad.adUnitId} (via showRewardedAd): $error');
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdReady = false;
          onAdFailedToShow?.call();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print('AdHelper: Recompensa ganha: ${reward.amount} ${reward.type}');
          onUserEarnedReward(
              reward); // Chama o callback de recompensa fornecido pelo middleware
        },
      );
      // _isRewardedAdReady = false; // Comentado: O anúncio é consumido, mas a flag é melhor gerenciada pelos callbacks de tela cheia.
      // Se o anúncio for mostrado com sucesso, ele será dispensado ou falhará ao mostrar,
      // e esses callbacks cuidarão de resetar a flag e recarregar.
    } else {
      print(
          'AdHelper: Anúncio recompensado não está pronto para ser mostrado ou é nulo.');
      if (!_isCurrentlyLoadingAd) {
        // Tenta carregar um anúncio para a *próxima* vez, usando o callback PENDENTE.
        // O callback `onUserEarnedReward` passado para este `showRewardedAd` é específico para esta tentativa de exibição.
        if (_pendingOnUserEarnedRewardCallback != null) {
          loadRewardedAd(
              onUserEarnedReward: _pendingOnUserEarnedRewardCallback!);
        }
      }
      onAdFailedToShow?.call();
    }
  }

  void disposeRewardedAd() {
    // Mantido como estava
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdReady = false;
    _isCurrentlyLoadingAd = false;
  }
}
