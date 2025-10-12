// lib/pages/start_screen_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Importar ações
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:shared_preferences/shared_preferences.dart';
import 'package:septima_biblia/consts.dart'; // <<< IMPORTAR SEU ARQUIVO DE CONSTANTES GLOBAIS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';

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

                    // <<< INÍCIO DA CORREÇÃO >>>
                    try {
                      // 1. FAZ O LOGIN ANÔNIMO PRIMEIRO
                      UserCredential userCredential =
                          await FirebaseAuth.instance.signInAnonymously();
                      print(
                          'Usuário anônimo logado com sucesso: ${userCredential.user?.uid}');

                      // 2. DISPACHA A AÇÃO DE LOGIN NO REDUX (IMPORTANTE!)
                      store.dispatch(UserLoggedInAction(
                        userId: userCredential.user!.uid,
                        email: '', // Anônimo não tem e-mail
                        nome: 'Convidado',
                      ));

                      // 3. AGORA, DISPACHA A AÇÃO DE MODO CONVIDADO
                      // (A lógica de carregar moedas pode ser removida se o backend for cuidar disso para anônimos)
                      store.dispatch(UserEnteredGuestModeAction());

                      // 4. NAVEGA PARA A TELA PRINCIPAL
                      store.dispatch(RequestBottomNavChangeAction(
                          2)); // Navega para Bíblia (índice 2)

                      // Usamos pushAndRemoveUntil para garantir que a tela de start não possa ser acessada voltando
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/mainAppScreen', (route) => false);
                    } on FirebaseAuthException catch (e) {
                      print("Erro ao fazer login anônimo: $e");
                      if (context.mounted) {
                        CustomNotificationService.showError(context,
                            "Não foi possível entrar como convidado. Verifique sua conexão.");
                      }
                    }
                    // <<< FIM DA CORREÇÃO >>>
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
