// lib/redux/middleware/backend_validation_middleware.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart'; // Para o navigatorKey
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/store.dart';

List<Middleware<AppState>> createBackendValidationMiddleware() {
  // Instancia a referência para o Firebase Functions na região correta
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Handler que intercepta a ação após a compra ser verificada no cliente
  void handleGooglePlayPurchaseVerified(
    Store<AppState> store,
    GooglePlayPurchaseVerifiedAction action,
    NextDispatcher next,
  ) async {
    next(
        action); // Passa a ação para o reducer, que deve marcar o status como "pendingValidation"

    final purchaseDetails = action.purchaseDetails;
    print(
        "BackendValidationMiddleware: Interceptou GooglePlayPurchaseVerifiedAction.");
    print(
        "BackendValidationMiddleware: Enviando dados para validação no backend...");

    try {
      // Prepara a chamada para a Cloud Function
      final HttpsCallable callable =
          functions.httpsCallable('validate_google_play_purchase');

      // Envia os dados necessários para a validação
      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'productId': purchaseDetails.productID,
        // O serverVerificationData contém o token de compra necessário
        'purchaseToken':
            purchaseDetails.verificationData.serverVerificationData,
      });

      print(
          "BackendValidationMiddleware: Resposta do backend recebida: ${result.data}");

      // Se a validação no backend for bem-sucedida, a própria Cloud Function atualiza o Firestore.
      // O listener do app (em MainAppScreen) irá detectar a mudança e atualizar o status da assinatura na UI.
      // Podemos mostrar uma mensagem de sucesso aqui para o usuário.
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assinatura ativada com sucesso!')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print(
          "BackendValidationMiddleware: Erro FirebaseFunctionsException ao chamar backend: ${e.code} - ${e.message}");
      // Despacha uma ação de falha para a UI poder reagir (ex: mostrar mensagem de erro)
      store.dispatch(GooglePlayPaymentFailedAction(
          e.message ?? "Falha na comunicação com o servidor."));
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao validar assinatura: ${e.message}')),
        );
      }
    } catch (e) {
      print(
          "BackendValidationMiddleware: Erro inesperado ao chamar backend: $e");
      store.dispatch(
          GooglePlayPaymentFailedAction("Ocorreu um erro inesperado."));
    }
  }

  return [
    TypedMiddleware<AppState, GooglePlayPurchaseVerifiedAction>(
        handleGooglePlayPurchaseVerified),
  ];
}
