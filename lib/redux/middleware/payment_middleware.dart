// lib/redux/middleware/payment_middleware.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // Alterado aqui
import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/store.dart';

List<Middleware<AppState>> createPaymentMiddleware() {
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
    InAppPurchase connection, // <<< TIPO CORRIGIDO AQUI
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print(
          "PaymentMiddleware: Atualização de Compra Recebida - ID: ${purchaseDetails.purchaseID}, Produto: ${purchaseDetails.productID}, Status: ${purchaseDetails.status}, Erro: ${purchaseDetails.error}");

      if (purchaseDetails.status == PurchaseStatus.pending) {
        print(
            "PaymentMiddleware: Compra pendente para ${purchaseDetails.productID}. Aguardando finalização.");
        // UI pode mostrar um indicador de pendência
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          print(
              "PaymentMiddleware: Erro na compra: ${purchaseDetails.error?.message}");
          store.dispatch(GooglePlayPurchaseErrorAction(
              error: purchaseDetails.error?.message ??
                  "Erro desconhecido na compra.",
              productId: purchaseDetails.productID));
          _showErrorDialog(purchaseDetails.error?.message ??
              "Ocorreu um erro durante a compra.");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          print(
              "PaymentMiddleware: Compra ${purchaseDetails.status == PurchaseStatus.purchased ? 'bem-sucedida' : 'restaurada'} para ${purchaseDetails.productID}.");

          store.dispatch(GooglePlayPurchaseVerifiedAction(
              purchaseDetails: purchaseDetails));
          print(
              "PaymentMiddleware: GooglePlayPurchaseVerifiedAction despachada para validação no backend.");

          if (purchaseDetails.pendingCompletePurchase) {
            await connection
                .completePurchase(purchaseDetails); // <<< USA A CONEXÃO CORRETA
            print(
                "PaymentMiddleware: Compra finalizada (completePurchase) para ${purchaseDetails.productID}.");
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          print(
              "PaymentMiddleware: Compra cancelada para ${purchaseDetails.productID}.");
          store.dispatch(GooglePlayPurchaseErrorAction(
              error: "Compra cancelada pelo usuário.",
              productId: purchaseDetails.productID));
          _showInfoDialog("Compra cancelada.");
        }
      }
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
    next(action);
    _listenToPurchaseUpdated(store);

    final bool available = await iapConnection.isAvailable();
    if (!available) {
      print("PaymentMiddleware: Serviço de compra não disponível.");
      // <<< CORREÇÃO AQUI >>>
      store.dispatch(
          GooglePlayPaymentFailedAction("Serviço de compra não disponível."));
      _showErrorDialog(
          "Serviço de compra não disponível. Verifique sua conexão com a Play Store.");
      return;
    }

    final Set<String> kProductIds = {action.productId};

    try {
      print(
          "PaymentMiddleware: Consultando detalhes do produto: ${action.productId}");
      final ProductDetailsResponse productDetailResponse =
          await iapConnection.queryProductDetails(kProductIds);

      if (productDetailResponse.error != null) {
        print(
            "PaymentMiddleware: Erro ao consultar detalhes do produto: ${productDetailResponse.error!.message}");
        // <<< CORREÇÃO AQUI >>>
        store.dispatch(GooglePlayPaymentFailedAction(
            "Erro ao buscar produto: ${productDetailResponse.error!.message}"));
        _showErrorDialog(
            "Erro ao buscar detalhes do plano: ${productDetailResponse.error!.message}.");
        return;
      }

      if (productDetailResponse.productDetails.isEmpty) {
        print("PaymentMiddleware: Produto não encontrado: ${action.productId}");
        // <<< CORREÇÃO AQUI >>>
        store.dispatch(GooglePlayPaymentFailedAction(
            "Plano de assinatura não encontrado."));
        _showErrorDialog(
            "Plano de assinatura não encontrado. Por favor, tente mais tarde.");
        return;
      }

      final ProductDetails productDetails =
          productDetailResponse.productDetails.first;
      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: productDetails);

      print(
          "PaymentMiddleware: Iniciando fluxo de compra para: ${productDetails.id}");
      await iapConnection.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print("PaymentMiddleware: Exceção ao iniciar compra: $e");
      // <<< CORREÇÃO AQUI >>>
      store.dispatch(
          GooglePlayPaymentFailedAction("Erro ao iniciar compra: $e"));
      _showErrorDialog(
          "Ocorreu um erro ao tentar iniciar a assinatura. Tente novamente.");
    }
  }

  return [
    TypedMiddleware<AppState, InitiateGooglePlaySubscriptionAction>(
            _handleInitiateGooglePlaySubscription)
        .call,
  ];
}
