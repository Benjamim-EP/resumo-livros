// lib/redux/middleware/bible_search_middleware.dart
import 'package:flutter/material.dart'; // NOVO: Para ScaffoldMessenger
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/main.dart'; // NOVO: Para navigatorKey
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // NOVO: Para RewardedAdWatchedAction
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // NOVO

import 'package:cloud_firestore/cloud_firestore.dart';

const int BIBLE_SEARCH_COST = 5; // Custo da busca

void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  // 1. Ação original é passada APÓS a verificação de moedas.
  //    Se não houver moedas, a ação de busca não prossegue para o isLoading, etc.

  final BuildContext? currentContext = navigatorKey.currentContext; // NOVO
  final userId = store.state.userState.userId;
  final userCoins = store.state.userState.userCoins;

  if (userId == null) {
    print("BibleSearchMiddleware: Usuário não logado. Busca cancelada.");
    if (currentContext != null && currentContext.mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(content: Text('Você precisa estar logado para buscar.')),
      );
    }
    // Não despacha SearchBibleSemanticFailureAction aqui, pois a busca nem começou.
    // O reducer de SearchBibleSemanticAction não deve ter sido chamado para isLoading=true.
    return;
  }

  // Verifica se o usuário é premium
  bool isUserPremium = false;
  final userDetails = store.state.userState.userDetails;
  if (userDetails != null) {
    final status = userDetails['subscriptionStatus'] as String?;
    final endDateTimestamp = userDetails['subscriptionEndDate'] as Timestamp?;
    if (status == 'active') {
      if (endDateTimestamp != null) {
        isUserPremium = endDateTimestamp.toDate().isAfter(DateTime.now());
      } else {
        // Se endDateTimestamp for nulo mas o status for 'active',
        // pode ser uma assinatura vitalícia ou um erro nos dados.
        // Por segurança, vamos considerar premium aqui, mas revise sua lógica de `active` sem `endDate`.
        isUserPremium = true;
      }
    }
  }
  print("BibleSearchMiddleware: Usuário é premium? $isUserPremium");

  // Se o usuário NÃO for premium, verifica as moedas
  if (!isUserPremium) {
    print(
        "BibleSearchMiddleware: Usuário não é premium. Verificando moedas...");
    if (userCoins < BIBLE_SEARCH_COST) {
      print(
          "BibleSearchMiddleware: Moedas insuficientes ($userCoins) para buscar (custo: $BIBLE_SEARCH_COST).");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
                'Moedas insuficientes para buscar. Você tem $userCoins, são necessárias $BIBLE_SEARCH_COST.'),
            action: SnackBarAction(
              // NOVO: Adiciona ação para ganhar moedas
              label: 'Ganhar Moedas',
              onPressed: () {
                store.dispatch(RequestRewardedAdAction());
              },
            ),
          ),
        );
      }
      // Despacha uma falha para que a UI possa parar o loading se já tiver começado (embora a ideia seja não começar).
      // É importante que SearchBibleSemanticAction não sete isLoading=true diretamente no reducer.
      // O middleware controla o isLoading.
      store.dispatch(SearchBibleSemanticFailureAction('Moedas insuficientes.'));
      return;
    }
  } else {
    print(
        "BibleSearchMiddleware: Usuário é premium. Busca sem custo de moedas.");
  }

  // Se chegou aqui, o usuário tem moedas (ou é premium) ou a verificação de moedas foi pulada.
  // Agora sim, despacha a ação para o reducer indicar que o carregamento começou.
  next(action);

  // Dedução de moedas (APENAS SE NÃO FOR PREMIUM)
  if (!isUserPremium) {
    print(
        "BibleSearchMiddleware: Deduzindo $BIBLE_SEARCH_COST moedas do usuário $userId.");
    // Usamos RewardedAdWatchedAction com valor negativo para deduzir.
    // Isso reutiliza a lógica do reducer para atualizar moedas e o FirestoreService para salvar.
    // A data do 'adWatchTime' não é relevante aqui, mas a ação espera.
    store.dispatch(RewardedAdWatchedAction(-BIBLE_SEARCH_COST, DateTime.now()));
    // A ação RewardedAdWatchedAction já chama o FirestoreService para atualizar moedas
    // (ver ad_middleware), então não precisamos chamar de novo aqui.
    // No entanto, a atualização de `rewardedAdsWatchedToday` não faz sentido aqui.
    // Seria melhor ter uma ação específica `DeductCoinsAction` ou
    // modificar `RewardedAdWatchedAction` para ser mais genérica ou
    // atualizar o firestore diretamente aqui para moedas.

    // VAMOS OPTAR POR ATUALIZAR DIRETAMENTE O FIRESTORE PARA MOEDAS,
    // E DESPACHAR UMA AÇÃO MAIS SIMPLES PARA O REDUX.
    // Isso evita o efeito colateral de `rewardedAdsWatchedToday` da `RewardedAdWatchedAction`.

    final firestoreService = FirestoreService(); // Instancia aqui ou injeta
    try {
      int newCoinTotal = userCoins - BIBLE_SEARCH_COST;
      await firestoreService.updateUserField(userId, 'userCoins', newCoinTotal);
      // Despachar uma ação para o Redux atualizar apenas as moedas no estado
      store.dispatch(UpdateUserCoinsAction(
          newCoinTotal)); // <<< PRECISA CRIAR ESTA AÇÃO E REDUCER

      print(
          "BibleSearchMiddleware: Moedas deduzidas com sucesso. Novo total: $newCoinTotal");
      if (currentContext != null && currentContext.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Garante que é executado após o build
          if (currentContext.mounted) {
            // Verifica de novo
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                  content:
                      Text('$BIBLE_SEARCH_COST moedas usadas para a busca.')),
            );
          }
        });
      }
    } catch (e) {
      print("BibleSearchMiddleware: Erro ao deduzir moedas do Firestore: $e");
      // Considerar reverter a busca ou notificar o usuário do erro na dedução.
      // Por ora, a busca prossegue, mas a dedução pode ter falhado.
      store.dispatch(SearchBibleSemanticFailureAction(
          'Erro ao processar custo da busca.'));
      return; // Interrompe a busca se a dedução falhou
    }
  }

  try {
    print(
        'BibleSearchMiddleware: Iniciando busca para query="${action.query}" com filtros: ${store.state.bibleSearchState.activeFilters}');

    final functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_bible_search');

    final requestData = {
      'query': action.query,
      'filters': store.state.bibleSearchState.activeFilters,
      'topK': 15,
    };

    print(
        'BibleSearchMiddleware: Chamando Cloud Function com dados: $requestData');
    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    final dynamic rawResults = response.data?['results'];
    List<Map<String, dynamic>> resultsList = [];

    if (rawResults is List) {
      resultsList = rawResults
          .map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          })
          .where((item) => item.isNotEmpty)
          .toList();
    } else if (rawResults != null) {
      print(
          'BibleSearchMiddleware: "results" não é uma lista, recebido: ${rawResults.runtimeType}');
    }

    print(
        'BibleSearchMiddleware: Resultados recebidos da Cloud Function: ${resultsList.length} itens.');
    store.dispatch(SearchBibleSemanticSuccessAction(resultsList));
  } catch (e) {
    print(
        "BibleSearchMiddleware: Erro ao chamar a Cloud Function 'semantic_bible_search': $e");
    var errorMessage = "Ocorreu um erro desconhecido durante a busca.";
    if (e is FirebaseFunctionsException) {
      print(
          "BibleSearchMiddleware: Detalhes da FirebaseFunctionsException: code=${e.code}, message=${e.message}, details=${e.details}");
      errorMessage =
          "Erro na busca (${e.code}): ${e.message ?? 'Falha ao contatar o servidor.'}";
    } else {
      errorMessage = e.toString();
    }
    store.dispatch(SearchBibleSemanticFailureAction(errorMessage));
  }
}

List<Middleware<AppState>> createBibleSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchBibleSemanticAction>(
            _handleSearchBibleSemantic)
        .call,
  ];
}
