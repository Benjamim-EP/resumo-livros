// lib/redux/middleware/sermon_search_middleware.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custo em moedas para realizar a busca semântica de sermões
const int SERMON_SEARCH_COST = 3;

// Chave específica para o histórico de busca de sermões do convidado
const String _sermonSearchHistoryKeyPrefsGuest = 'sermon_search_history_guest';

/// Cria a lista de middlewares responsáveis pela busca de sermões.
List<Middleware<AppState>> createSermonSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchSermonsAction>(_handleSearchSermons).call,
    TypedMiddleware<AppState, LoadSermonSearchHistoryAction>(
            _handleLoadSermonSearchHistory)
        .call,
  ];
}

/// Handler principal que executa a busca de sermões, gerenciando custos e erros.
void _handleSearchSermons(Store<AppState> store, SearchSermonsAction action,
    NextDispatcher next) async {
  // Evita buscas duplicadas
  if (store.state.sermonSearchState.isLoading) {
    print(
        "SermonSearchMiddleware: Busca de sermões já em andamento. Ignorando.");
    return;
  }

  next(
      action); // Reducer vai setar isLoading = true e isProcessingPayment = true

  final BuildContext? currentContext = navigatorKey.currentContext;
  final UserState currentUserState = store.state.userState;

  final String? userId = currentUserState.userId;
  final bool isGuest = currentUserState.isGuestUser;
  final int originalUserCoins = currentUserState.userCoins;
  final bool isPremium =
      store.state.subscriptionState.status == SubscriptionStatus.premiumActive;

  bool coinsWereDeducted = false;

  // --- LÓGICA DE CUSTO ---
  if (!isPremium) {
    if (originalUserCoins < SERMON_SEARCH_COST) {
      print(
          "SermonSearchMiddleware: Moedas insuficientes ($originalUserCoins). Custo: $SERMON_SEARCH_COST.");
      store.dispatch(SearchSermonsFailureAction('Moedas insuficientes.'));
      if (currentContext != null && currentContext.mounted) {
        CustomNotificationService.showWarningWithAction(
          context: currentContext,
          message:
              'Você tem $originalUserCoins, são necessárias $SERMON_SEARCH_COST para buscar sermões.',
          buttonText: 'Ganhar Moedas',
          onButtonPressed: () => store.dispatch(RequestRewardedAdAction()),
        );
      }
      return;
    }

    // Deduz moedas otimisticamente
    print("SermonSearchMiddleware: Deduzindo $SERMON_SEARCH_COST moedas.");
    int newCoinTotal = originalUserCoins - SERMON_SEARCH_COST;
    store.dispatch(UpdateUserCoinsAction(newCoinTotal));
    coinsWereDeducted = true;

    // Persiste a dedução no backend
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
      print("SermonSearchMiddleware: Erro ao persistir dedução de moedas: $e");
      store.dispatch(SearchSermonsFailureAction(
          'Erro ao processar custo da busca de sermões.'));
      _reimburseSermonCoins(
          store, userId, isGuest, originalUserCoins); // Reembolsa
      return;
    }
  }

  // --- CHAMADA DA CLOUD FUNCTION ---
  try {
    print(
        'SermonSearchMiddleware: Iniciando chamada da CF para query="${action.query}"...');
    final FirebaseFunctions functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_sermon_search');

    final requestData = {
      'query': action.query,
      'topKSermons': action.topKSermons,
      'topKParagraphs': action.topKParagraphs,
    };

    final HttpsCallableResult<dynamic> response =
        await callable.call<Map<String, dynamic>>(requestData);

    List<Map<String, dynamic>> resultsList = [];
    final dynamic rawResults = response.data?['sermons'];

    if (rawResults is List) {
      resultsList = rawResults
          .map((item) => Map<String, dynamic>.from(item as Map))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (resultsList.isNotEmpty) {
      await _saveSermonSearchHistory(store, action.query, resultsList);
    }

    store.dispatch(SearchSermonsSuccessAction(resultsList));
    print('SermonSearchMiddleware: Busca de sermões bem-sucedida.');
  } on FirebaseFunctionsException catch (e) {
    print(
        "SermonSearchMiddleware: Erro FirebaseFunctionsException (CF): code=${e.code}, message=${e.message}");
    store.dispatch(SearchSermonsFailureAction(
        "Erro na busca de sermões (${e.code}): ${e.message ?? 'Falha no servidor.'}"));

    if (coinsWereDeducted) {
      _reimburseSermonCoins(store, userId, isGuest, originalUserCoins);
    }
  } catch (e) {
    print("SermonSearchMiddleware: Erro inesperado na chamada da CF: $e");
    store.dispatch(SearchSermonsFailureAction(
        "Ocorreu um erro desconhecido durante a busca de sermões."));

    if (coinsWereDeducted) {
      _reimburseSermonCoins(store, userId, isGuest, originalUserCoins);
    }
  }
}

/// Função auxiliar para reembolsar moedas em caso de falha na busca de sermões.
void _reimburseSermonCoins(Store<AppState> store, String? userId, bool isGuest,
    int originalCoinAmount) async {
  print(
      "SermonSearchMiddleware: Reembolsando moedas devido a erro. Valor original: $originalCoinAmount");

  store.dispatch(UpdateUserCoinsAction(originalCoinAmount));

  try {
    if (userId != null) {
      final firestoreService = FirestoreService();
      await firestoreService.updateUserField(
          userId, 'userCoins', originalCoinAmount);
      print(
          "SermonSearchMiddleware: Moedas (logado) reembolsadas no Firestore: $originalCoinAmount");
    } else if (isGuest) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(guestUserCoinsPrefsKey, originalCoinAmount);
      print(
          "SermonSearchMiddleware: Moedas (convidado) reembolsadas no SharedPreferences: $originalCoinAmount");
    }
  } catch (e) {
    print(
        "SermonSearchMiddleware: Erro CRÍTICO ao persistir reembolso de moedas: $e");
  }

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

/// Carrega o histórico de buscas de sermões.
void _handleLoadSermonSearchHistory(Store<AppState> store,
    LoadSermonSearchHistoryAction action, NextDispatcher next) async {
  next(action);

  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;
  List<Map<String, dynamic>> history = [];

  if (userId != null) {
    final firestoreService = FirestoreService();
    try {
      final userDoc = await firestoreService.getUserDetails(userId);
      if (userDoc != null && userDoc['sermonSearchHistory'] is List) {
        history = List<Map<String, dynamic>>.from(
            userDoc['sermonSearchHistory'] as List<dynamic>);
      }
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao carregar histórico de sermões do Firestore: $e");
    }
  } else if (isGuest) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson =
          prefs.getString(_sermonSearchHistoryKeyPrefsGuest);
      if (historyJson != null) {
        history = (jsonDecode(historyJson) as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao carregar histórico de sermões do SharedPreferences: $e");
    }
  }

  history.sort((a, b) =>
      (DateTime.tryParse(b['timestamp'] as String? ?? '') ?? DateTime(1900))
          .compareTo(DateTime.tryParse(a['timestamp'] as String? ?? '') ??
              DateTime(1900)));

  store.dispatch(SermonSearchHistoryLoadedAction(history));
}

/// Salva o histórico de buscas de sermões.
Future<void> _saveSermonSearchHistory(Store<AppState> store, String query,
    List<Map<String, dynamic>> results) async {
  store
      .dispatch(AddSermonSearchToHistoryAction(query: query, results: results));

  final List<Map<String, dynamic>> historyToPersist =
      store.state.sermonSearchState.searchHistory;
  final userState = store.state.userState;
  final userId = userState.userId;
  final isGuest = userState.isGuestUser;

  if (userId != null) {
    final firestoreService = FirestoreService();
    try {
      await firestoreService.updateUserField(
          userId, 'sermonSearchHistory', historyToPersist);
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao salvar histórico de sermões no Firestore: $e");
    }
  } else if (isGuest) {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _sermonSearchHistoryKeyPrefsGuest, jsonEncode(historyToPersist));
    } catch (e) {
      print(
          "SermonSearchMiddleware: Erro ao salvar histórico de sermões no SharedPreferences: $e");
    }
  }
}
