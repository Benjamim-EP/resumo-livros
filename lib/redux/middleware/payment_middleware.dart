// lib/redux/middleware/payment_middleware.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // Alterado aqui
import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/payment_service.dart';

List<Middleware<AppState>> createPaymentMiddleware(
    IPaymentService paymentService) {
  final InAppPurchase iapConnection =
      InAppPurchase.instance; // <<< CORREÇÃO AQUI
  StreamSubscription<List<PurchaseDetails>>?
      _purchaseUpdatedSubscription; // Renomeado para clareza

  // Helper para mostrar diálogos (evita problemas de contexto)
  void _showErrorDialog(String message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message), duration: const Duration(seconds: 5)),
          );
        }
      });
    }
  }

  void _showInfoDialog(String message) {
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message), duration: const Duration(seconds: 3)),
          );
        }
      });
    }
  }

  // <<< FUNÇÃO _handlePurchaseUpdates DEFINIDA ANTES DE SER USADA >>>
  // Handler para processar atualizações de compra (do listener)
  void _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
    Store<AppState> store,
    InAppPurchase connection,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print(
          "PaymentMiddleware: Atualização de Compra Recebida - ID: ${purchaseDetails.purchaseID}, Produto: ${purchaseDetails.productID}, Status: ${purchaseDetails.status}, Erro: ${purchaseDetails.error}");

      // >>>>> INÍCIO DA MODIFICAÇÃO PRINCIPAL <<<<<
      if (purchaseDetails.status == PurchaseStatus.pending) {
        print(
            "PaymentMiddleware: Compra pendente para ${purchaseDetails.productID}.");
        // Não finalizamos o loading aqui, pois a compra ainda está em andamento.
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print(
              "PaymentMiddleware: Erro na compra: ${purchaseDetails.error?.message}");
          store.dispatch(GooglePlayPurchaseErrorAction(
              error: purchaseDetails.error?.message ?? "Erro desconhecido.",
              productId: purchaseDetails.productID));
          // FINALIZA A TENTATIVA
          store.dispatch(FinalizePurchaseAttemptAction(
              productId: purchaseDetails.productID));
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          print(
              "PaymentMiddleware: Compra ${purchaseDetails.status == PurchaseStatus.purchased ? 'bem-sucedida' : 'restaurada'}...");

          // Despacha para validação no backend. O backend irá finalizar o loading da UI.
          store.dispatch(GooglePlayPurchaseVerifiedAction(
              purchaseDetails: purchaseDetails));

          // Não despachamos FinalizePurchaseAttemptAction aqui, pois a validação do backend
          // cuidará de fechar os diálogos e resetar o estado.

          if (purchaseDetails.pendingCompletePurchase) {
            await connection.completePurchase(purchaseDetails);
            print("PaymentMiddleware: Compra finalizada (completePurchase).");
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          print(
              "PaymentMiddleware: Compra cancelada para ${purchaseDetails.productID}.");
          store.dispatch(GooglePlayPurchaseErrorAction(
              error: "Compra cancelada pelo usuário.",
              productId: purchaseDetails.productID));
          // FINALIZA A TENTATIVA
          store.dispatch(FinalizePurchaseAttemptAction(
              productId: purchaseDetails.productID));
        }
      }
      // >>>>> FIM DA MODIFICAÇÃO PRINCIPAL <<<<<
    }
  }

  // Função para configurar o listener de compras
  void _listenToPurchaseUpdated(Store<AppState> store) {
    _purchaseUpdatedSubscription?.cancel();
    _purchaseUpdatedSubscription = iapConnection.purchaseStream.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        // <<< AGORA _handlePurchaseUpdates ESTÁ DEFINIDA >>>
        _handlePurchaseUpdates(purchaseDetailsList, store, iapConnection);
      },
      onDone: () {
        _purchaseUpdatedSubscription?.cancel();
        print(
            "PaymentMiddleware: Listener de compras (purchaseStream) finalizado.");
      },
      onError: (error) {
        print(
            "PaymentMiddleware: Erro no listener de compras (purchaseStream): $error");
        store.dispatch(GooglePlayPurchaseErrorAction(
            error: "Erro no stream de compras: $error"));
      },
    );
    print("PaymentMiddleware: Listener de atualizações de compra configurado.");
  }

  // Handler para InitiateGooglePlaySubscriptionAction
  void _handleInitiateGooglePlaySubscription(
    Store<AppState> store,
    InitiateGooglePlaySubscriptionAction action,
    NextDispatcher next,
  ) async {
    // 1. Validação prévia (lógica de negócio que independe do provedor de pagamento)
    if (store.state.userState.isGuestUser) {
      print(
          "PaymentMiddleware: Ação de compra bloqueada. Usuário é um convidado.");
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, faça login para assinar.')),
        );
      }
      return; // Encerra o fluxo
    }

    // 2. Passa a ação para o reducer, que ativará o estado de `isLoading: true`
    next(action);

    // 3. Garante que o listener de compras está ativo
    _listenToPurchaseUpdated(store);

    // 4. Delega a lógica de compra para o serviço de pagamento injetado
    try {
      print(
          "PaymentMiddleware: Delegando compra de '${action.productId}' para o serviço de pagamento...");

      // A chamada agora é simples e abstrata. O `paymentService` pode ser
      // o `GooglePlayPaymentService` ou o `StripePaymentService`.
      await paymentService.initiatePurchase(action.productId);

      print(
          "PaymentMiddleware: O serviço de pagamento iniciou o fluxo com sucesso.");
      // Se a função acima não lançar um erro, significa que o fluxo de compra
      // (ex: a tela do Google Play) foi aberto. O resultado será capturado pelo
      // listener `_listenToPurchaseUpdated`.
    } catch (e) {
      // 5. Se o serviço lançar um erro (ex: produto não encontrado, loja indisponível),
      // o middleware captura, mostra um erro para o usuário e atualiza o estado do Redux.
      print("PaymentMiddleware: Erro recebido do serviço de pagamento: $e");

      store.dispatch(GooglePlayPaymentFailedAction(
          "Erro ao iniciar a compra: ${e.toString()}"));

      // Mostra um erro genérico, pois os detalhes já foram logados.
      _showErrorDialog(
          "Não foi possível iniciar a compra. Verifique sua conexão e tente novamente.");
    }
  }

  return [
    TypedMiddleware<AppState, InitiateGooglePlaySubscriptionAction>(
            _handleInitiateGooglePlaySubscription)
        .call,
  ];
}
