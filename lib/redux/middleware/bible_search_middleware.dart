// lib/redux/middleware/bible_search_middleware.dart
import 'package:flutter/material.dart'; // NOVO: Para ScaffoldMessenger
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/main.dart'; // NOVO: Para navigatorKey
import 'package:septima_biblia/redux/actions.dart'; // NOVO: Para RewardedAdWatchedAction
import 'package:septima_biblia/services/firestore_service.dart'; // NOVO

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int BIBLE_SEARCH_COST = 3; // Custo da busca
const String guestUserCoinsPrefsKeyForBibleSearch =
    'shared_guest_user_coins'; // Use a mesma chave que no sermon_search e ad_middleware

void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  // --- INÍCIO DA LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---
  final BuildContext? currentContext = navigatorKey.currentContext;
  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;
  final userCoins = userState.userCoins;
  final isPremium =
      store.state.subscriptionState.status == SubscriptionStatus.premiumActive;

  if (userId == null && !isGuest) {
    print(
        "BibleSearchMiddleware: Usuário nem logado, nem convidado. Busca bíblica cancelada.");
    if (currentContext != null && currentContext.mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text(
                'Você precisa estar logado ou continuar como convidado para buscar na Bíblia.')),
      );
    }
    return; // Não prossegue com a busca
  }

  // Usuários Premium não pagam pela busca
  if (!isPremium) {
    print(
        "BibleSearchMiddleware: Usuário não é premium. Verificando moedas para busca bíblica...");
    if (userCoins < BIBLE_SEARCH_COST) {
      print(
          "BibleSearchMiddleware: Moedas insuficientes ($userCoins) para busca bíblica (custo: $BIBLE_SEARCH_COST).");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
                'Moedas insuficientes para buscar. Você tem $userCoins, são necessárias $BIBLE_SEARCH_COST.'),
            action: SnackBarAction(
              label: 'Ganhar Moedas',
              onPressed: () {
                store.dispatch(RequestRewardedAdAction());
              },
            ),
          ),
        );
      }
      store.dispatch(SearchBibleSemanticFailureAction('Moedas insuficientes.'));
      return; // Não prossegue com a busca
    }

    // Se tem moedas suficientes (e não é premium), deduz as moedas
    print(
        "BibleSearchMiddleware: Deduzindo $BIBLE_SEARCH_COST moedas do usuário/convidado.");

    int newCoinTotal = userCoins - BIBLE_SEARCH_COST;
    store.dispatch(UpdateUserCoinsAction(newCoinTotal)); // Atualiza o Redux

    if (userId != null) {
      // Usuário Logado
      final firestoreService = FirestoreService();
      try {
        await firestoreService.updateUserField(
            userId, 'userCoins', newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas deduzidas (usuário logado) com sucesso. Novo total: $newCoinTotal");
      } catch (e) {
        print(
            "BibleSearchMiddleware: Erro ao deduzir moedas do Firestore para usuário logado: $e");
        store.dispatch(SearchBibleSemanticFailureAction(
            'Erro ao processar custo da busca bíblica.'));
        return;
      }
    } else if (isGuest) {
      // Usuário Convidado
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(guestUserCoinsPrefsKeyForBibleSearch, newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas deduzidas (convidado) com sucesso. Novo total: $newCoinTotal");
      } catch (e) {
        print(
            "BibleSearchMiddleware: Erro ao salvar moedas do convidado no SharedPreferences: $e");
        store.dispatch(SearchBibleSemanticFailureAction(
            'Erro ao processar custo da busca bíblica.'));
        return;
      }
    }

    if (currentContext != null && currentContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text(
                    '$BIBLE_SEARCH_COST moedas usadas para a busca bíblica.')),
          );
        }
      });
    }
  } else {
    print(
        "BibleSearchMiddleware: Usuário é premium. Busca bíblica sem custo de moedas.");
  }
  // --- FIM DA LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---

  // Passa a ação para o reducer (para atualizar isLoading, currentQuery, etc.)
  next(action);

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
      'topK': 30,
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
