// lib/services/payment_service.dart

// 1. A Interface (o "Contrato")
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:septima_biblia/main.dart';

abstract class IPaymentService {
  /// Inicia o fluxo de compra para um produto específico (assinatura).
  Future<void> initiatePurchase(String productId);

  /// Tenta restaurar compras anteriores.
  Future<void> restorePurchases();
}

// 2. Implementação Falsa/Vazia (para a versão da Play Store por enquanto)
//    Isso nos permite compilar a versão da Play Store sem ter a lógica do Google ainda.
class GooglePlayPaymentService implements IPaymentService {
  @override
  Future<void> initiatePurchase(String productId) async {
    // A lógica real do Google Play Billing virá aqui no futuro.
    print(
        "GooglePlayPaymentService: Compra iniciada para $productId (ainda não implementado).");
    // Lançar um erro ou mostrar um aviso pode ser útil.
    throw UnimplementedError(
        'Google Play Billing não está configurado para este build.');
  }

  @override
  Future<void> restorePurchases() async {
    print(
        "GooglePlayPaymentService: Restaurando compras (ainda não implementado).");
    throw UnimplementedError(
        'Restauração do Google Play Billing não está configurada.');
  }
}

// 3. Implementação da Stripe (para a versão do site)
class StripePaymentService implements IPaymentService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  @override
  Future<void> initiatePurchase(String priceId) async {
    final BuildContext? context = navigatorKey.currentContext;
    if (context == null) {
      throw Exception("Contexto de navegação inválido.");
    }

    try {
      // 1. Chamar a Cloud Function para criar a sessão de pagamento
      print(
          "StripePaymentService: Chamando a Cloud Function 'createStripeCheckoutSession'...");
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

      // 2. Inicializar o Payment Sheet da Stripe no app
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Septima Bíblia',
          paymentIntentClientSecret: clientSecret,
          customerId: customerId,
          // Para PIX e outros, o ideal é que a Stripe gerencie isso automaticamente
          // mas você pode configurar mais opções aqui se necessário.
        ),
      );

      print(
          "StripePaymentService: Payment Sheet inicializado. Apresentando ao usuário...");

      // 3. Apresentar a folha de pagamento para o usuário
      await Stripe.instance.presentPaymentSheet();

      print(
          "StripePaymentService: Fluxo do Payment Sheet concluído com sucesso pelo usuário.");
      // O webhook cuidará da ativação da assinatura. O app pode mostrar uma mensagem de "Processando...".
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
      rethrow; // Relança para o middleware saber que falhou.
    } catch (e) {
      // Outros erros (ex: Cloud Function falhou, erro de rede)
      print("StripePaymentService: Erro inesperado: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ocorreu um erro inesperado. Tente novamente.')),
      );
      rethrow; // Relança para o middleware saber que falhou.
    }
  }

  @override
  Future<void> restorePurchases() async {
    print(
        "StripePaymentService: 'Restaurar' não é aplicável. O status da assinatura é verificado no login através do Firestore.");
    // Opcional: Você pode forçar uma recarga dos dados do usuário aqui
    // StoreProvider.of<AppState>(navigatorKey.currentContext!, listen: false).dispatch(LoadUserDetailsAction());
    return;
  }
}
