// lib/services/stripe_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:resumo_dos_deuses_flutter/services/stripe_backend_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Para obter o store para despachar ações PÓS webhook
import 'package:flutter_redux/flutter_redux.dart'; // Para obter o store
import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Para despachar SubscriptionStatusUpdatedAction
import '../redux/actions.dart'; // Para LoadUserPremiumStatusAction, LoadUserDetailsAction

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();
  final StripeBackendService _backendService = StripeBackendService();

  Future<void> initiatePayment(
    String priceId,
    String userId,
    String email,
    String nome,
    BuildContext context,
  ) async {
    // --- DEBUG PRINT ---
    print(
        '>>> StripeService: initiatePayment iniciado para priceId: $priceId, userId: $userId');
    // --- FIM DEBUG PRINT ---
    try {
      // --- DEBUG PRINT ---
      print(
          '>>> StripeService: Chamando _backendService.getOrCreateCustomer...');
      // --- FIM DEBUG PRINT ---
      final customerId =
          await _backendService.getOrCreateCustomer(email, nome, userId);
      if (customerId == null) {
        print(
            '>>> StripeService: ERRO - CustomerId nulo retornado pelo backend.'); // DEBUG
        _showErrorDialog(context, "Erro ao configurar cliente de pagamento.");
        return;
      }
      // --- DEBUG PRINT ---
      print('>>> StripeService: CustomerId obtido/criado: $customerId');
      print(
          '>>> StripeService: Chamando _backendService.createPaymentIntent...');
      // --- FIM DEBUG PRINT ---
      final clientSecret =
          await _backendService.createPaymentIntent(priceId, customerId);
      if (clientSecret == null) {
        print(
            '>>> StripeService: ERRO - clientSecret nulo retornado pelo backend.'); // DEBUG
        _showErrorDialog(context, "Erro ao iniciar o pagamento.");
        return;
      }
      // --- DEBUG PRINT ---
      print('>>> StripeService: clientSecret obtido: $clientSecret');
      print('>>> StripeService: Chamando Stripe.instance.initPaymentSheet...');
      // --- FIM DEBUG PRINT ---
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: "Septima",
          customerId: customerId,
        ),
      );
      // --- DEBUG PRINT ---
      print('>>> StripeService: initPaymentSheet concluído.');
      print('>>> StripeService: Chamando _presentAndConfirmPayment...');
      // --- FIM DEBUG PRINT ---
      await _presentAndConfirmPayment(context,
          isSubscription: false, identifier: clientSecret, userId: userId);
    } catch (e) {
      // --- DEBUG PRINT ---
      print(">>> StripeService: CATCH (initiatePayment) - Erro no fluxo: $e");
      // --- FIM DEBUG PRINT ---
      _showErrorDialog(
          context, "Ocorreu um erro inesperado durante o pagamento.");
    }
  }

  Future<void> initiateSubscription(
    String priceId,
    String userId,
    String email,
    String nome,
    BuildContext context,
  ) async {
    // --- DEBUG PRINT ---
    print(
        '>>> StripeService: initiateSubscription iniciado para priceId: $priceId, userId: $userId');
    // --- FIM DEBUG PRINT ---
    try {
      // --- DEBUG PRINT ---
      print(
          '>>> StripeService: Chamando _backendService.getOrCreateCustomer...');
      // --- FIM DEBUG PRINT ---
      final customerId =
          await _backendService.getOrCreateCustomer(email, nome, userId);
      if (customerId == null) {
        print(
            '>>> StripeService: ERRO - CustomerId nulo retornado pelo backend.'); // DEBUG
        _showErrorDialog(context, "Erro ao configurar cliente de pagamento.");
        return;
      }
      // --- DEBUG PRINT ---
      print('>>> StripeService: CustomerId obtido/criado: $customerId');
      print(
          '>>> StripeService: Chamando _backendService.createSubscription...');
      // --- FIM DEBUG PRINT ---
      final subscriptionData =
          await _backendService.createSubscription(priceId, customerId);
      if (subscriptionData == null) {
        print(
            '>>> StripeService: ERRO - subscriptionData nulo retornado pelo backend.'); // DEBUG
        _showErrorDialog(context, "Erro ao iniciar a assinatura.");
        return;
      }
      // --- DEBUG PRINT ---
      print('>>> StripeService: subscriptionData obtido: $subscriptionData');
      // --- FIM DEBUG PRINT ---

      final clientSecret = subscriptionData["clientSecret"];
      final subscriptionId = subscriptionData["subscriptionId"];
      final initialStatus = subscriptionData["status"];

      if (clientSecret != null && initialStatus != 'active') {
        // --- DEBUG PRINT ---
        print(
            '>>> StripeService: Assinatura requer confirmação. Chamando initPaymentSheet...');
        // --- FIM DEBUG PRINT ---
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: "Septima",
            customerId: customerId,
          ),
        );
        // --- DEBUG PRINT ---
        print('>>> StripeService: initPaymentSheet concluído.');
        print('>>> StripeService: Chamando _presentAndConfirmPayment...');
        // --- FIM DEBUG PRINT ---
        await _presentAndConfirmPayment(context,
            isSubscription: true, identifier: subscriptionId, userId: userId);
      } else if (initialStatus == 'active') {
        // --- DEBUG PRINT ---
        print(
            ">>> StripeService: Assinatura $subscriptionId ativa, sem necessidade de PaymentSheet.");
        // --- FIM DEBUG PRINT ---
        _showSuccessDialog(context, "Assinatura ativada com sucesso!");
        // Dispara ações para recarregar estado do Firestore via Redux
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final store = StoreProvider.of<AppState>(context, listen: false);
            store.dispatch(LoadUserPremiumStatusAction());
            store.dispatch(LoadUserDetailsAction());
          }
        });
      } else {
        print(
            '>>> StripeService: ERRO - Status inesperado da assinatura: $initialStatus'); // DEBUG
        _showErrorDialog(
            context, "Status inesperado da assinatura após criação.");
      }
    } catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> StripeService: CATCH (initiateSubscription) - Erro no fluxo: $e");
      // --- FIM DEBUG PRINT ---
      _showErrorDialog(
          context, "Ocorreu um erro inesperado durante a assinatura.");
    }
  }

  Future<void> _presentAndConfirmPayment(BuildContext context,
      {required bool isSubscription,
      required String identifier,
      required String userId}) async {
    // --- DEBUG PRINT ---
    print(
        '>>> StripeService: _presentAndConfirmPayment iniciado. isSubscription: $isSubscription, identifier: $identifier');
    // --- FIM DEBUG PRINT ---
    try {
      // --- DEBUG PRINT ---
      print(
          '>>> StripeService: Chamando Stripe.instance.presentPaymentSheet...');
      // --- FIM DEBUG PRINT ---
      await Stripe.instance.presentPaymentSheet();
      // --- DEBUG PRINT ---
      print(
          '>>> StripeService: presentPaymentSheet CONCLUÍDO (ou fechado pelo usuário).');
      // --- FIM DEBUG PRINT ---

      // --- SIMULAÇÃO PÓS-PAGAMENTO (APENAS PARA DEV) ---
      // --- DEBUG PRINT ---
      print(">>> StripeService: SIMULANDO chamada de webhook para backend...");
      // --- FIM DEBUG PRINT ---
      if (isSubscription) {
        await _backendService.handleSubscriptionWebhookEvent(
            identifier, 'active', null);
      } else {
        await _backendService.handlePaymentIntentSucceeded(identifier);
      }
      // --- DEBUG PRINT ---
      print('>>> StripeService: SIMULAÇÃO Webhook concluída.');
      // --- FIM DEBUG PRINT ---

      // Força o recarregamento do estado do usuário APÓS a simulação do webhook
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          // --- DEBUG PRINT ---
          print(
              '>>> StripeService: Disparando ações Redux para recarregar estado do usuário (LoadUserPremiumStatusAction, LoadUserDetailsAction)');
          // --- FIM DEBUG PRINT ---
          final store = StoreProvider.of<AppState>(context, listen: false);
          store.dispatch(LoadUserPremiumStatusAction());
          store.dispatch(LoadUserDetailsAction());
        } else {
          print(
              '>>> StripeService: ERRO - Contexto não montado após simulação de webhook.'); // DEBUG
        }
      });

      _showSuccessDialog(context,
          isSubscription ? "Assinatura confirmada!" : "Pagamento confirmado!");
    } on StripeException catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> StripeService: CATCH StripeException em _presentAndConfirmPayment - ${e.error.code} - ${e.error.localizedMessage}");
      // --- FIM DEBUG PRINT ---
      _showErrorDialog(
          context, e.error.localizedMessage ?? "Erro durante o pagamento.");
    } catch (e) {
      // --- DEBUG PRINT ---
      print(
          ">>> StripeService: CATCH Geral em _presentAndConfirmPayment - Erro inesperado: $e");
      // --- FIM DEBUG PRINT ---
      _showErrorDialog(context, "Ocorreu um erro inesperado.");
    }
  }

  // --- Diálogos de Feedback (permanecem privados) ---
  void _showSuccessDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // --- DEBUG PRINT ---
        print(">>> StripeService: Mostrando diálogo de SUCESSO: $message");
        // --- FIM DEBUG PRINT ---
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
      } else {
        print(
            ">>> StripeService: ERRO - Contexto não montado ao tentar mostrar diálogo de sucesso."); // DEBUG
      }
    });
  }

  void _showErrorDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // --- DEBUG PRINT ---
        print(">>> StripeService: Mostrando diálogo de ERRO: $message");
        // --- FIM DEBUG PRINT ---
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
      } else {
        print(
            ">>> StripeService: ERRO - Contexto não montado ao tentar mostrar diálogo de erro."); // DEBUG
      }
    });
  }
}
