// lib/services/AdHelperStartIo.dart
// ATUALIZADO COM BASE NA DOCUMENTAÇÃO OFICIAL START.IO

import 'package:flutter/material.dart'; // Necessário para Widget
import 'package:startapp_sdk/startapp.dart';

// Definindo o tipo de callback que o middleware vai usar.
// Não precisa passar parâmetros, pois a recompensa é fixa no nosso caso.
typedef OnUserEarnedRewardCallback = void Function();

class AdHelperStartIo {
  final StartAppSdk _sdk = StartAppSdk();
  StartAppRewardedVideoAd? _rewardedAd;
  bool _isLoading = false;

  OnUserEarnedRewardCallback? _onUserEarnedReward;
  VoidCallback? _onAdFailedToShow;

  AdHelperStartIo() {
    // TODO: Certifique-se de comentar ou remover esta linha antes da produção!
    _sdk.setTestAdsEnabled(true); // HABILITA ANÚNCIOS DE TESTE AQUI
    print("Start.io Helper: Test Ads Enabled.");

    _loadRewardedVideo(); // Inicia o carregamento do primeiro anúncio
  }

  // Carrega um novo anúncio recompensado.
  // Os callbacks aqui definem o comportamento do ciclo de vida do anúncio.
  void _loadRewardedVideo() {
    if (_isLoading) {
      print(
          'Start.io Helper: Carregamento de anúncio recompensado já em andamento.');
      return;
    }
    _isLoading = true;
    print('Start.io Helper: Carregando um novo anúncio recompensado...');

    _sdk.loadRewardedVideoAd(
      // Chamado quando o anúncio é fechado pelo usuário.
      onAdHidden: () {
        print('Start.io Helper: onAdHidden - Anúncio fechado.');

        // Descarta o anúncio antigo, pois ele só pode ser exibido uma vez.
        _rewardedAd?.dispose();
        _rewardedAd = null;

        // Começa a carregar o próximo anúncio para a futura solicitação.
        _loadRewardedVideo();
      },
      // Chamado quando o vídeo termina de ser assistido.
      // É aqui que a recompensa é concedida.
      onVideoCompleted: () {
        print(
            'Start.io Helper: onVideoCompleted - Vídeo completado. Concedendo recompensa...');

        // Aciona o callback que foi passado pelo middleware
        _onUserEarnedReward?.call();
      },
      // Chamado se o anúncio carregado não puder ser exibido por algum motivo.
      onAdNotDisplayed: () {
        print('Start.io Helper: onAdNotDisplayed - Anúncio não foi exibido.');
        _rewardedAd?.dispose();
        _rewardedAd = null;
        _onAdFailedToShow?.call(); // Notifica a falha

        // Tenta carregar um novo anúncio.
        _loadRewardedVideo();
      },
    ).then((ad) {
      // Quando o carregamento é bem-sucedido, armazena a instância do anúncio.
      print('Start.io Helper: Anúncio recompensado carregado com sucesso.');
      _rewardedAd = ad;
      _isLoading = false;
    }).catchError((error) {
      // Se ocorrer um erro durante o carregamento.
      print('Start.io Helper: Erro ao carregar anúncio recompensado: $error');
      _rewardedAd = null;
      _isLoading = false;
    });
  }

  // Função chamada pelo middleware para exibir o anúncio.
  void showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required VoidCallback onAdFailedToShow,
  }) {
    print('Start.io Helper: Tentando exibir anúncio recompensado...');

    // Armazena os callbacks para que os listeners globais possam chamá-los.
    _onUserEarnedReward = onUserEarnedReward;
    _onAdFailedToShow = onAdFailedToShow;

    if (_rewardedAd != null) {
      // Se temos um anúncio carregado, tenta exibi-lo.
      _rewardedAd!.show().then((shown) {
        if (shown) {
          print('Start.io Helper: Comando show() executado com sucesso.');
          // A lógica de recompensa e fechamento será tratada pelos callbacks
          // definidos em _loadRewardedVideo (onVideoCompleted e onAdHidden).
        } else {
          print(
              'Start.io Helper: Comando show() retornou false. Anúncio não exibido.');
          _onAdFailedToShow?.call();
        }
      }).catchError((error) {
        print('Start.io Helper: Erro ao chamar show(): $error');
        _onAdFailedToShow?.call();
      });
    } else {
      // Se não há anúncio pronto.
      print(
          'Start.io Helper: Nenhum anúncio recompensado pronto. Chamando onAdFailedToShow.');
      _onAdFailedToShow?.call();

      // Se não estivermos já carregando um, iniciamos o processo.
      if (!_isLoading) {
        _loadRewardedVideo();
      }
    }
  }

  // --- Lógica para Banners (se você for usar) ---
  // Widget getBannerAd() {
  //   // A documentação mostra que o banner é um widget que pode ser
  //   // adicionado diretamente na árvore de widgets.
  //   return StartAppBanner(
  //       // Você pode querer adicionar um listener para rastrear eventos.
  //       // listener: (event) => print("Evento do Banner: $event"),
  //       );
  // }

  // Libera recursos se necessário (a documentação menciona para Intersticiais)
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
