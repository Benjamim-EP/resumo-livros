// lib/redux/middleware/sermon_search_middleware.dart
import 'dart:convert'; // Para jsonEncode e jsonDecode
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart'; // Para SubscriptionStatus
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:septima_biblia/main.dart'; // Para navigatorKey
import 'package:septima_biblia/redux/actions.dart'; // Para UpdateUserCoinsAction, RequestRewardedAdAction
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Para DateFormat
import 'package:septima_biblia/consts.dart'; // <<< IMPORTAR ARQUIVO DE CONSTANTES GLOBAIS

// Custo da busca de sermões
const int SERMON_SEARCH_COST = 3;
// Não precisa definir guestUserCoinsPrefsKey aqui se estiver importando de consts.dart

// Chave específica para o histórico de busca de sermões do convidado no SharedPreferences
const String _sermonSearchHistoryKeyPrefsGuest = 'sermon_search_history_guest';

// Função Helper para salvar histórico de sermões
Future<void> _saveSermonSearchHistory(Store<AppState> store, String query,
    List<Map<String, dynamic>> results) async {
  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;

  // Atualiza o estado Redux primeiro com a nova entrada de histórico
  // O reducer (sermonSearchReducer) cuidará de adicionar e limitar a 30 itens.
  store
      .dispatch(AddSermonSearchToHistoryAction(query: query, results: results));

  // Pega o histórico atualizado do Redux para persistir
  final List<Map<String, dynamic>> currentHistoryToPersist =
      store.state.sermonSearchState.searchHistory;

  if (userId != null) {
    // Usuário Logado
    final firestoreService = FirestoreService();
    try {
      // Salva no Firestore.
      // IMPORTANTE: Use uma chave diferente para o histórico de sermões para não sobrescrever o da Bíblia.
      await firestoreService.updateUserField(
          userId, 'sermonSearchHistory', currentHistoryToPersist);
      print(
          "SermonSearchMiddleware: Histórico de busca de sermões (limitado a ${currentHistoryToPersist.length}) salvo no Firestore para usuário $userId.");
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao salvar histórico de busca de sermões no Firestore: $e");
    }
  } else if (isGuest) {
    // Usuário Convidado
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(currentHistoryToPersist);
      await prefs.setString(_sermonSearchHistoryKeyPrefsGuest, historyJson);
      print(
          "SermonSearchMiddleware: Histórico de busca de sermões (limitado a ${currentHistoryToPersist.length}) salvo no SharedPreferences para convidado.");
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao salvar histórico de busca de sermões no SharedPreferences: $e");
    }
  }
}

// Handler para carregar o histórico de sermões
void _handleLoadSermonSearchHistory(Store<AppState> store,
    LoadSermonSearchHistoryAction action, NextDispatcher next) async {
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
      // IMPORTANTE: Use a chave correta, ex: 'sermonSearchHistory'
      if (userDoc != null && userDoc['sermonSearchHistory'] is List) {
        history = List<Map<String, dynamic>>.from(
            userDoc['sermonSearchHistory'] as List<dynamic>);
      }
      print(
          "SermonSearchMiddleware: Histórico de busca de sermões carregado do Firestore para $userId.");
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao carregar histórico de busca de sermões do Firestore para $userId: $e");
    }
  } else if (isGuest) {
    // Usuário Convidado
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson =
          prefs.getString(_sermonSearchHistoryKeyPrefsGuest);
      if (historyJson != null) {
        final List<dynamic> decodedList = jsonDecode(historyJson);
        history = decodedList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      print(
          "SermonSearchMiddleware: Histórico de busca de sermões carregado do SharedPreferences para convidado.");
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao carregar histórico de busca de sermões do SharedPreferences para convidado: $e");
    }
  }

  history.sort((a, b) {
    final DateTime? timeA = DateTime.tryParse(a['timestamp'] as String? ?? '');
    final DateTime? timeB = DateTime.tryParse(b['timestamp'] as String? ?? '');
    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;
    return timeB.compareTo(timeA); // Mais recente primeiro
  });

  store.dispatch(SermonSearchHistoryLoadedAction(history));
}

// Handler para a ação de buscar sermões
void _handleSearchSermons(
  Store<AppState> store,
  SearchSermonsAction action,
  NextDispatcher next,
) async {
  // 1. Verifica se uma busca ou seu processamento de custo já está em andamento.
  if (store.state.sermonSearchState.isLoading ||
      store.state.sermonSearchState.isProcessingPayment) {
    print(
        "SermonSearchMiddleware: Busca de sermões ou pagamento/dedução já em andamento. Nova solicitação ignorada para query: '${action.query}'.");
    return;
  }

  // 2. Despacha a ação para o reducer (que seta isLoading e isProcessingPayment para true).
  next(action);

  // 3. Prepara variáveis e pega o estado atualizado.
  final BuildContext? currentContext = navigatorKey.currentContext;
  final UserState currentUserState = store.state.userState;

  final String? userId = currentUserState.userId;
  final bool isGuest = currentUserState.isGuestUser;
  final int userCoins = currentUserState.userCoins;
  final bool isPremium =
      store.state.subscriptionState.status == SubscriptionStatus.premiumActive;

  if (userId == null && !isGuest) {
    print(
        "SermonSearchMiddleware: Usuário nem logado, nem convidado. Busca de sermões cancelada.");
    if (currentContext != null && currentContext.mounted) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
            content: Text(
                'Você precisa estar logado ou continuar como convidado para buscar sermões.')),
      );
    }
    store.dispatch(
        SearchSermonsFailureAction("Usuário não autenticado ou convidado."));
    return;
  }

  // --- LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---
  if (!isPremium) {
    print(
        "SermonSearchMiddleware: Usuário não é premium. Verificando moedas... Moedas: $userCoins, Custo: $SERMON_SEARCH_COST");
    if (userCoins < SERMON_SEARCH_COST) {
      print(
          "SermonSearchMiddleware: Moedas insuficientes ($userCoins). Custo: $SERMON_SEARCH_COST.");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(
                'Moedas insuficientes para buscar sermões. Você tem $userCoins, são necessárias $SERMON_SEARCH_COST.'),
            action: SnackBarAction(
                label: 'Ganhar Moedas',
                onPressed: () => store.dispatch(RequestRewardedAdAction())),
          ),
        );
      }
      store.dispatch(SearchSermonsFailureAction('Moedas insuficientes.'));
      return;
    }

    print("SermonSearchMiddleware: Deduzindo $SERMON_SEARCH_COST moedas.");
    int newCoinTotal = userCoins - SERMON_SEARCH_COST;
    store.dispatch(
        UpdateUserCoinsAction(newCoinTotal)); // Atualiza o Redux imediatamente

    String? errorPersistence;
    if (userId != null) {
      // Usuário Logado
      final firestoreService = FirestoreService();
      try {
        await firestoreService.updateUserField(
            userId, 'userCoins', newCoinTotal);
        print(
            "SermonSearchMiddleware: Moedas (logado) atualizadas no Firestore: $newCoinTotal");
      } catch (e) {
        errorPersistence = "Erro ao deduzir moedas (Firestore): $e";
      }
    } else if (isGuest) {
      // Usuário Convidado
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
            guestUserCoinsPrefsKey, newCoinTotal); // <<< USA A CONSTANTE GLOBAL
        print(
            "SermonSearchMiddleware: Moedas (convidado) atualizadas no SharedPreferences: $newCoinTotal usando a chave '$guestUserCoinsPrefsKey'");
      } catch (e) {
        errorPersistence = "Erro ao salvar moedas (SharedPreferences): $e";
      }
    }

    if (errorPersistence != null) {
      print("SermonSearchMiddleware: $errorPersistence");
      store.dispatch(SearchSermonsFailureAction(
          'Erro ao processar custo da busca de sermões.'));
      return;
    }
    if (currentContext != null && currentContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentContext.mounted) {
          // Verifica novamente
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
                content: Text(
                    '$SERMON_SEARCH_COST moedas usadas para a busca de sermões.')),
          );
        }
      });
    }
  } else {
    print(
        "SermonSearchMiddleware: Usuário é premium. Busca de sermões sem custo.");
  }
  // --- FIM DA LÓGICA DE CUSTO ---

  // 4. Executa a busca real (chamada da Cloud Function)
  try {
    print(
        'SermonSearchMiddleware: Iniciando chamada da CF para query="${action.query}", topKSermons=${action.topKSermons}, topKParagraphs=${action.topKParagraphs}');
    final FirebaseFunctions functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_sermon_search');

    final requestData = {
      'query': action.query,
      'topKSermons': action.topKSermons,
      'topKParagraphs': action.topKParagraphs,
      // 'filters': action.filters, // Se você tiver filtros para sermões
    };

    print(
        'SermonSearchMiddleware: Chamando Cloud Function "semantic_sermon_search" com dados: $requestData');
    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    List<Map<String, dynamic>> resultsList = [];
    final dynamic rawResults = response.data?['sermons'];

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
      print(
          'SermonSearchMiddleware: Resultados de sermões da CF processados: ${resultsList.length} itens.');
    } else if (rawResults != null) {
      print(
          'SermonSearchMiddleware: "sermons" da CF não é uma lista. Tipo: ${rawResults.runtimeType}');
    } else {
      print('SermonSearchMiddleware: "sermons" da CF é nulo.');
    }

    if (resultsList.isNotEmpty) {
      await _saveSermonSearchHistory(store, action.query, resultsList);
    }

    store.dispatch(SearchSermonsSuccessAction(resultsList));
  } on FirebaseFunctionsException catch (e) {
    print(
        "SermonSearchMiddleware: Erro FirebaseFunctionsException (CF): code=${e.code}, message=${e.message}, details=${e.details}");
    store.dispatch(SearchSermonsFailureAction(
        "Erro na busca de sermões (${e.code}): ${e.message ?? 'Falha no servidor.'}"));
  } catch (e) {
    print("SermonSearchMiddleware: Erro inesperado na chamada da CF: $e");
    store.dispatch(SearchSermonsFailureAction(
        "Ocorreu um erro desconhecido durante a busca de sermões."));
  }
}

List<Middleware<AppState>> createSermonSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchSermonsAction>(_handleSearchSermons).call,
    TypedMiddleware<AppState, LoadSermonSearchHistoryAction>(
            _handleLoadSermonSearchHistory)
        .call,
  ];
}
