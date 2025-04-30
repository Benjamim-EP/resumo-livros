// lib/redux/middleware/payment_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import '../actions/payment_actions.dart';
import '../store.dart';
import '../../services/stripe_service.dart';

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
    next(action);

    final BuildContext? context =
        navigatorKey.currentContext; // Obtém o contexto global

    // --- Obtém dados do usuário DO STORE ---
    final userId = store.state.userState.userId;
    final email = store.state.userState.email;
    final nome = store.state.userState.nome;
    // ---------------------------------------

    if (context == null) {
      print(
          "Erro: BuildContext nulo no payment_middleware. Não é possível iniciar o pagamento.");
      store.dispatch(
          StripePaymentFailedAction("Erro interno: Contexto inválido."));
      return;
    }

    // --- Verifica se os dados do usuário existem ---
    if (userId == null || email == null || nome == null) {
      print("Erro: Dados do usuário incompletos no estado Redux.");
      store.dispatch(
          StripePaymentFailedAction("Erro: Informações do usuário ausentes."));
      // Mostra o erro usando o contexto obtido, SE o serviço tiver um método público para isso
      // ou deixa a UI reagir à ação StripePaymentFailedAction.
      // Exemplo (tornando público): stripeFrontendService.showErrorDialog(context, "Erro: Informações do usuário ausentes.");
      return;
    }
    // -----------------------------------------

    try {
      if (action.isSubscription) {
        // --- Passa os dados do usuário para o serviço ---
        await stripeFrontendService.initiateSubscription(
            action.priceId, userId, email, nome, context);
      } else {
        // --- Passa os dados do usuário para o serviço ---
        await stripeFrontendService.initiatePayment(
            action.priceId, userId, email, nome, context);
      }
    } catch (e) {
      print("Erro ao iniciar pagamento/assinatura no middleware: $e");
      store
          .dispatch(StripePaymentFailedAction("Erro ao iniciar pagamento: $e"));
      // REMOVIDO: Chamada direta ao método privado _showErrorDialog daqui
      // A UI deve observar StripePaymentFailedAction se precisar mostrar algo específico
    }
  };
}

// Defina ou importe sua GlobalKey<NavigatorState>
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
