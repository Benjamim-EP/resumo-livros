// Em: lib/redux/middleware/search_embedding_middleware.dart

import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import '../actions.dart'; // Para SearchByQueryAction, SearchSuccessAction, SearchFailureAction, UpdateUserCoinsAction, RequestRewardedAdAction
import '../store.dart'; // Para AppState
import '../../services/openai_service.dart';
import '../../services/pinecone_service.dart';
import '../../services/firestore_service.dart';
import 'package:flutter/material.dart'; // Para ScaffoldMessenger
import 'package:septima_biblia/main.dart'; // Para navigatorKey
import 'package:shared_preferences/shared_preferences.dart'; // Para SharedPreferences

// >>> DEFINA A CHAVE DE PREFERÊNCIAS PARA MOEDAS DO CONVIDADO AQUI OU IMPORTE DE UM LOCAL CENTRAL <<<
// Use a mesma chave que nos outros middlewares se o "pote" de moedas for o mesmo.
const String guestUserCoinsPrefsKeyForTopicSearch = 'shared_guest_user_coins';

const int TOPIC_SEARCH_COST = 3; // Defina o custo para esta busca específica

List<Middleware<AppState>> createSearchEmbeddingMiddleware() {
  final openAIService = OpenAIService();
  final pineconeService = PineconeService();
  final firestoreService = FirestoreService();

  return [
    TypedMiddleware<AppState, SearchByQueryAction>(_handleSearchByQuery(
            openAIService, pineconeService, firestoreService))
        .call,
  ];
}

void Function(Store<AppState>, SearchByQueryAction, NextDispatcher)
    _handleSearchByQuery(OpenAIService openAIService,
        PineconeService pineconeService, FirestoreService firestoreService) {
  return (Store<AppState> store, SearchByQueryAction action,
      NextDispatcher next) async {
    // --- INÍCIO DA LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---
    final BuildContext? currentContext = navigatorKey.currentContext;
    final userState = store.state.userState;
    final userId = userState.userId;
    final isGuest = userState.isGuestUser;
    final userCoins = userState.userCoins;
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    if (userId == null && !isGuest) {
      print(
          "SearchEmbeddingMiddleware: Usuário nem logado, nem convidado. Busca de tópicos cancelada.");
      if (currentContext != null && currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          const SnackBar(
              content: Text(
                  'Você precisa estar logado ou continuar como convidado para esta busca.')),
        );
      }
      return;
    }

    if (!isPremium) {
      print(
          "SearchEmbeddingMiddleware: Usuário não é premium. Verificando moedas para busca de tópicos...");
      if (userCoins < TOPIC_SEARCH_COST) {
        print(
            "SearchEmbeddingMiddleware: Moedas insuficientes ($userCoins) para busca de tópicos (custo: $TOPIC_SEARCH_COST).");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              content: Text(
                  'Moedas insuficientes para buscar. Você tem $userCoins, são necessárias $TOPIC_SEARCH_COST.'),
              action: SnackBarAction(
                label: 'Ganhar Moedas',
                onPressed: () {
                  store.dispatch(RequestRewardedAdAction());
                },
              ),
            ),
          );
        }
        store.dispatch(SearchFailureAction(
            'Moedas insuficientes.')); // Ação genérica de falha de busca
        return;
      }

      print(
          "SearchEmbeddingMiddleware: Deduzindo $TOPIC_SEARCH_COST moedas do usuário/convidado.");
      int newCoinTotal = userCoins - TOPIC_SEARCH_COST;
      store.dispatch(UpdateUserCoinsAction(newCoinTotal));

      if (userId != null) {
        try {
          await firestoreService.updateUserField(
              userId, 'userCoins', newCoinTotal);
          print(
              "SearchEmbeddingMiddleware: Moedas deduzidas (usuário logado) com sucesso. Novo total: $newCoinTotal");
        } catch (e) {
          print(
              "SearchEmbeddingMiddleware: Erro ao deduzir moedas do Firestore (logado): $e");
          store.dispatch(SearchFailureAction(
              'Erro ao processar custo da busca de tópicos.'));
          return;
        }
      } else if (isGuest) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
              guestUserCoinsPrefsKeyForTopicSearch, newCoinTotal);
          print(
              "SearchEmbeddingMiddleware: Moedas deduzidas (convidado) com sucesso. Novo total: $newCoinTotal");
        } catch (e) {
          print(
              "SearchEmbeddingMiddleware: Erro ao salvar moedas do convidado (SharedPreferences): $e");
          store.dispatch(SearchFailureAction(
              'Erro ao processar custo da busca de tópicos.'));
          return;
        }
      }

      if (currentContext != null && currentContext.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentContext.mounted) {
            ScaffoldMessenger.of(currentContext).showSnackBar(
              const SnackBar(
                  content: Text(
                      '$TOPIC_SEARCH_COST moedas usadas para a busca de tópicos.')),
            );
          }
        });
      }
    } else {
      print(
          "SearchEmbeddingMiddleware: Usuário é premium. Busca de tópicos sem custo.");
    }
    // --- FIM DA LÓGICA DE CUSTO ---

    next(
        action); // Despacha a ação original para o reducer (que pode setar isLoading)

    try {
      print(
          "SearchEmbeddingMiddleware: Gerando embedding para query: '${action.query}'");
      final embedding = await openAIService.generateEmbedding(action.query);

      print("SearchEmbeddingMiddleware: Consultando Pinecone com o embedding.");
      final results = await pineconeService.queryPinecone(embedding, 100);

      final topicIds = results.map((match) => match['id'] as String).toList();
      print(
          "SearchEmbeddingMiddleware: IDs de tópicos obtidos do Pinecone: $topicIds");

      List<Map<String, dynamic>> topics =
          await firestoreService.fetchTopicsByIds(topicIds);
      print(
          "SearchEmbeddingMiddleware: Detalhes dos tópicos carregados do Firestore: ${topics.length} tópicos.");

      store.dispatch(SearchSuccessAction(topics));
    } catch (e) {
      print('SearchEmbeddingMiddleware: Erro durante a busca de tópicos: $e');
      store
          .dispatch(SearchFailureAction('Erro durante a busca de tópicos: $e'));
    }
  };
}
