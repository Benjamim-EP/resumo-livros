// lib/services/interstitial_manager.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/services/AdHelperStartIo.dart'; // Seu helper

class InterstitialManager {
  static const _lastInterstitialShownKey = 'last_interstitial_shown_timestamp';
  // Escolha um cooldown que faça sentido para você, ex: 3 a 5 minutos
  static const _interstitialCooldown = Duration(minutes: 7);

  final AdHelperStartIo _adHelper;

  InterstitialManager(this._adHelper);

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
          "InterstitialManager: Cooldown permite. Tentando mostrar intersticial (AdMob) de '$fromScreen'.");
      await _adHelper.showInterstitialAd();
      // O AdHelper já cuida de recarregar, então só precisamos registrar que foi mostrado.
      await _recordInterstitialShown();
    } else {
      print(
          "InterstitialManager: Cooldown do intersticial ainda ativo para '$fromScreen'.");
    }
  }
}

// Instância global
final InterstitialManager interstitialManager =
    InterstitialManager(AdHelperStartIo());
