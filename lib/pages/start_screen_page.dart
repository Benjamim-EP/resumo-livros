// lib/pages/start_screen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Importar ações
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _guestUserCoinsPrefsKeyFromSermonSearch =
    'sermon_search_guest_user_coins';

class StartScreenPage extends StatelessWidget {
  const StartScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Bem-vindo ao Septima',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Explore um universo de conhecimento teológico e aprofunde sua fé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                        theme.textTheme.labelLarge?.copyWith(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Login / Cadastrar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(/* ... */),
                  onPressed: () async {
                    final store =
                        StoreProvider.of<AppState>(context, listen: false);

                    try {
                      final prefs = await SharedPreferences.getInstance();

                      // Carrega moedas salvas para o convidado usando a chave correta
                      final int? guestCoins =
                          prefs.getInt(_guestUserCoinsPrefsKeyFromSermonSearch);
                      // A lógica para guestAdsToday e guestLastAdTime do ad_middleware pode permanecer
                      // se você quiser que os limites de anúncios recompensados sejam separados
                      // das moedas gastas em buscas. Se não, precisaria de chaves separadas para eles também.

                      // Para simplificar, vamos focar apenas nas moedas agora.
                      // A lógica de resetar adsToday do ad_middleware pode ser mantida.
                      int finalAdsToday =
                          0; // Resetar se for o caso, ou carregar
                      DateTime? finalLastAdTime; // Carregar se for o caso
                      // Exemplo de como você carregaria os outros dados de anúncio do convidado (do ad_middleware):
                      // final int? guestAdsTodayFromAd = prefs.getInt('guest_ads_today'); // Use a chave do ad_middleware
                      // final String? lastAdTimeStringFromAd = prefs.getString('guest_last_ad_time'); // Use a chave do ad_middleware
                      // final DateTime? guestLastAdTimeFromAd = lastAdTimeStringFromAd != null ? DateTime.tryParse(lastAdTimeStringFromAd) : null;
                      // if (guestLastAdTimeFromAd != null) {
                      //     final now = DateTime.now();
                      //     if(now.year > guestLastAdTimeFromAd.year || now.month > guestLastAdTimeFromAd.month || now.day > guestLastAdTimeFromAd.day) {
                      //         finalAdsToday = 0;
                      //     } else {
                      //         finalAdsToday = guestAdsTodayFromAd ?? 0;
                      //     }
                      //     finalLastAdTime = guestLastAdTimeFromAd;
                      // }

                      store.dispatch(UserEnteredGuestModeAction(
                        initialCoins: guestCoins, // Passa as moedas carregadas
                        // initialAdsToday: finalAdsToday,         // Opcional: se quiser carregar do ad_middleware
                        // initialLastAdTime: finalLastAdTime,       // Opcional: se quiser carregar do ad_middleware
                      ));
                    } catch (e) {
                      print("Erro ao carregar dados de convidado: $e");
                      store.dispatch(UserEnteredGuestModeAction());
                    }

                    Navigator.pushNamedAndRemoveUntil(
                        context, '/mainAppScreen', (route) => false);
                  },
                  child: const Text('Continuar como Convidado'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
