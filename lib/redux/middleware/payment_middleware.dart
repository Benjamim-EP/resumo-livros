// lib/redux/middleware/payment_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import '../actions/payment_actions.dart';
import '../store.dart';
import '../../services/stripe_service.dart'; // Serviço Frontend
import '../../main.dart';

// --- DEFINIÇÃO DA GLOBAL KEY ---
// Coloque isso em um arquivo acessível globalmente, como main.dart ou um arquivo de config
// Exemplo: `final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();`
// E importe aqui:
// import 'caminho/para/seu/main_or_config.dart'; // Exemplo
// Por agora, definimos aqui para o código compilar, mas mova para um local apropriado.
//final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// -----------------------------

List<Middleware<AppState>> createPaymentMiddleware() {
  final stripeFrontendService = StripeService.instance;

  return [
    TypedMiddleware<AppState, InitiateStripePaymentAction>(
        _handleInitiatePayment(stripeFrontendService)),
  ];
}

void Function(Store<AppState>, InitiateStripePaymentAction, NextDispatcher)
    _handleInitiatePayment(StripeService stripeFrontendService) {
  return (Store<AppState> store, InitiateStripePaymentAction action,
      NextDispatcher next) async {
    // --- DEBUG PRINT ---
    print(
        '>>> Middleware: _handleInitiatePayment iniciado para priceId: ${action.priceId}, isSubscription: ${action.isSubscription}');
    // --- FIM DEBUG PRINT ---
    next(action); // Passa a ação adiante primeiro

    final BuildContext? context = navigatorKey.currentContext;

    // Obtém dados do usuário DO STORE
    final userId = store.state.userState.userId;
    final email = store.state.userState.email;
    final nome = store.state.userState.nome;

    // --- DEBUG PRINT ---
    print(
        '>>> Middleware: Tentando obter context. navigatorKey.currentContext é: ${context == null ? "nulo" : "não nulo"}');
    print(
        '>>> Middleware: Dados do usuário do store: userId: $userId, email: $email, nome: $nome');
    // --- FIM DEBUG PRINT ---

    if (context == null) {
      print(
          ">>> Middleware: ERRO - BuildContext nulo. Não é possível iniciar o pagamento.");
      store.dispatch(
          StripePaymentFailedAction("Erro interno: Contexto inválido."));
      return;
    }

    if (userId == null || email == null || nome == null) {
      print(
          ">>> Middleware: ERRO - Dados do usuário incompletos no estado Redux.");
      store.dispatch(
          StripePaymentFailedAction("Erro: Informações do usuário ausentes."));
      // Não mostre diálogo daqui, deixe a UI reagir à ação de falha se necessário
      return;
    }

    try {
      // --- DEBUG PRINT ---
      print(
          '>>> Middleware: Chamando stripeFrontendService.initiate${action.isSubscription ? "Subscription" : "Payment"}...');
      // --- FIM DEBUG PRINT ---
      if (action.isSubscription) {
        await stripeFrontendService.initiateSubscription(
            action.priceId, userId, email, nome, context);
      } else {
        await stripeFrontendService.initiatePayment(
            action.priceId, userId, email, nome, context);
      }
      // --- DEBUG PRINT ---
      print(
          '>>> Middleware: Chamada ao stripeFrontendService concluída (sucesso/erro tratado internamente no serviço).');
      // --- FIM DEBUG PRINT ---
    } catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> Middleware: CATCH - Erro ao chamar initiateSubscription/Payment: $e");
      // --- FIM DEBUG PRINT ---
      store.dispatch(StripePaymentFailedAction(
          "Erro ao iniciar ${action.isSubscription ? 'assinatura' : 'pagamento'}: $e"));
      // Não mostre diálogo daqui
    }
  };
}
