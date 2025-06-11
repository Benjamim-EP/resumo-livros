// lib/services/AdHelperStartIo.dart
import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

typedef OnUserEarnedRewardCallback = void Function();

class AdHelperStartIo {
  final StartAppSdk _sdk = StartAppSdk();

  // Para Anúncios Recompensados
  StartAppRewardedVideoAd? _rewardedAd;
  bool _isLoadingRewarded = false;
  OnUserEarnedRewardCallback?
      _onUserEarnedRewardCallbackForRewarded; // Renomeado para clareza
  VoidCallback? _onRewardedAdFailedToShowCallback; // Renomeado

  // --- NOVO: Para Anúncios Intersticiais ---
  StartAppInterstitialAd? _interstitialAd;
  bool _isLoadingInterstitial = false;

  AdHelperStartIo() {
    _sdk.setTestAdsEnabled(true); // Lembre-se de remover para produção!
    print("Start.io Helper: Test Ads Enabled.");

    _loadRewardedVideo();
    _loadInterstitialAd(); // Carrega um intersticial na inicialização
  }

  // --- Lógica para Anúncios Recompensados (como antes, mas com nomes de callback mais claros) ---
  void _loadRewardedVideo() {
    if (_isLoadingRewarded) {
      print('Start.io Helper: Carregamento de RECOMPENSADO já em andamento.');
      return;
    }
    _isLoadingRewarded = true;
    print('Start.io Helper: Carregando um novo anúncio RECOMPENSADO...');

    _sdk.loadRewardedVideoAd(
      onAdHidden: () {
        print('Start.io Helper: RECOMPENSADO onAdHidden - Anúncio fechado.');
        _rewardedAd?.dispose();
        _rewardedAd = null;
        _loadRewardedVideo();
      },
      onVideoCompleted: () {
        print(
            'Start.io Helper: RECOMPENSADO onVideoCompleted - Concedendo recompensa...');
        _onUserEarnedRewardCallbackForRewarded?.call();
      },
      onAdNotDisplayed: () {
        print(
            'Start.io Helper: RECOMPENSADO onAdNotDisplayed - Anúncio não foi exibido.');
        _rewardedAd?.dispose();
        _rewardedAd = null;
        _onRewardedAdFailedToShowCallback?.call();
        _loadRewardedVideo();
      },
    ).then((ad) {
      print('Start.io Helper: Anúncio RECOMPENSADO carregado com sucesso.');
      _rewardedAd = ad;
      _isLoadingRewarded = false;
    }).catchError((error) {
      print('Start.io Helper: Erro ao carregar anúncio RECOMPENSADO: $error');
      _rewardedAd = null;
      _isLoadingRewarded = false;
    });
  }

  void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdFailedToShow,
  }) {
    print('Start.io Helper: Tentando exibir anúncio RECOMPENSADO...');
    _onUserEarnedRewardCallbackForRewarded = onUserEarnedReward;
    _onRewardedAdFailedToShowCallback = onAdFailedToShow;

    if (_rewardedAd != null) {
      _rewardedAd!.show().then((shown) {
        if (shown) {
          print('Start.io Helper: RECOMPENSADO show() executado com sucesso.');
        } else {
          print('Start.io Helper: RECOMPENSADO show() retornou false.');
          _onRewardedAdFailedToShowCallback?.call();
        }
      }).catchError((error) {
        print('Start.io Helper: Erro ao chamar RECOMPENSADO show(): $error');
        _onRewardedAdFailedToShowCallback?.call();
      });
    } else {
      print(
          'Start.io Helper: Nenhum anúncio RECOMPENSADO pronto. Chamando onAdFailedToShow.');
      _onRewardedAdFailedToShowCallback?.call();
      if (!_isLoadingRewarded) {
        _loadRewardedVideo();
      }
    }
  }

  // --- NOVO: Lógica para Anúncios Intersticiais ---
  void _loadInterstitialAd() {
    if (_isLoadingInterstitial) {
      print('Start.io Helper: Carregamento de INTERSTICIAL já em andamento.');
      return;
    }
    if (_interstitialAd != null) {
      print(
          'Start.io Helper: Um INTERSTICIAL já está carregado. Use showInterstitialAd().');
      return;
    }
    _isLoadingInterstitial = true;
    print('Start.io Helper: Carregando um novo anúncio INTERSTICIAL...');

    _sdk.loadInterstitialAd(
        // Callbacks para o ciclo de vida do anúncio intersticial
        onAdDisplayed: () {
      print('Start.io Helper: INTERSTICIAL onAdDisplayed - Anúncio exibido.');
    }, onAdHidden: () {
      print('Start.io Helper: INTERSTICIAL onAdHidden - Anúncio fechado.');
      // Importante: Anúncios intersticiais do Start.io só podem ser mostrados uma vez.
      // É preciso descartar e carregar um novo.
      _interstitialAd?.dispose(); // Descarta o anúncio usado
      _interstitialAd = null; // Limpa a referência
      _loadInterstitialAd(); // Começa a carregar o próximo
    }, onAdClicked: () {
      print('Start.io Helper: INTERSTICIAL onAdClicked - Anúncio clicado.');
    }, onAdNotDisplayed: () {
      print(
          'Start.io Helper: INTERSTICIAL onAdNotDisplayed - Anúncio não foi exibido.');
      _interstitialAd?.dispose();
      _interstitialAd = null;
      // Tenta carregar um novo se este não pôde ser exibido.
      _loadInterstitialAd();
    }).then((ad) {
      print('Start.io Helper: Anúncio INTERSTICIAL carregado com sucesso.');
      _interstitialAd = ad;
      _isLoadingInterstitial = false;
    }).catchError((error, stackTrace) {
      // Adicionado stackTrace para mais detalhes
      print('Start.io Helper: Erro ao carregar anúncio INTERSTICIAL: $error');
      print('Start.io Helper: StackTrace INTERSTICIAL: $stackTrace');
      _interstitialAd = null;
      _isLoadingInterstitial = false;
    });
  }

  // Função para tentar mostrar um anúncio intersticial.
  // Retorna true se o comando show() foi chamado, false caso contrário (ex: anúncio não carregado).
  // A exibição real e o recarregamento são gerenciados pelos callbacks em _loadInterstitialAd.
  Future<bool> showInterstitialAd() async {
    print('Start.io Helper: Tentando exibir anúncio INTERSTICIAL...');
    if (_interstitialAd != null) {
      try {
        bool shown = await _interstitialAd!.show();
        if (shown) {
          print(
              'Start.io Helper: INTERSTICIAL show() executado com sucesso (retornou true).');
          // O callback onAdHidden em _loadInterstitialAd cuidará de limpar e recarregar.
        } else {
          print(
              'Start.io Helper: INTERSTICIAL show() retornou false. Anúncio não exibido.');
          // O callback onAdNotDisplayed deve ser chamado pelo SDK se show() retorna false por esse motivo.
          // Se não, podemos precisar forçar um recarregamento aqui se o anúncio ainda existir mas não mostrar.
          // No entanto, a documentação sugere que após show(), ele deve ser null.
        }
        return shown;
      } catch (e) {
        print('Start.io Helper: Erro ao chamar INTERSTICIAL show(): $e');
        // Limpa e recarrega em caso de erro na exibição
        _interstitialAd?.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
        return false;
      }
    } else {
      print('Start.io Helper: Nenhum anúncio INTERSTICIAL pronto para exibir.');
      // Se não há anúncio e não estamos carregando, tentamos carregar um.
      if (!_isLoadingInterstitial) {
        _loadInterstitialAd();
      }
      return false;
    }
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose(); // NOVO: Dispose do intersticial
    _interstitialAd = null;
  }
}
