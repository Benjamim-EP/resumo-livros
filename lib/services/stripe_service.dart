// lib/services/stripe_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
// REMOVIDO: import 'package:flutter_redux/flutter_redux.dart'; // <<< REMOVIDO
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // <<< REMOVIDO (LoadUserPremiumStatusAction, etc não são despachados aqui)
import 'package:resumo_dos_deuses_flutter/services/stripe_backend_service.dart';
// REMOVIDO: import 'package:redux/redux.dart'; // <<< REMOVIDO
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // <<< REMOVIDO
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // <<< Mantido se despachar algo, mas provavelmente não necessário aqui
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Para obter o store para despachar ações PÓS webhook (se necessário)
import 'package:flutter_redux/flutter_redux.dart'; // Para obter o store para despachar ações PÓS webhook (se necessário)
import '../redux/actions.dart'; // Para LoadUserPremiumStatusAction, LoadUserDetailsAction

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();
  final StripeBackendService _backendService = StripeBackendService();

  /// Inicia o fluxo de pagamento único usando PaymentSheet.
  /// AGORA RECEBE userDetails como parâmetros.
  Future<void> initiatePayment(
    String priceId,
    String userId, // <<< NOVO PARÂMETRO
    String email, // <<< NOVO PARÂMETRO
    String nome, // <<< NOVO PARÂMETRO
    BuildContext context,
  ) async {
    // REMOVIDO: Obtenção do store e userDetails daqui

    try {
      // 1. (Backend Simulado) Obtém/Cria o Customer no Stripe
      final customerId = await _backendService.getOrCreateCustomer(
          email, nome, userId); // Usa parâmetros
      if (customerId == null) {
        _showErrorDialog(context, "Erro ao configurar cliente de pagamento.");
        return;
      }

      // 2. (Backend Simulado) Cria o PaymentIntent e obtém o client_secret
      final clientSecret =
          await _backendService.createPaymentIntent(priceId, customerId);
      if (clientSecret == null) {
        _showErrorDialog(context, "Erro ao iniciar o pagamento.");
        return;
      }

      // 3. Inicializa o PaymentSheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: "Septima",
          customerId: customerId,
        ),
      );

      // 4. Apresenta o PaymentSheet e processa
      await _presentAndConfirmPayment(context,
          isSubscription: false,
          identifier: clientSecret,
          userId: userId); // Passa userId para recarregar estado
    } catch (e) {
      print("Erro no fluxo de pagamento: $e");
      _showErrorDialog(
          context, "Ocorreu um erro inesperado durante o pagamento.");
    }
  }

  /// Inicia o fluxo de assinatura recorrente usando PaymentSheet.
  /// AGORA RECEBE userDetails como parâmetros.
  Future<void> initiateSubscription(
    String priceId,
    String userId, // <<< NOVO PARÂMETRO
    String email, // <<< NOVO PARÂMETRO
    String nome, // <<< NOVO PARÂMETRO
    BuildContext context,
  ) async {
    // REMOVIDO: Obtenção do store e userDetails daqui

    try {
      // 1. (Backend Simulado) Obtém/Cria o Customer no Stripe
      final customerId = await _backendService.getOrCreateCustomer(
          email, nome, userId); // Usa parâmetros
      if (customerId == null) {
        _showErrorDialog(context, "Erro ao configurar cliente de pagamento.");
        return;
      }

      // 2. (Backend Simulado) Cria a Assinatura e obtém client_secret (se necessário)
      final subscriptionData =
          await _backendService.createSubscription(priceId, customerId);
      if (subscriptionData == null) {
        _showErrorDialog(context, "Erro ao iniciar a assinatura.");
        return;
      }

      final clientSecret = subscriptionData["clientSecret"];
      final subscriptionId = subscriptionData["subscriptionId"];
      final initialStatus = subscriptionData["status"];

      if (clientSecret != null && initialStatus != 'active') {
        // 3. Assinatura requer confirmação de pagamento inicial
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: "Septima",
            customerId: customerId,
          ),
        );

        // 4. Apresenta o PaymentSheet e processa
        await _presentAndConfirmPayment(context,
            isSubscription: true,
            identifier: subscriptionId,
            userId: userId); // Passa userId
      } else if (initialStatus == 'active') {
        print(
            "Assinatura $subscriptionId ativa, sem necessidade de PaymentSheet.");
        _showSuccessDialog(context, "Assinatura ativada com sucesso!");

        // Como o backend simulado já atualizou o Firestore, disparamos ações para
        // o Redux ler os dados atualizados do Firestore.
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(
            LoadUserPremiumStatusAction()); // Ou a ação específica que carrega o status
        store.dispatch(LoadUserDetailsAction()); // Recarrega detalhes gerais
        // store.dispatch(SubscriptionStatusUpdatedAction( // Alternativa: despachar status direto se o backend não puder ser simulado
        //   status: 'active',
        //   subscriptionId: subscriptionId,
        // ));
      } else {
        _showErrorDialog(
            context, "Status inesperado da assinatura após criação.");
      }
    } catch (e) {
      print("Erro no fluxo de assinatura: $e");
      _showErrorDialog(
          context, "Ocorreu um erro inesperado durante a assinatura.");
    }
  }

  /// Apresenta o PaymentSheet e tenta confirmar o pagamento.
  Future<void> _presentAndConfirmPayment(BuildContext context,
      {required bool isSubscription,
      required String identifier,
      required String userId}) async {
    // Recebe userId
    // final store = StoreProvider.of<AppState>(context, listen: false); // Store já não é mais necessário aqui para pegar dados iniciais
    try {
      await Stripe.instance.presentPaymentSheet();
      // await Stripe.instance.confirmPaymentSheetPayment(); // Geralmente não necessário com presentPaymentSheet

      print(
          "Pagamento/Confirmação no frontend concluído. SIMULANDO webhook...");
      if (isSubscription) {
        await _backendService.handleSubscriptionWebhookEvent(
            identifier, 'active', null);
      } else {
        // Extrair paymentIntentId do clientSecret se necessário para o backend real
        // String paymentIntentId = clientSecret.split('_secret').first;
        await _backendService.handlePaymentIntentSucceeded(
            identifier); // Passar ID correto se necessário
      }

      // Força o recarregamento do estado do usuário APÓS a simulação do webhook
      // É importante que o StoreProvider esteja disponível neste BuildContext
      // O que geralmente é verdade se chamado de uma página/widget
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final store = StoreProvider.of<AppState>(context, listen: false);
          store.dispatch(LoadUserPremiumStatusAction());
          store.dispatch(LoadUserDetailsAction());
        }
      });

      _showSuccessDialog(context,
          isSubscription ? "Assinatura confirmada!" : "Pagamento confirmado!");
    } on StripeException catch (e) {
      print(
          "Erro Stripe durante present/confirm PaymentSheet: ${e.error.localizedMessage}");
      _showErrorDialog(
          context, e.error.localizedMessage ?? "Erro durante o pagamento.");
    } catch (e) {
      print("Erro inesperado durante present/confirm PaymentSheet: $e");
      _showErrorDialog(context, "Ocorreu um erro inesperado.");
    }
  }

  // --- Diálogos de Feedback (permanecem privados) ---
  void _showSuccessDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Sucesso ✅"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    });
  }

  void _showErrorDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Erro ❌"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    });
  }
}
