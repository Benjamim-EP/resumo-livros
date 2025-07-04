// lib/redux/middleware/backend_validation_middleware.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions/payment_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart'; // <<< ADICIONAR IMPORT

List<Middleware<AppState>> createBackendValidationMiddleware() {
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  void handleGooglePlayPurchaseVerified(
    Store<AppState> store,
    GooglePlayPurchaseVerifiedAction action,
    NextDispatcher next,
  ) async {
    // A ação original da UI não precisa mais ter o completer.
    // O middleware vai controlar o fluxo.
    next(action);

    final purchaseDetails = action.purchaseDetails;
    final context = navigatorKey.currentContext;

    // Mostra um diálogo de "validando" que bloqueia a UI
    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const PopScope(
          canPop: false, // Impede o usuário de fechar o diálogo
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Validando assinatura..."),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final HttpsCallable callable =
          functions.httpsCallable('validate_google_play_purchase');
      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'productId': purchaseDetails.productID,
        'purchaseToken':
            purchaseDetails.verificationData.serverVerificationData,
      });

      print(
          "BackendValidationMiddleware: Resposta do backend recebida: ${result.data}");

      // <<< MUDANÇA CRÍTICA AQUI >>>
      // Em vez de esperar o listener, despachamos a ação de sucesso AGORA.
      // O backend já atualizou o Firestore, então os dados para a action podem vir
      // da resposta da cloud function se ela os retornar, ou podemos usar valores genéricos.
      store.dispatch(SubscriptionStatusUpdatedAction(
        status:
            'active', // Assumimos que a validação bem-sucedida significa ativo
        endDate:
            null, // O listener do MainAppScreen vai pegar a data exata depois
        priceId: purchaseDetails.productID,
      ));

      // 1. Fecha o diálogo de "validando"
      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pop(); // Fecha o diálogo de loading
      }

      // 2. Fecha a página de assinatura
      if (context != null && context.mounted) {
        // Verifique se a página de assinatura está no topo antes de dar pop
        if (ModalRoute.of(context)?.settings.name != '/mainAppScreen') {
          Navigator.of(context).pop();
        }
      }
    } on FirebaseFunctionsException catch (e) {
      print(
          "BackendValidationMiddleware: Erro FirebaseFunctionsException: ${e.message}");

      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pop(); // Fecha o diálogo de loading
      }

      store.dispatch(
          GooglePlayPaymentFailedAction(e.message ?? "Falha na validação."));

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao validar assinatura: ${e.message}')),
        );
      }
    } catch (e) {
      print("BackendValidationMiddleware: Erro inesperado: $e");

      if (context != null && context.mounted) {
        Navigator.of(context, rootNavigator: true)
            .pop(); // Fecha o diálogo de loading
      }

      store.dispatch(
          GooglePlayPaymentFailedAction("Ocorreu um erro inesperado."));
    }
  }

  return [
    TypedMiddleware<AppState, GooglePlayPurchaseVerifiedAction>(
        handleGooglePlayPurchaseVerified),
  ];
}
