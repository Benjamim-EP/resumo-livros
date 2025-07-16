// lib/redux/middleware/bible_search_middleware.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custo em moedas para realizar a busca semântica na Bíblia
const int BIBLE_SEARCH_COST = 3;

// Chave específica para o histórico de busca bíblica do convidado no SharedPreferences
const String _bibleSearchHistoryKeyPrefsGuest = 'bible_search_history_guest';

/// Cria a lista de middlewares responsáveis pela busca semântica na Bíblia.
List<Middleware<AppState>> createBibleSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchBibleSemanticAction>(
            _handleSearchBibleSemantic)
        .call,
    TypedMiddleware<AppState, LoadSearchHistoryAction>(_handleLoadSearchHistory)
        .call,
  ];
}

/// Handler principal que executa a busca semântica, gerenciando custos e erros.
void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  // Evita buscas duplicadas se uma já estiver em andamento
  if (store.state.bibleSearchState.isLoading) {
    print(
        "BibleSearchMiddleware: Busca já em andamento. Nova solicitação ignorada para query: '${action.query}'.");
    return;
  }

  // >>> PASSO DE ANALYTICS <<<
  // Registra que uma busca foi iniciada.
  AnalyticsService.instance.logSearch(action.query, 'bible_semantic');

  // Despacha a ação para o reducer, que setará isLoading = true
  // e isProcessingPayment = true
  next(action);

  final BuildContext? currentContext = navigatorKey.currentContext;
  final UserState currentUserState = store.state.userState;
  final String? userId = currentUserState.userId;
  final bool isGuest = currentUserState.isGuestUser;
  final int originalUserCoins = currentUserState.userCoins;
  final bool isPremium =
      store.state.subscriptionState.status == SubscriptionStatus.premiumActive;

  bool coinsWereDeducted = false;

  // --- 1. LÓGICA DE CUSTO E VALIDAÇÃO ---
  if (!isPremium) {
    if (originalUserCoins < BIBLE_SEARCH_COST) {
      print(
          "BibleSearchMiddleware: Moedas insuficientes ($originalUserCoins). Custo: $BIBLE_SEARCH_COST.");
      store.dispatch(SearchBibleSemanticFailureAction('Moedas insuficientes.'));

      if (currentContext != null && currentContext.mounted) {
        CustomNotificationService.showWarningWithAction(
          context: currentContext,
          message:
              'Você tem $originalUserCoins, são necessárias $BIBLE_SEARCH_COST para esta busca.',
          buttonText: 'Ganhar Moedas',
          onButtonPressed: () => store.dispatch(RequestRewardedAdAction()),
        );
      }
      return; // Interrompe a execução
    }

    // Deduz as moedas otimisticamente para a UI e persiste no backend
    print("BibleSearchMiddleware: Deduzindo $BIBLE_SEARCH_COST moedas.");
    int newCoinTotal = originalUserCoins - BIBLE_SEARCH_COST;
    store.dispatch(UpdateUserCoinsAction(newCoinTotal));
    coinsWereDeducted = true;

    final firestoreService = FirestoreService();
    try {
      if (userId != null) {
        await firestoreService.updateUserField(
            userId, 'userCoins', newCoinTotal);
      } else if (isGuest) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(guestUserCoinsPrefsKey, newCoinTotal);
      }
    } catch (e) {
      print("BibleSearchMiddleware: Erro ao persistir dedução de moedas: $e");
      store.dispatch(SearchBibleSemanticFailureAction(
          'Erro ao processar custo da busca.'));
      // Se a persistência falhar, reembolsa as moedas imediatamente
      _reimburseCoins(store, userId, isGuest, originalUserCoins);
      return; // Interrompe a execução
    }
  }

  // --- 2. CHAMADA DA CLOUD FUNCTION ---
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
      'topK': 30, // Você pode ajustar este valor conforme necessário
    };

    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    // --- 3. PROCESSAMENTO DO SUCESSO ---
    List<Map<String, dynamic>> resultsList = [];
    final dynamic rawResults = response.data?['results'];

    if (rawResults is List) {
      resultsList = rawResults
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Salva a busca no histórico antes de despachar o sucesso
    if (resultsList.isNotEmpty) {
      await _saveSearchHistory(store, action.query, resultsList);
    }

    store.dispatch(SearchBibleSemanticSuccessAction(resultsList));
    print('BibleSearchMiddleware: Busca semântica bem-sucedida.');
  } on FirebaseFunctionsException catch (e) {
    // --- 4. TRATAMENTO DE ERROS DA CLOUD FUNCTION ---
    print(
        "BibleSearchMiddleware: Erro FirebaseFunctionsException (CF): code=${e.code}, message=${e.message}");
    final userFriendlyMessage =
        e.message ?? 'Falha na comunicação com o servidor. Tente novamente.';
    store.dispatch(SearchBibleSemanticFailureAction(
        "Erro na busca (${e.code}): $userFriendlyMessage"));

    if (coinsWereDeducted) {
      _reimburseCoins(store, userId, isGuest, originalUserCoins);
    }
  } catch (e) {
    // --- 5. TRATAMENTO DE ERROS GENÉRICOS (REDE, ETC.) ---
    print("BibleSearchMiddleware: Erro inesperado na chamada da CF: $e");
    store.dispatch(SearchBibleSemanticFailureAction(
        "Ocorreu um erro de conexão. Verifique sua internet e tente novamente."));

    if (coinsWereDeducted) {
      _reimburseCoins(store, userId, isGuest, originalUserCoins);
    }
  }
}

/// Função auxiliar para reembolsar moedas ao usuário em caso de falha na busca.
void _reimburseCoins(Store<AppState> store, String? userId, bool isGuest,
    int originalCoinAmount) async {
  print(
      "BibleSearchMiddleware: Reembolsando moedas devido a erro. Valor original: $originalCoinAmount");

  // 1. Atualiza o estado do Redux para o valor original
  store.dispatch(UpdateUserCoinsAction(originalCoinAmount));

  // 2. Persiste a devolução no backend/local storage
  try {
    if (userId != null) {
      final firestoreService = FirestoreService();
      await firestoreService.updateUserField(
          userId, 'userCoins', originalCoinAmount);
      print(
          "BibleSearchMiddleware: Moedas (logado) reembolsadas no Firestore: $originalCoinAmount");
    } else if (isGuest) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(guestUserCoinsPrefsKey, originalCoinAmount);
      print(
          "BibleSearchMiddleware: Moedas (convidado) reembolsadas no SharedPreferences: $originalCoinAmount");
    }
  } catch (e) {
    print(
        "BibleSearchMiddleware: Erro CRÍTICO ao persistir reembolso de moedas: $e");
  }

  // 3. Notifica o usuário (opcional, mas recomendado)
  final context = navigatorKey.currentContext;
  if (context != null && context.mounted) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        CustomNotificationService.showError(
          context,
          'Suas moedas foram devolvidas devido a um erro na busca.',
        );
      }
    });
  }
}

/// Carrega o histórico de buscas do Firestore (se logado) ou SharedPreferences (se convidado).
void _handleLoadSearchHistory(Store<AppState> store,
    LoadSearchHistoryAction action, NextDispatcher next) async {
  next(action); // Reducer pode setar isLoadingHistory = true

  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;
  List<Map<String, dynamic>> history = [];

  if (userId != null) {
    final firestoreService = FirestoreService();
    try {
      final userDoc = await firestoreService.getUserDetails(userId);
      if (userDoc != null && userDoc['bibleSearchHistory'] is List) {
        history = List<Map<String, dynamic>>.from(
            userDoc['bibleSearchHistory'] as List<dynamic>);
      }
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao carregar histórico de busca do Firestore: $e");
    }
  } else if (isGuest) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson =
          prefs.getString(_bibleSearchHistoryKeyPrefsGuest);
      if (historyJson != null) {
        final List<dynamic> decodedList = jsonDecode(historyJson);
        history = decodedList
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao carregar histórico de busca do SharedPreferences: $e");
    }
  }

  // Ordena o histórico pela data, do mais recente para o mais antigo.
  history.sort((a, b) {
    final DateTime? timeA = DateTime.tryParse(a['timestamp'] as String? ?? '');
    final DateTime? timeB = DateTime.tryParse(b['timestamp'] as String? ?? '');
    if (timeA == null && timeB == null) return 0;
    if (timeA == null) return 1;
    if (timeB == null) return -1;
    return timeB.compareTo(timeA);
  });

  store.dispatch(SearchHistoryLoadedAction(history));
}

/// Salva o histórico de buscas no local apropriado (Firestore ou SharedPreferences).
Future<void> _saveSearchHistory(Store<AppState> store, String query,
    List<Map<String, dynamic>> results) async {
  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;

  // Primeiro, atualiza o estado do Redux. O reducer já limita a lista a 50 itens.
  store.dispatch(AddSearchToHistoryAction(query: query, results: results));

  // Pega o histórico ATUALIZADO do Redux para persistir.
  final List<Map<String, dynamic>> currentHistoryToPersist =
      store.state.bibleSearchState.searchHistory;

  if (userId != null) {
    final firestoreService = FirestoreService();
    try {
      await firestoreService.updateUserField(
          userId, 'bibleSearchHistory', currentHistoryToPersist);
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica salvo no Firestore.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao salvar histórico de busca bíblica no Firestore: $e");
    }
  } else if (isGuest) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String historyJson = jsonEncode(currentHistoryToPersist);
      await prefs.setString(_bibleSearchHistoryKeyPrefsGuest, historyJson);
      print(
          "BibleSearchMiddleware: Histórico de busca bíblica salvo no SharedPreferences para convidado.");
    } catch (e) {
      print(
          "BibleSearchMiddleware: Erro ao salvar histórico de busca bíblica no SharedPreferences: $e");
    }
  }
}
