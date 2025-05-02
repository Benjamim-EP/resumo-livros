// lib/services/stripe_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Para acessar o store pós-pagamento
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Para AppState e store
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/services/stripe_backend_service.dart'; // Não chama mais o backend simulado
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/redux/actions/payment_actions.dart'; // Ações são despachadas pelo middleware ou listener
import '../redux/actions.dart'; // Para LoadUserPremiumStatusAction, LoadUserDetailsAction

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();
  // REMOVIDO: final StripeBackendService _backendService = StripeBackendService();

  /// Inicializa e apresenta o PaymentSheet usando o clientSecret recebido do backend.
  Future<void> presentPaymentSheetWithSecret(
      String clientSecret,
      String customerId, // Recebe customerId criado/obtido pelo backend
      BuildContext context, // Contexto para mostrar o sheet e dialogs
      {required bool isSubscription, // Para mensagem de sucesso
      required String identifier // ID da Sub/Intent para logs (opcional)
      }) async {
    print(
        '>>> StripeService: presentPaymentSheetWithSecret iniciado. Identifier: $identifier');

    try {
      // 1. Inicializa o PaymentSheet com os dados do backend
      print('>>> StripeService: Chamando Stripe.instance.initPaymentSheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret:
              clientSecret, // ESSENCIAL: Vindo do backend
          merchantDisplayName: "Septima",
          customerId: customerId, // Vindo do backend
          // customerEphemeralKeySecret: ephemeralKey, // Se o backend gerar ephemeral keys
          // testEnv: true, // Se estiver usando chaves de teste
          // style: ThemeMode.dark,
        ),
      );
      print('>>> StripeService: initPaymentSheet concluído.');

      // 2. Apresenta o PaymentSheet para o usuário
      print(
          '>>> StripeService: Chamando Stripe.instance.presentPaymentSheet...');
      await Stripe.instance.presentPaymentSheet();
      print(
          '>>> StripeService: presentPaymentSheet CONCLUÍDO (ou fechado pelo usuário). Pagamento/Confirmação bem-sucedida no frontend.');

      // 3. Feedback de Sucesso e Recarregamento do Estado
      // A confirmação REAL e atualização do Firestore acontecem via Webhook -> Cloud Function.
      // Aqui, apenas mostramos sucesso e disparamos ações para o app LER o estado atualizado.
      _showSuccessDialog(context,
          isSubscription ? "Assinatura iniciada!" : "Pagamento processado!");

      // Dispara ações para forçar o recarregamento do estado do usuário do Firestore
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          print(
              '>>> StripeService: Disparando ações Redux para recarregar estado do usuário (LoadUserPremiumStatusAction, LoadUserDetailsAction)');
          final store = StoreProvider.of<AppState>(context, listen: false);
          store.dispatch(
              LoadUserPremiumStatusAction()); // Ou a ação que carrega o status
          store.dispatch(LoadUserDetailsAction()); // Ou LoadUserStatsAction
        } else {
          print(
              '>>> StripeService: ERRO - Contexto não montado após presentPaymentSheet.');
        }
      });
    } on StripeException catch (e) {
      // Erro específico do Stripe (ex: cartão recusado, pagamento cancelado)
      print(
          ">>> StripeService: CATCH StripeException em presentPaymentSheetWithSecret - ${e.error.code} - ${e.error.localizedMessage}");
      _showErrorDialog(
          context, e.error.localizedMessage ?? "Erro durante o pagamento.");
      // Opcional: Despachar ação de falha Redux se necessário
      // StoreProvider.of<AppState>(context, listen: false).dispatch(StripePaymentFailedAction(e.error.localizedMessage ?? "Erro Stripe"));
    } catch (e) {
      // Outros erros inesperados
      print(
          ">>> StripeService: CATCH Geral em presentPaymentSheetWithSecret - Erro inesperado: $e");
      _showErrorDialog(context, "Ocorreu um erro inesperado.");
      // Opcional: Despachar ação de falha Redux
      // StoreProvider.of<AppState>(context, listen: false).dispatch(StripePaymentFailedAction("Erro inesperado: $e"));
    }
  }

  // REMOVIDO: Métodos initiatePayment, initiateSubscription e _presentAndConfirmPayment (lógica movida/adaptada)

  // --- Diálogos de Feedback (permanecem privados) ---
  void _showSuccessDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        print(">>> StripeService: Mostrando diálogo de SUCESSO: $message");
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
            ">>> StripeService: ERRO - Contexto não montado ao tentar mostrar diálogo de sucesso.");
      }
    });
  }

  void _showErrorDialog(BuildContext context, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        print(">>> StripeService: Mostrando diálogo de ERRO: $message");
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
            ">>> StripeService: ERRO - Contexto não montado ao tentar mostrar diálogo de erro.");
      }
    });
  }
}
