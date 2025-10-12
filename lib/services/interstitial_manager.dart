// lib/services/interstitial_manager.dart
import 'package:flutter/foundation.dart';
import 'package:septima_biblia/services/ad_helper_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/services/ad_helper_admob.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class InterstitialManager {
  // --- CHAVES E CONSTANTES ---
  static const _lastInterstitialShownKey = 'last_interstitial_shown_timestamp';

  // Cooldown curto para o PRIMEIRO anúncio da sessão
  static const _initialCooldown = Duration(minutes: 3);

  // Cooldown longo para os anúncios SUBSEQUENTES
  static const _subsequentCooldown = Duration(minutes: 7);

  // --- ESTADO INTERNO ---
  final dynamic _adHelper;

  // ✅ 1. NOVA VARIÁVEL DE ESTADO
  // Esta variável "lembra" se um anúncio já foi exibido nesta sessão.
  // Sendo estática, ela persiste enquanto o app estiver em memória.
  static bool _hasShownAdThisSession = false;

  InterstitialManager(this._adHelper) {
    _adHelper.loadInterstitialAd();
  }

  // ✅ 2. LÓGICA DE COOLDOWN DINÂMICO
  Future<bool> _canShowInterstitial() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownMillis = prefs.getInt(_lastInterstitialShownKey);

    // Se nunca mostrou um anúncio antes (primeira vez que o app é usado), pode mostrar.
    if (lastShownMillis == null) {
      return true;
    }

    final lastShownTime = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    final timeSinceLastAd = DateTime.now().difference(lastShownTime);

    // A MÁGICA ACONTECE AQUI:
    // Se um anúncio já foi exibido nesta sessão, usamos o cooldown longo.
    // Caso contrário, usamos o cooldown curto.
    if (_hasShownAdThisSession) {
      print("InterstitialManager: Verificando com cooldown LONGO (7 min)...");
      return timeSinceLastAd > _subsequentCooldown;
    } else {
      print("InterstitialManager: Verificando com cooldown CURTO (3 min)...");
      return timeSinceLastAd > _initialCooldown;
    }
  }

  Future<void> _recordInterstitialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _lastInterstitialShownKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> tryShowInterstitial({String? fromScreen}) async {
    if (kIsWeb) {
      print("InterstitialManager: Anúncios pulados (Plataforma Web).");
      return;
    }
    if (await _canShowInterstitial()) {
      print(
          "InterstitialManager: Cooldown permite. Tentando mostrar anúncio...");

      // A chamada ao helper permanece a mesma
      await _adHelper.showInterstitialAd();

      // Grava o timestamp da exibição
      await _recordInterstitialShown();

      // ✅ 3. ATUALIZA O ESTADO DA SESSÃO
      // Marca que um anúncio já foi exibido nesta sessão.
      // A partir de agora, a função _canShowInterstitial usará o cooldown de 7 minutos.
      _hasShownAdThisSession = true;
      print(
          "InterstitialManager: Anúncio exibido. Próximo cooldown será de 7 minutos.");
    } else {
      print("InterstitialManager: Cooldown do intersticial ainda ativo.");
    }
  }
}

// A instância global permanece a mesma
final InterstitialManager interstitialManager =
    InterstitialManager(kIsWeb ? AdHelperWeb() : AdHelperAdMob());
