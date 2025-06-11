// Em algum arquivo de utils ou helpers
import 'package:flutter/material.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

void showLoginRequiredDialog(BuildContext context,
    {String featureName = "esta funcionalidade"}) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("Login Necessário"),
      content: Text(
          "Para acessar $featureName, por favor, faça login ou crie uma conta."),
      actions: [
        TextButton(
          child: const Text("Cancelar"),
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
        TextButton(
          child: const Text("Login / Cadastro"),
          onPressed: () {
            Navigator.of(dialogContext).pop(); // Fecha o diálogo
            // Navega para a tela de login, limpando o estado de convidado
            StoreProvider.of<AppState>(context, listen: false)
                .dispatch(UserExitedGuestModeAction());
            // AuthCheck cuidará de mostrar LoginPage agora
            // Se você tiver rotas nomeadas e uma forma de resetar a pilha até AuthCheck:
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
            // Ou se LoginPage for a raiz após StartScreen:
            // Navigator.of(context).pushNamedAndRemoveUntil('/login', ModalRoute.withName('/'));
          },
        ),
      ],
    ),
  );
}
