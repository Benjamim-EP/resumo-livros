// lib/redux/middleware/bible_search_middleware.dart
import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart'; // Para SubscriptionStatus
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:septima_biblia/main.dart'; // Para navigatorKey
import 'package:septima_biblia/redux/actions.dart'; // Para UpdateUserCoinsAction, RequestRewardedAdAction
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Para DateFormat

const int BIBLE_SEARCH_COST = 3;
const String guestUserCoinsPrefsKeyForBibleSearch = 'shared_guest_user_coins';
const String _searchHistoryKeyPrefs =
    'bible_search_history_guest'; // Chave específica para histórico de convidado

// Função Helper para salvar histórico
Future<void> _saveSearchHistory(Store<AppState> store, String query,
    List<Map<String, dynamic>> results) async {
  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;

  // Atualiza o estado Redux primeiro com a nova entrada de histórico
  store.dispatch(AddSearchToHistoryAction(query: query, results: results));

  // Pega o histórico atualizado do Redux para persistir
  final List<Map<String, dynamic>> currentHistoryToPersist =
      store.state.bibleSearchState.searchHistory;

  if (userId != null) {
    // Usuário Logado
    final firestoreService = FirestoreService();
    try {
      // Abordagem Simples (campo array no documento do usuário):
      // CUIDADO: Documentos do Firestore têm limite de tamanho (1MB).
      // Se o histórico + resultados se tornarem muito grandes, considere uma subcoleção.
      await firestoreService.updateUserField(
          userId, 'bibleSearchHistory', currentHistoryToPersist);
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica salvo no Firestore para usuário $userId.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao salvar histórico de busca bíblica no Firestore: $e");
    }
  } else if (isGuest) {
    // Usuário Convidado
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(currentHistoryToPersist);
      await prefs.setString(_searchHistoryKeyPrefs, historyJson);
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica salvo no SharedPreferences para convidado.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao salvar histórico de busca bíblica no SharedPreferences: $e");
    }
  }
}

// Handler para carregar o histórico
void _handleLoadSearchHistory(Store<AppState> store,
    LoadSearchHistoryAction action, NextDispatcher next) async {
  next(action); // Reducer pode setar isLoadingHistory = true

  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;
  List<Map<String, dynamic>> history = [];

  if (userId != null) {
    // Usuário Logado
    final firestoreService = FirestoreService();
    try {
      final userDoc = await firestoreService.getUserDetails(userId);
      if (userDoc != null && userDoc['bibleSearchHistory'] is List) {
        history = List<Map<String, dynamic>>.from(
            userDoc['bibleSearchHistory'] as List<dynamic>);
      }
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica carregado do Firestore para $userId.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao carregar histórico de busca bíblica do Firestore para $userId: $e");
    }
  } else if (isGuest) {
    // Usuário Convidado
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_searchHistoryKeyPrefs);
      if (historyJson != null) {
        final List<dynamic> decodedList = jsonDecode(historyJson);
        history = decodedList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica carregado do SharedPreferences para convidado.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao carregar histórico de busca bíblica do SharedPreferences para convidado: $e");
    }
  }

  // Ordena por timestamp (descendente) se o timestamp foi salvo corretamente
  history.sort((a, b) {
    final DateTime? timeA = DateTime.tryParse(a['timestamp'] as String? ?? '');
    final DateTime? timeB = DateTime.tryParse(b['timestamp'] as String? ?? '');
    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1; // Nulos no final
    if (timeB == null) return -1;
    return timeB.compareTo(timeA); // Mais recente primeiro
  });

  store.dispatch(SearchHistoryLoadedAction(history));
}

void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  if (store.state.bibleSearchState.isLoading ||
      store.state.bibleSearchState.isProcessingPayment) {
    print(
        "BibleSearchMiddleware: Busca ou pagamento/dedução já em andamento. Nova solicitação ignorada para query: '${action.query}'.");
    return;
  }

  next(action); // Reducer define isLoading e isProcessingPayment para true

  final BuildContext? currentContext = navigatorKey.currentContext;
  final UserState currentUserState = store.state.userState;

  final String? userId = currentUserState.userId;
  final bool isGuest = currentUserState.isGuestUser;
  final int userCoins = currentUserState.userCoins;
  final bool isPremium =
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
    store.dispatch(SearchBibleSemanticFailureAction(
        'Usuário não autenticado ou convidado.'));
    return;
  }

  if (!isPremium) {
    print(
        "BibleSearchMiddleware: Usuário não é premium. Verificando moedas... Moedas: $userCoins, Custo: $BIBLE_SEARCH_COST");
    if (userCoins < BIBLE_SEARCH_COST) {
      print(
          "BibleSearchMiddleware: Moedas insuficientes ($userCoins). Custo: $BIBLE_SEARCH_COST.");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
                'Moedas insuficientes. Você tem $userCoins, são necessárias $BIBLE_SEARCH_COST.'),
            action: SnackBarAction(
                label: 'Ganhar Moedas',
                onPressed: () => store.dispatch(RequestRewardedAdAction())),
          ),
        );
      }
      store.dispatch(SearchBibleSemanticFailureAction('Moedas insuficientes.'));
      return;
    }

    print("BibleSearchMiddleware: Deduzindo $BIBLE_SEARCH_COST moedas.");
    int newCoinTotal = userCoins - BIBLE_SEARCH_COST;
    store.dispatch(UpdateUserCoinsAction(newCoinTotal));

    String? errorPersistence;
    if (userId != null) {
      final firestoreService = FirestoreService();
      try {
        await firestoreService.updateUserField(
            userId, 'userCoins', newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas (logado) atualizadas no Firestore: $newCoinTotal");
      } catch (e) {
        errorPersistence = "Erro ao deduzir moedas do Firestore (logado): $e";
      }
    } else if (isGuest) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(guestUserCoinsPrefsKeyForBibleSearch, newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas (convidado) atualizadas no SharedPreferences: $newCoinTotal");
      } catch (e) {
        errorPersistence =
            "Erro ao salvar moedas do convidado (SharedPreferences): $e";
      }
    }

    if (errorPersistence != null) {
      print("BibleSearchMiddleware: $errorPersistence");
      store.dispatch(SearchBibleSemanticFailureAction(
          'Erro ao processar custo da busca.'));
      // Opcional: reverter a atualização de moedas no Redux se a persistência falhar
      // store.dispatch(UpdateUserCoinsAction(userCoins));
      return;
    }

    if (currentContext != null && currentContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content:
                    Text('$BIBLE_SEARCH_COST moedas usadas para a busca.')),
          );
        }
      });
    }
  } else {
    print(
        "BibleSearchMiddleware: Usuário é premium. Busca sem custo de moedas.");
  }

  try {
    print(
        'BibleSearchMiddleware: Iniciando chamada da Cloud Function para query="${action.query}"...');
    final functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_bible_search');

    final requestData = {
      'query': action.query,
      'filters': store.state.bibleSearchState.activeFilters,
      'topK': 30,
    };

    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    List<Map<String, dynamic>> resultsList = [];
    final dynamic rawResults = response.data?['results'];

    if (rawResults is List) {
      resultsList = rawResults
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item.isNotEmpty)
          .toList();
      print(
          'BibleSearchMiddleware: Resultados da CF processados: ${resultsList.length} itens.');
    } else if (rawResults != null) {
      print(
          'BibleSearchMiddleware: "results" da CF não é uma lista. Tipo: ${rawResults.runtimeType}');
    } else {
      print('BibleSearchMiddleware: "results" da CF é nulo.');
    }

    if (resultsList.isNotEmpty) {
      await _saveSearchHistory(store, action.query, resultsList);
    }

    store.dispatch(SearchBibleSemanticSuccessAction(resultsList));
  } on FirebaseFunctionsException catch (e) {
    print(
        "BibleSearchMiddleware: Erro FirebaseFunctionsException (CF): code=${e.code}, message=${e.message}, details=${e.details}");
    store.dispatch(SearchBibleSemanticFailureAction(
        "Erro na busca (${e.code}): ${e.message ?? 'Falha no servidor.'}"));
  } catch (e) {
    print("BibleSearchMiddleware: Erro inesperado na chamada da CF: $e");
    store.dispatch(SearchBibleSemanticFailureAction(
        "Ocorreu um erro desconhecido durante a busca."));
  }
}

List<Middleware<AppState>> createBibleSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchBibleSemanticAction>(
            _handleSearchBibleSemantic)
        .call,
    TypedMiddleware<AppState, LoadSearchHistoryAction>(_handleLoadSearchHistory)
        .call,
  ];
}
