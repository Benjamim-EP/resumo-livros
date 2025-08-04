// lib/services/payment_service.dart

// 1. A Interface (o "Contrato")
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

abstract class IPaymentService {
  /// Inicia o fluxo de compra para um produto específico (assinatura).
  Future<void> initiatePurchase(String productId);

  /// Tenta restaurar compras anteriores.
  Future<void> restorePurchases();
}

// 2. Implementação Falsa/Vazia (para a versão da Play Store por enquanto)
//    Isso nos permite compilar a versão da Play Store sem ter a lógica do Google ainda.
class GooglePlayPaymentService implements IPaymentService {
  final InAppPurchase _iapConnection = InAppPurchase.instance;

  @override
  Future<void> initiatePurchase(String productId) async {
    print(
        "GooglePlayPaymentService: Iniciando fluxo de compra real para $productId");

    // 1. Verifica se a loja está disponível
    final bool isAvailable = await _iapConnection.isAvailable();
    if (!isAvailable) {
      throw Exception(
          'A loja de aplicativos (Google Play) não está disponível.');
    }

    // 2. Busca os detalhes do produto na loja para garantir que ele existe
    final ProductDetailsResponse productDetailResponse =
        await _iapConnection.queryProductDetails({productId});

    if (productDetailResponse.error != null) {
      throw Exception(
          'Erro ao buscar detalhes do produto: ${productDetailResponse.error!.message}');
    }

    if (productDetailResponse.productDetails.isEmpty) {
      throw Exception(
          'Produto "$productId" não encontrado na Google Play Store. Verifique o ID e o status no console.');
    }

    // 3. Inicia o fluxo de compra
    final ProductDetails productDetails =
        productDetailResponse.productDetails.first;
    final PurchaseParam purchaseParam =
        PurchaseParam(productDetails: productDetails);

    // O resultado desta chamada (sucesso, falha, cancelamento) será capturado
    // pelo listener `purchaseStream` que já configuramos no seu `payment_middleware.dart`.
    // Por isso, não precisamos de um `await` aqui.
    _iapConnection.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() async {
    print("GooglePlayPaymentService: Iniciando restauração de compras...");
    final bool isAvailable = await _iapConnection.isAvailable();
    if (!isAvailable) {
      throw Exception(
          'A loja de aplicativos (Google Play) não está disponível para restaurar compras.');
    }
    // A restauração também envia os resultados para o `purchaseStream` no middleware.
    await _iapConnection.restorePurchases();
  }
}

// 3. Implementação da Stripe (para a versão do site)
class StripePaymentService implements IPaymentService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  @override
  Future<void> initiatePurchase(String priceId) async {
    // Usamos o navigatorKey para ter acesso ao BuildContext global
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      throw Exception(
          "Contexto de navegação inválido para iniciar o pagamento.");
    }

    try {
      // 1. Chamar a Cloud Function para criar a sessão de pagamento segura
      print(
          "StripePaymentService: Chamando a Cloud Function 'createStripeCheckoutSession' com priceId: $priceId");
      final HttpsCallable callable =
          _functions.httpsCallable('createStripeCheckoutSession');
      final response =
          await callable.call<Map<String, dynamic>>({'priceId': priceId});

      final clientSecret = response.data['clientSecret'] as String?;
      final customerId = response.data['customerId'] as String?;

      if (clientSecret == null || customerId == null) {
        throw Exception(
            "Resposta do servidor inválida. clientSecret ou customerId nulos.");
      }
      print(
          "StripePaymentService: clientSecret recebido. Inicializando o Payment Sheet...");

      // 2. Inicializar o Payment Sheet da Stripe com os dados recebidos do backend
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Septima Bíblia',
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          // A Stripe gerencia os métodos de pagamento (Cartão, PIX, etc.) automaticamente aqui
        ),
      );

      print(
          "StripePaymentService: Payment Sheet inicializado. Apresentando ao usuário...");

      // 3. Apresentar a folha de pagamento para o usuário
      await Stripe.instance.presentPaymentSheet();

      print(
          "StripePaymentService: Fluxo do Payment Sheet concluído com sucesso pelo usuário.");

      // 4. Feedback para o usuário
      // O webhook cuidará da ativação da assinatura. O app pode mostrar uma mensagem de "Processando...".
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pagamento recebido! Atualizando sua assinatura...')),
      );
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(FinalizePurchaseAttemptAction());
    } on StripeException catch (e) {
      // Erros específicos da Stripe (ex: cartão recusado, cancelado pelo usuário)
      print("StripePaymentService: Erro da Stripe: ${e.error.message}");
      // Se o usuário simplesmente fechou a tela, não mostre um erro feio.
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.error.message ?? 'Ocorreu um erro no pagamento.')),
        );
      }
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(FinalizePurchaseAttemptAction());
      // Relança o erro para que o middleware possa atualizar o estado (parar o loading)
      rethrow;
    } catch (e) {
      // Outros erros (ex: Cloud Function falhou, erro de rede)
      print("StripePaymentService: Erro inesperado: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ocorreu um erro inesperado. Tente novamente.')),
      );
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(FinalizePurchaseAttemptAction());
      rethrow; // Relança o erro
    }
  }

  @override
  Future<void> restorePurchases() async {
    print(
        "StripePaymentService: 'Restaurar' não é aplicável. O status da assinatura é verificado no login através do Firestore.");
    return;
  }
}
