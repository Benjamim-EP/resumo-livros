// lib/services/interstitial_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
// <<< 1. MUDE O IMPORT AQUI >>>
import 'package:septima_biblia/services/ad_helper_admob.dart'; // Importe o helper do AdMob

class InterstitialManager {
  static const _lastInterstitialShownKey = 'last_interstitial_shown_timestamp';
  static const _interstitialCooldown = Duration(minutes: 7);

  // <<< 2. MUDE O TIPO DA VARIÁVEL AQUI >>>
  final AdHelperAdMob _adHelper;

  InterstitialManager(this._adHelper) {
    // Pré-carrega o primeiro anúncio intersticial na inicialização
    _adHelper.loadInterstitialAd();
  }

  Future<bool> _canShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownMillis = prefs.getInt(_lastInterstitialShownKey);
    if (lastShownMillis == null) return true;
    final lastShownTime = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    return DateTime.now().difference(lastShownTime) > _interstitialCooldown;
  }

  Future<void> _recordInterstitialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastInterstitialShownKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> tryShowInterstitial({String? fromScreen}) async {
    if (await _canShowInterstitial()) {
      print(
          "InterstitialManager: Cooldown permite. Tentando mostrar intersticial (AdMob) de: ${fromScreen ?? 'desconhecido'}.");

      // A chamada para `showInterstitialAd` já está correta, pois o método tem o mesmo nome
      await _adHelper.showInterstitialAd();

      // A lógica de gravar o timestamp também está correta
      await _recordInterstitialShown();
    } else {
      print(
          "InterstitialManager: Cooldown do intersticial ainda ativo (chamado de: ${fromScreen ?? 'desconhecido'}).");
    }
  }
}

// <<< 3. ATUALIZE A INSTÂNCIA GLOBAL AQUI >>>
final InterstitialManager interstitialManager =
    InterstitialManager(AdHelperAdMob());
