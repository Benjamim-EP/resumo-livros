// lib/redux/middleware/fake_payment_middleware.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';

// <<< ADICIONE ESTES IMPORTS >>>
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Enum para controlar o cenário da simulação
enum FakePurchaseScenario {
  success,
  failure,
  cancelled,
}

List<Middleware<AppState>> createFakePaymentMiddleware() {
  // Handler que intercepta a ação de iniciar a compra
  void _handleInitiateGooglePlaySubscription(
    Store<AppState> store,
    InitiateGooglePlaySubscriptionAction action,
    NextDispatcher next,
  ) async {
    next(action);

    final BuildContext? context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    // ----- SIMULAÇÃO DA UI DA GOOGLE PLAY -----
    final scenario = await showDialog<FakePurchaseScenario>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Simulador de Compra"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Você está tentando comprar: ${action.productId}"),
            const SizedBox(height: 20),
            const Text("Escolha o resultado da simulação:"),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("SUCESSO", style: TextStyle(color: Colors.green)),
            onPressed: () =>
                Navigator.of(dialogContext).pop(FakePurchaseScenario.success),
          ),
          TextButton(
            child: const Text("FALHA", style: TextStyle(color: Colors.red)),
            onPressed: () =>
                Navigator.of(dialogContext).pop(FakePurchaseScenario.failure),
          ),
          TextButton(
            child: const Text("CANCELAR"),
            onPressed: () =>
                Navigator.of(dialogContext).pop(FakePurchaseScenario.cancelled),
          ),
        ],
      ),
    );

    if (scenario == null) {
      store.dispatch(GooglePlayPurchaseErrorAction(
          error: "Compra cancelada.", productId: action.productId));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Validando..."),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    // ----- PROCESSAMENTO DO CENÁRIO ESCOLHIDO -----
    switch (scenario) {
      case FakePurchaseScenario.success:
        print("SIMULAÇÃO: Compra bem-sucedida.");

        // >>>>> INÍCIO DA MODIFICAÇÃO <<<<<
        // Simula a escrita no Firestore que a Cloud Function faria.
        final firestoreService = FirestoreService();
        final userId = store.state.userState.userId;
        final expirationDate = DateTime.now().add(const Duration(minutes: 2));

        if (userId != null) {
          try {
            await firestoreService.updateUserSubscriptionStatus(
              userId: userId,
              status: 'active',
              customerId: 'simulated_customer_123', // Valor de teste
              subscriptionId: 'simulated_sub_123', // Valor de teste
              endDate: Timestamp.fromDate(expirationDate),
              priceId: action.productId,
            );
            print("SIMULAÇÃO: Firestore atualizado para o usuário $userId.");
          } catch (e) {
            print("SIMULAÇÃO: Erro ao atualizar Firestore no modo fake: $e");
          }
        }
        // >>>>> FIM DA MODIFICAÇÃO <<<<<

        // Despacha a ação para o Redux (para atualizar a UI imediatamente)
        store.dispatch(SubscriptionStatusUpdatedAction(
          status: 'active',
          endDate: expirationDate,
          priceId: action.productId,
        ));

        // Feedback de sucesso e navegação
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assinatura ativada com sucesso!')),
          );
          Navigator.of(context).pop();
        }
        break;

      case FakePurchaseScenario.failure:
        // ... (código de falha e cancelamento permanecem iguais) ...
        print("SIMULAÇÃO: Falha na compra.");
        store.dispatch(GooglePlayPaymentFailedAction(
            "Erro simulado da loja. Tente novamente mais tarde."));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ocorreu um erro ao processar a compra.')),
          );
        }
        break;
      case FakePurchaseScenario.cancelled:
        print("SIMULAÇÃO: Compra cancelada pelo usuário.");
        store.dispatch(GooglePlayPurchaseErrorAction(
            error: "Compra cancelada pelo usuário.",
            productId: action.productId));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compra cancelada.')),
          );
        }
        break;
    }
  }

  return [
    TypedMiddleware<AppState, InitiateGooglePlaySubscriptionAction>(
      _handleInitiateGooglePlaySubscription,
    ),
  ];
}
