// lib/pages/start_screen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Importar ações
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

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
                  onPressed: () {
                    final store =
                        StoreProvider.of<AppState>(context, listen: false);
                    store.dispatch(UserEnteredGuestModeAction());

                    // ***** ALTERAÇÃO AQUI *****
                    // Supondo que a aba da Bíblia na MainAppScreen é o índice 1.
                    // Verifique lib/components/bottomNavigationBar/bottomNavigationBar.dart
                    // para o índice correto da BiblePage.
                    // _pages = [ UserPage (0), BiblePage (1), LibraryPage (2), Chat (3) ]
                    // Então, o índice para a Bíblia é 1.
                    store.dispatch(RequestBottomNavChangeAction(
                        1)); // <<< ÍNDICE DA BÍBLIA

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
