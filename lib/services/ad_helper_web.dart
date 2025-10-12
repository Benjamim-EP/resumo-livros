// lib/services/ad_helper_web.dart

// Importamos a classe base do AdMob para simular os mesmos métodos,
// mas não usaremos nenhuma funcionalidade real dela.
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Callback para quando o usuário ganha a recompensa
typedef OnUserEarnedRewardCallback = void Function(RewardItem reward);

// Esta classe tem os mesmos nomes de métodos que AdHelperAdMob,
// mas todas as funções são vazias.
class AdHelperWeb {
  void loadRewardedAd({
    required Function onAdLoaded,
    required Function onAdFailedToLoad,
  }) {
    print("AdHelperWeb: loadRewardedAd chamado, mas não faz nada na web.");
    onAdFailedToLoad();
  }

  Future<void> showRewardedAd({
    required OnUserEarnedRewardCallback onUserEarnedReward,
    required Function onAdFailedToShow,
  }) async {
    print("AdHelperWeb: showRewardedAd chamado, mas não faz nada na web.");
    onAdFailedToShow();
  }

  void loadInterstitialAd() {
    print("AdHelperWeb: loadInterstitialAd chamado, mas não faz nada na web.");
  }

  Future<void> showInterstitialAd() async {
    print("AdHelperWeb: showInterstitialAd chamado, mas não faz nada na web.");
  }
}
