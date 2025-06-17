// lib/pages/start_screen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Importar ações
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/consts.dart'; // <<< IMPORTAR SEU ARQUIVO DE CONSTANTES GLOBAIS

// Remova a definição local da chave se você a importou de consts.dart
// const String _guestUserCoinsPrefsKeyFromSermonSearch = 'sermon_search_guest_user_coins'; // REMOVER OU COMENTAR

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
                    // Se o usuário escolher logar, a StartScreen será removida da pilha
                    // e a LoginPage será mostrada.
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Login / Cadastrar'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.primary),
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                        theme.textTheme.labelLarge?.copyWith(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final store =
                        StoreProvider.of<AppState>(context, listen: false);

                    int? loadedGuestCoins;
                    int loadedAdsToday = 0;
                    DateTime? loadedLastAdTime;

                    try {
                      final prefs = await SharedPreferences.getInstance();

                      // Carrega moedas salvas para o convidado usando a constante global
                      loadedGuestCoins = prefs.getInt(guestUserCoinsPrefsKey);
                      print(
                          "StartScreenPage: Moedas do convidado lidas do SharedPreferences (Chave: '$guestUserCoinsPrefsKey'): $loadedGuestCoins");

                      // Carrega dados relacionados a anúncios recompensados do convidado
                      // Use chaves diferentes para estes se forem distintos do saldo de moedas gasto em buscas
                      // Por exemplo, defina estas chaves em consts.dart também:
                      // const String guestLastAdTimePrefsKey = 'guest_last_ad_time_reward';
                      // const String guestAdsTodayPrefsKey = 'guest_ads_today_reward';

                      // Se você tem chaves separadas para os dados de anúncios do ad_middleware:
                      // final String? lastAdTimeStringFromAd = prefs.getString(guestLastAdTimePrefsKey); // Usaria a chave do ad_middleware
                      // loadedLastAdTime = lastAdTimeStringFromAd != null ? DateTime.tryParse(lastAdTimeStringFromAd) : null;
                      // final int? guestAdsTodayFromAd = prefs.getInt(guestAdsTodayPrefsKey); // Usaria a chave do ad_middleware

                      // Lógica para resetar adsToday se for um novo dia (se você estiver carregando esses dados)
                      // if (loadedLastAdTime != null) {
                      //     final now = DateTime.now();
                      //     if(now.year > loadedLastAdTime!.year || now.month > loadedLastAdTime!.month || now.day > loadedLastAdTime!.day) {
                      //         loadedAdsToday = 0;
                      //     } else {
                      //         loadedAdsToday = guestAdsTodayFromAd ?? 0;
                      //     }
                      // } else {
                      //    loadedAdsToday = guestAdsTodayFromAd ?? 0;
                      // }
                    } catch (e) {
                      print(
                          "StartScreenPage: Erro ao carregar dados de convidado do SharedPreferences: $e");
                      // Não impede o fluxo, usará os defaults na ação
                    }

                    // Despacha a ação com os dados carregados (ou nulos/padrão se não encontrados/erro)
                    store.dispatch(UserEnteredGuestModeAction(
                      initialCoins:
                          loadedGuestCoins, // Passa as moedas carregadas (pode ser null)
                      initialAdsToday:
                          loadedAdsToday, // Passa o valor (pode ser 0)
                      initialLastAdTime:
                          loadedLastAdTime, // Passa o valor (pode ser null)
                    ));

                    // Solicita a navegação para a aba da Bíblia (índice 1) para convidados
                    store.dispatch(RequestBottomNavChangeAction(1));

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
