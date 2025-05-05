// lib/redux/middleware/payment_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Para obter store no callback do WidgetsBinding
import 'package:cloud_functions/cloud_functions.dart';
import '../actions/payment_actions.dart';
import '../store.dart';
import '../../services/stripe_service.dart'; // Serviço Frontend (para apresentar o sheet)
import '../../main.dart'; // Onde navigatorKey está definida
import '../actions.dart'; // Para LoadUser... actions

List<Middleware<AppState>> createPaymentMiddleware() {
  final stripeFrontendService = StripeService.instance;
  final functions = FirebaseFunctions.instanceFor(
      region: 'southamerica-east1'); // Ajuste sua região se necessário

  return [
    TypedMiddleware<AppState, InitiateStripePaymentAction>(
        _handleInitiatePayment(
            stripeFrontendService, functions)), // Passa functions
  ];
}

void Function(Store<AppState>, InitiateStripePaymentAction, NextDispatcher)
    _handleInitiatePayment(
        StripeService stripeFrontendService, FirebaseFunctions functions) {
  // Recebe functions
  return (Store<AppState> store, InitiateStripePaymentAction action,
      NextDispatcher next) async {
    print(
        '>>> Middleware: _handleInitiatePayment iniciado para priceId: ${action.priceId}, isSubscription: ${action.isSubscription}');
    next(action); // Passa a ação adiante

    final BuildContext? initialContext =
        navigatorKey.currentContext; // Captura o contexto inicial
    final userId = store.state.userState.userId;

    print(
        '>>> Middleware: Tentando obter context. Contexto inicial é: ${initialContext == null ? "nulo" : "não nulo"}');
    print('>>> Middleware: Dados do usuário do store: userId: $userId');

    // Verifica se o contexto inicial era válido
    if (initialContext == null || !initialContext.mounted) {
      print(">>> Middleware: ERRO - Contexto inicial inválido ou não montado.");
      store.dispatch(StripePaymentFailedAction(
          "Erro interno: Contexto inválido para iniciar pagamento."));
      return;
    }

    if (userId == null) {
      print(">>> Middleware: ERRO - Usuário não autenticado no estado Redux.");
      store.dispatch(
          StripePaymentFailedAction("Erro: Usuário não autenticado."));
      return;
    }

    // Mostra loading usando o contexto inicial válido
    showDialog(
      context: initialContext, // Usa o contexto inicial
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    // Variável para garantir que o diálogo de loading seja fechado apenas uma vez
    bool isLoadingDialogClosed = false;
    void closeLoadingDialog() {
      // Usa a navigatorKey para obter o contexto ATUAL ao fechar
      final currentContext = navigatorKey.currentContext;
      if (currentContext != null &&
          currentContext.mounted &&
          !isLoadingDialogClosed) {
        try {
          Navigator.of(currentContext).pop(); // Tenta fechar
          isLoadingDialogClosed = true;
          print(">>> Middleware: Diálogo de loading fechado.");
        } catch (e) {
          print(
              ">>> Middleware: Erro ao fechar diálogo de loading (talvez já fechado?): $e");
          isLoadingDialogClosed = true; // Marca como fechado mesmo se der erro
        }
      } else if (!isLoadingDialogClosed) {
        print(
            ">>> Middleware: Aviso - Contexto atual nulo/não montado ao tentar fechar diálogo de loading.");
      }
    }

    try {
      print(
          '>>> Middleware: Chamando Cloud Function "create_stripe_checkout"...');
      final HttpsCallable callable =
          functions.httpsCallable('create_stripe_checkout');
      final result = await callable.call<Map<String, dynamic>>(
        {'priceId': action.priceId, 'isSubscription': action.isSubscription},
      );
      final responseData = result.data;
      print(
          '>>> Middleware: Resposta da Cloud Function recebida: $responseData');

      // Fecha o loading APÓS receber a resposta
      closeLoadingDialog();

      // Re-obtém o contexto atualizado após o await e o fechamento do diálogo
      final validContext = navigatorKey.currentContext;
      if (validContext == null || !validContext.mounted) {
        print(
            ">>> Middleware: ERRO - Contexto não montado após retorno da Cloud Function. Abortando.");
        store.dispatch(
            StripePaymentFailedAction("Erro interno: Ação cancelada."));
        return;
      }

      // --- Processa a resposta da Cloud Function ---
      final clientSecret = responseData['clientSecret'] as String?;
      final subscriptionId = responseData['subscriptionId'] as String?;
      final customerId = responseData['customerId'] as String?;
      final status = responseData['status'] as String?;

      if (customerId == null) {
        print(
            '>>> Middleware: ERRO CRÍTICO - Resposta da Cloud Function sem customerId.');
        throw Exception("Resposta inválida do servidor (sem customerId).");
      }

      // Cenário 1: Temos clientSecret (Pagamento único OU Assinatura que precisa de ação)
      if (clientSecret != null) {
        print(
            '>>> Middleware: clientSecret recebido (${clientSecret.substring(0, 10)}...). Chamando presentPaymentSheetWithSecret...');
        await stripeFrontendService.presentPaymentSheetWithSecret(
            clientSecret, customerId, validContext,
            isSubscription: action.isSubscription,
            identifier: action.isSubscription
                ? (subscriptionId ?? 'sub_desconhecida')
                : clientSecret);
        print(
            '>>> Middleware: Chamada a presentPaymentSheetWithSecret concluída.');
      }
      // Cenário 2: SEM clientSecret, MAS é uma assinatura e já está ATIVA (ex: trial)
      else if (action.isSubscription &&
          status == 'active' &&
          subscriptionId != null) {
        print(
            '>>> Middleware: Assinatura $subscriptionId ativa imediatamente. Atualizando UI.');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (validContext.mounted) {
            ScaffoldMessenger.of(validContext).showSnackBar(
              const SnackBar(
                  content: Text('Assinatura ativada!'),
                  duration: Duration(seconds: 3)),
            );
            final store =
                StoreProvider.of<AppState>(validContext, listen: false);
            store.dispatch(LoadUserPremiumStatusAction());
            store.dispatch(LoadUserDetailsAction());
          }
        });
      }
      // Cenário 3: Resposta inesperada (ex: status 'incomplete' SEM clientSecret)
      else {
        // Este caso agora deve ser menos provável se a função Python foi corrigida
        // para sempre tentar obter o client secret do SetupIntent/Invoice.
        print(
            '>>> Middleware: ERRO/AVISO - Resposta inesperada da Cloud Function (ex: sub incomplete sem clientSecret). Resposta: $responseData');
        throw Exception(
            "Não foi possível obter os detalhes necessários para o pagamento."); // Será pego pelo catch abaixo
      }
      // --------------------------------------------
    } on FirebaseFunctionsException catch (e) {
      closeLoadingDialog();
      print(
          ">>> Middleware: CATCH FirebaseFunctionsException - ${e.code} - ${e.message} - Details: ${e.details}");
      final errorMessage =
          "Erro (${e.code}): ${e.message ?? 'Falha na comunicação.'}";
      store.dispatch(StripePaymentFailedAction(errorMessage));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null && currentContext.mounted) {
          stripeFrontendService.showErrorDialog(currentContext, errorMessage);
        }
      });
    } catch (e) {
      closeLoadingDialog();
      print(">>> Middleware: CATCH Geral - Erro: $e");
      final errorMessage = "Erro inesperado: $e";
      store.dispatch(StripePaymentFailedAction(errorMessage));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentContext = navigatorKey.currentContext;
        if (currentContext != null && currentContext.mounted) {
          stripeFrontendService.showErrorDialog(
              currentContext, "Ocorreu um erro inesperado.");
        }
      });
    }
  };
}
