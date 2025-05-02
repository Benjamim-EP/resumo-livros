// lib/redux/middleware/payment_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../actions/payment_actions.dart';
import '../store.dart';
import '../../services/stripe_service.dart';
import '../../main.dart';
import '../actions.dart';

List<Middleware<AppState>> createPaymentMiddleware() {
  final stripeFrontendService = StripeService.instance;
  final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  return [
    TypedMiddleware<AppState, InitiateStripePaymentAction>(
        _handleInitiatePayment(stripeFrontendService, functions)),
  ];
}

void Function(Store<AppState>, InitiateStripePaymentAction, NextDispatcher)
    _handleInitiatePayment(
        StripeService stripeFrontendService, FirebaseFunctions functions) {
  return (Store<AppState> store, InitiateStripePaymentAction action,
      NextDispatcher next) async {
    print(
        '>>> Middleware: _handleInitiatePayment iniciado para priceId: ${action.priceId}, isSubscription: ${action.isSubscription}');
    next(action);

    final BuildContext? context = navigatorKey.currentContext;
    final userId = store.state.userState.userId;

    print(
        '>>> Middleware: Tentando obter context. navigatorKey.currentContext é: ${context == null ? "nulo" : "não nulo"}');
    print('>>> Middleware: Dados do usuário do store: userId: $userId');

    if (context == null) {
      print(
          ">>> Middleware: ERRO - BuildContext nulo. Não é possível iniciar o pagamento.");
      store.dispatch(
          StripePaymentFailedAction("Erro interno: Contexto inválido."));
      return;
    }

    if (userId == null) {
      print(">>> Middleware: ERRO - Usuário não autenticado no estado Redux.");
      store.dispatch(
          StripePaymentFailedAction("Erro: Usuário não autenticado."));
      return;
    }

    // Mostra loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      print(
          '>>> Middleware: Chamando Cloud Function "create_stripe_checkout"...');
      final HttpsCallable callable =
          functions.httpsCallable('create_stripe_checkout');
      final result = await callable.call<Map<String, dynamic>>(
        {'priceId': action.priceId, 'isSubscription': action.isSubscription},
      );
      print(
          '>>> Middleware: Resposta da Cloud Function recebida: ${result.data}');

      // Fecha o loading ANTES de processar a resposta
      // Importante verificar se o contexto ainda é válido APÓS o await
      if (context.mounted)
        Navigator.of(context).pop();
      else {
        print(
            ">>> Middleware: Aviso - Contexto não montado após retorno da Cloud Function. Não foi possível fechar o diálogo de loading.");
        // Se o contexto não estiver montado, não podemos continuar com segurança para mostrar o PaymentSheet
        store.dispatch(StripePaymentFailedAction(
            "Erro interno: Contexto inválido após processamento."));
        return;
      }

      final clientSecret = result.data['clientSecret'] as String?;
      final subscriptionId = result.data['subscriptionId'] as String?;
      final customerId = result.data['customerId'] as String?;
      final status = result.data['status'] as String?;

      if (clientSecret != null && customerId != null) {
        print(
            '>>> Middleware: clientSecret recebido. Chamando stripeFrontendService.presentPaymentSheetWithSecret...');
        await stripeFrontendService.presentPaymentSheetWithSecret(
            clientSecret,
            customerId,
            context, // Passa o contexto que sabemos que está montado
            isSubscription: action.isSubscription,
            identifier: action.isSubscription ? subscriptionId! : clientSecret);
        print(
            '>>> Middleware: Chamada a presentPaymentSheetWithSecret concluída.');
      } else if (status == 'active' && subscriptionId != null) {
        print(
            '>>> Middleware: Assinatura $subscriptionId ativa imediatamente.');
        // REMOVIDO: stripeFrontendService.showSuccessDialog(...) daqui
        // O diálogo de sucesso/erro será mostrado DENTRO de presentPaymentSheetWithSecret
        // ou, neste caso 'active', podemos mostrar um diálogo genérico ou apenas atualizar o estado.
        // Apenas atualiza o estado Redux, a UI reagirá.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Garante que aconteça após o build atual
          if (context.mounted) {
            // Verifica de novo por segurança
            final store = StoreProvider.of<AppState>(context, listen: false);
            store.dispatch(LoadUserPremiumStatusAction());
            store.dispatch(LoadUserDetailsAction());
            // Opcional: Mostrar um SnackBar rápido em vez de diálogo
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Assinatura ativada!'),
                  duration: Duration(seconds: 2)),
            );
          }
        });
      } else {
        print(
            '>>> Middleware: ERRO - Resposta inválida da Cloud Function: Faltando clientSecret/customerId ou status ativo.');
        throw Exception("Resposta inesperada do servidor.");
      }
    } on FirebaseFunctionsException catch (e) {
      // Garante fechar loading em erro
      // Verifica se o contexto original ainda é válido ANTES de tentar fechar o diálogo
      if (context.mounted) Navigator.of(context).pop();
      print(
          ">>> Middleware: CATCH FirebaseFunctionsException - ${e.code} - ${e.message}");
      store.dispatch(StripePaymentFailedAction(
          "Erro ao comunicar com o servidor (${e.code}): ${e.message ?? 'Erro desconhecido'}"));
      // REMOVIDO: Chamada a showErrorDialog daqui
    } catch (e) {
      // Garante fechar loading em erro
      if (context.mounted) Navigator.of(context).pop();
      print(
          ">>> Middleware: CATCH Geral - Erro ao chamar/processar Cloud Function: $e");
      store.dispatch(StripePaymentFailedAction(
          "Erro ao iniciar ${action.isSubscription ? 'assinatura' : 'pagamento'}: $e"));
      // REMOVIDO: Chamada a showErrorDialog daqui
    }
  };
}
