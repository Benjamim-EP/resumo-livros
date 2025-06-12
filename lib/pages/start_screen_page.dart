// lib/pages/start_screen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Importar ações
import 'package:septima_biblia/redux/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
                    store.dispatch(UserEnteredGuestModeAction());

                    // >>> INÍCIO DA MUDANÇA: Carrega dados do convidado <<<
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      // As chaves precisam ser as mesmas definidas no ad_middleware.dart
                      final int? guestCoins = prefs.getInt('guest_user_coins');
                      final int? guestAdsToday =
                          prefs.getInt('guest_ads_today');
                      final String? lastAdTimeString =
                          prefs.getString('guest_last_ad_time');
                      final DateTime? guestLastAdTime = lastAdTimeString != null
                          ? DateTime.tryParse(lastAdTimeString)
                          : null;

                      // Reseta o contador diário se for um novo dia
                      int finalAdsToday = guestAdsToday ?? 0;
                      if (guestLastAdTime != null) {
                        final now = DateTime.now();
                        if (now.year > guestLastAdTime.year ||
                            now.month > guestLastAdTime.month ||
                            now.day > guestLastAdTime.day) {
                          finalAdsToday = 0;
                        }
                      }

                      // Despacha a ação com os dados carregados (ou nulos se não existirem)
                      store.dispatch(UserEnteredGuestModeAction(
                        initialCoins: guestCoins,
                        initialAdsToday: finalAdsToday,
                        initialLastAdTime: guestLastAdTime,
                      ));
                    } catch (e) {
                      print("Erro ao carregar dados de convidado: $e");
                      // Em caso de erro, despacha a ação padrão sem dados iniciais
                      store.dispatch(UserEnteredGuestModeAction());
                    }
                    // >>> FIM DA MUDANÇA <<<

                    Navigator.pushNamedAndRemoveUntil(
                        context, '/mainAppScreen', (route) => false);
                  },
                  child: const Text('Continuar como Convidado'),
                ),
                // ...
              ],
            ),
          ),
        ),
      ),
    );
  }
}
