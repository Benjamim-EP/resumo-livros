// lib/services/AdHelperStartIo.dart
import 'dart:async'; // Para Completer
import 'package:flutter/material.dart';
import 'package:startapp_sdk/startapp.dart';

typedef OnUserEarnedRewardCallback = void Function();

class AdHelperStartIo {
  final StartAppSdk _sdk = StartAppSdk();

  StartAppRewardedVideoAd? _rewardedAdInstance;
  bool _isRewardedAdLoading = false;
  StartAppInterstitialAd? _interstitialAdInstance;
  bool _isInterstitialAdLoading = false;

  // Callbacks que serão definidos pelo middleware ao chamar showRewardedAd
  // Estes são passados para o showRewardedAd e usados quando um anúncio específico é exibido
  OnUserEarnedRewardCallback? _currentOnUserEarnedRewardCallback;
  VoidCallback? _currentOnRewardedAdFailedToShowCallback;
  VoidCallback?
      _currentOnRewardedAdHiddenCallback; // Para recarregar após fechar

  // Completer para sinalizar quando o carregamento do anúncio termina (sucesso ou falha)
  Completer<StartAppRewardedVideoAd?>? _rewardedAdLoadCompleter;

  AdHelperStartIo() {
    _sdk.setTestAdsEnabled(false);
    //print("Start.io Helper: Test Ads Enabled.");
    // Inicia um pré-carregamento, mas não bloqueia.
    // O showRewardedAd tentará carregar se necessário.
    ensureRewardedVideoIsLoaded();
  }

  // Carrega um anúncio recompensado se não houver um pronto ou carregando.
  // Retorna um Future que completa quando o anúncio está carregado ou falha.
  Future<StartAppRewardedVideoAd?> _loadRewardedVideoAdInternal() async {
    if (_rewardedAdInstance != null) {
      print('Start.io Helper: RECOMPENSADO já carregado.');
      return _rewardedAdInstance;
    }
    if (_isRewardedAdLoading && _rewardedAdLoadCompleter != null) {
      print(
          'Start.io Helper: RECOMPENSADO carregamento já em andamento, aguardando completer existente.');
      return _rewardedAdLoadCompleter!.future;
    }

    _isRewardedAdLoading = true;
    _rewardedAdLoadCompleter = Completer<StartAppRewardedVideoAd?>();
    print(
        'Start.io Helper: Carregando um novo anúncio RECOMPENSADO (interno)...');

    _sdk.loadRewardedVideoAd(
      onAdHidden: () {
        print(
            'Start.io Helper: RECOMPENSADO onAdHidden (interno) - Anúncio fechado.');
        _rewardedAdInstance?.dispose();
        _rewardedAdInstance = null;
        _currentOnRewardedAdHiddenCallback
            ?.call(); // Chama o callback de hidden se existir
        ensureRewardedVideoIsLoaded(); // Tenta carregar o próximo
      },
      onVideoCompleted: () {
        print(
            'Start.io Helper: RECOMPENSADO onVideoCompleted (interno) - Concedendo recompensa...');
        _currentOnUserEarnedRewardCallback
            ?.call(); // Chama o callback de recompensa
      },
      onAdNotDisplayed: () {
        print(
            'Start.io Helper: RECOMPENSADO onAdNotDisplayed (interno) - Anúncio não foi exibido.');
        _rewardedAdInstance?.dispose();
        _rewardedAdInstance = null;
        _currentOnRewardedAdFailedToShowCallback
            ?.call(); // Chama o callback de falha
        ensureRewardedVideoIsLoaded(); // Tenta carregar um novo
      },
    ).then((ad) {
      print(
          'Start.io Helper: Anúncio RECOMPENSADO carregado com sucesso (interno).');
      _rewardedAdInstance = ad;
      _isRewardedAdLoading = false;
      if (!_rewardedAdLoadCompleter!.isCompleted) {
        _rewardedAdLoadCompleter!.complete(ad);
      }
    }).catchError((error, stackTrace) {
      print(
          'Start.io Helper: Erro ao carregar anúncio RECOMPENSADO (interno): $error');
      print('Start.io Helper: StackTrace RECOMPENSADO (interno): $stackTrace');
      _rewardedAdInstance = null;
      _isRewardedAdLoading = false;
      if (!_rewardedAdLoadCompleter!.isCompleted) {
        _rewardedAdLoadCompleter!.complete(null);
      }
    });
    return _rewardedAdLoadCompleter!.future;
  }

  // Garante que um anúncio recompensado esteja sendo carregado ou já carregado.
  // Usado para pré-carregamento.
  void ensureRewardedVideoIsLoaded() {
    if (_rewardedAdInstance == null && !_isRewardedAdLoading) {
      _loadRewardedVideoAdInternal();
    }
  }

  // Tenta mostrar um anúncio. Se não estiver carregado, carrega e depois mostra.
  Future<void> showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdFailedToShow,
    VoidCallback?
        onAdHidden, // Opcional: se o middleware precisar saber quando foi fechado
  }) async {
    print(
        'Start.io Helper: Tentando exibir anúncio RECOMPENSADO (com carregamento sob demanda)...');
    _currentOnUserEarnedRewardCallback = onUserEarnedReward;
    _currentOnRewardedAdFailedToShowCallback = onAdFailedToShow;
    _currentOnRewardedAdHiddenCallback = onAdHidden;

    StartAppRewardedVideoAd? adToShow = _rewardedAdInstance;

    if (adToShow == null) {
      if (_isRewardedAdLoading) {
        print(
            'Start.io Helper: Anúncio RECOMPENSADO está carregando, aguardando...');
        // Espera pelo carregamento atual
        adToShow = await (_rewardedAdLoadCompleter?.future);
      } else {
        print(
            'Start.io Helper: Nenhum anúncio RECOMPENSADO carregado, iniciando novo carregamento...');
        // Inicia um novo carregamento e espera por ele
        adToShow = await _loadRewardedVideoAdInternal();
      }
    }

    if (adToShow != null) {
      try {
        print(
            'Start.io Helper: Anúncio RECOMPENSADO está pronto. Tentando mostrar...');
        bool shown = await adToShow.show();
        if (shown) {
          print(
              'Start.io Helper: RECOMPENSADO show() chamado com sucesso (retornou true).');
          // Os callbacks onVideoCompleted e onAdHidden definidos em _loadRewardedVideoAdInternal
          // serão acionados pelo SDK.
        } else {
          print(
              'Start.io Helper: RECOMPENSADO show() retornou false (anúncio não exibido).');
          _currentOnRewardedAdFailedToShowCallback?.call();
          // Se show() retorna false, o SDK pode ter chamado onAdNotDisplayed,
          // que já tentaria recarregar. Mas por segurança, podemos garantir.
          _rewardedAdInstance =
              null; // Considerar que o anúncio não pôde ser usado
          ensureRewardedVideoIsLoaded();
        }
      } catch (e) {
        print('Start.io Helper: Erro ao chamar RECOMPENSADO show(): $e');
        _currentOnRewardedAdFailedToShowCallback?.call();
        _rewardedAdInstance = null; // Anúncio pode ter se tornado inválido
        ensureRewardedVideoIsLoaded(); // Tenta recarregar
      }
    } else {
      print(
          'Start.io Helper: Falha ao carregar anúncio RECOMPENSADO após espera.');
      _currentOnRewardedAdFailedToShowCallback?.call();
    }
  }

  // --- Lógica para Anúncios Intersticiais (mantida como antes, mas pode ser adaptada de forma similar) ---
  void _loadInterstitialAd() {
    if (_isInterstitialAdLoading) {
      print('Start.io Helper: Carregamento de INTERSTICIAL já em andamento.');
      return;
    }
    if (_interstitialAdInstance != null) {
      print('Start.io Helper: Um anúncio INTERSTICIAL já está carregado.');
      return;
    }
    _isInterstitialAdLoading = true;
    print('Start.io Helper: Carregando um novo anúncio INTERSTICIAL...');
    _sdk.loadInterstitialAd(
      onAdDisplayed: () {/* ... */},
      onAdHidden: () {
        print('Start.io Helper: INTERSTICIAL onAdHidden - Anúncio fechado.');
        _interstitialAdInstance?.dispose();
        _interstitialAdInstance = null;
        _isInterstitialAdLoading = false;
        _loadInterstitialAd();
      },
      onAdClicked: () {/* ... */},
      onAdNotDisplayed: () {
        print(
            'Start.io Helper: INTERSTICIAL onAdNotDisplayed - Anúncio não foi exibido.');
        _interstitialAdInstance?.dispose();
        _interstitialAdInstance = null;
        _isInterstitialAdLoading = false;
        _loadInterstitialAd();
      },
    ).then((ad) {
      print('Start.io Helper: Anúncio INTERSTICIAL carregado com sucesso.');
      _interstitialAdInstance = ad;
      _isInterstitialAdLoading = false;
    }).catchError((error, stackTrace) {
      print('Start.io Helper: Erro ao carregar anúncio INTERSTICIAL: $error');
      print('Start.io Helper: StackTrace INTERSTICIAL: $stackTrace');
      _interstitialAdInstance = null;
      _isInterstitialAdLoading = false;
    });
  }

  Future<bool> showInterstitialAd() async {
    print('Start.io Helper: Tentando exibir anúncio INTERSTICIAL...');
    StartAppInterstitialAd? adToDisplay = _interstitialAdInstance;

    if (adToDisplay == null && !_isInterstitialAdLoading) {
      print(
          'Start.io Helper: Intersticial não carregado, iniciando carregamento e aguardando...');
      // Para intersticiais, o padrão pode ser apenas tentar carregar para a próxima vez,
      // ou você pode implementar um Completer similar ao recompensado se quiser esperar.
      // Por simplicidade aqui, vamos apenas tentar carregar para a próxima vez.
      _loadInterstitialAd();
      return false; // Não mostra agora, pois não está pronto.
    } else if (_isInterstitialAdLoading) {
      print('Start.io Helper: Intersticial ainda carregando...');
      return false; // Não mostra agora.
    }

    if (adToDisplay != null) {
      // Deve ser _interstitialAdInstance aqui
      try {
        bool shown = await adToDisplay.show();
        if (shown) {
          print(
              'Start.io Helper: INTERSTICIAL show() chamado com sucesso (retornou true).');
        } else {
          print(
              'Start.io Helper: INTERSTICIAL show() retornou false (anúncio não exibido).');
          _interstitialAdInstance = null; // Já foi usado ou falhou em mostrar
          _loadInterstitialAd(); // Tenta recarregar
        }
        return shown;
      } catch (e) {
        print('Start.io Helper: Erro ao chamar INTERSTICIAL show(): $e');
        _interstitialAdInstance = null;
        _loadInterstitialAd();
        return false;
      }
    }
    return false; // Se chegou aqui, algo deu errado.
  }

  void dispose() {
    print("Start.io Helper: Chamando dispose().");
    _rewardedAdInstance?.dispose();
    _rewardedAdInstance = null;
    _interstitialAdInstance?.dispose();
    _interstitialAdInstance = null;
  }
}
