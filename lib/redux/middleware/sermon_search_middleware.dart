// lib/redux/middleware/sermon_search_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart'; // Suas ações de busca de sermões
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Para AppState
// Não é necessário importar FirestoreService ou OpenAIService aqui, pois a Cloud Function faz o trabalho pesado.

const int SERMON_SEARCH_COST = 3;
const String _guestUserCoinsPrefsKey = 'sermon_search_guest_user_coins';

List<Middleware<AppState>> createSermonSearchMiddleware() {
  final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: "southamerica-east1");

  // Handler para a ação de buscar sermões
// Handler para a ação de buscar sermões
  void _handleSearchSermons(
    Store<AppState> store,
    SearchSermonsAction action,
    NextDispatcher next,
  ) async {
    // --- INÍCIO DA LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---
    final BuildContext? currentContext = navigatorKey.currentContext;
    final userState = store.state.userState;
    final userId = userState.userId;
    final isGuest = userState.isGuestUser;
    final userCoins = userState.userCoins;
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive; // Verifica se é premium

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
      return; // Não prossegue com a busca
    }

    // Usuários Premium não pagam pela busca
    if (!isPremium) {
      print(
          "SermonSearchMiddleware: Usuário não é premium. Verificando moedas para busca de sermões...");
      if (userCoins < SERMON_SEARCH_COST) {
        print(
            "SermonSearchMiddleware: Moedas insuficientes ($userCoins) para busca de sermões (custo: $SERMON_SEARCH_COST).");
        if (currentContext != null && currentContext.mounted) {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            SnackBar(
              content: Text(
                  'Moedas insuficientes para buscar. Você tem $userCoins, são necessárias $SERMON_SEARCH_COST.'),
              action: SnackBarAction(
                label: 'Ganhar Moedas',
                onPressed: () {
                  store.dispatch(RequestRewardedAdAction());
                },
              ),
            ),
          );
        }
        store.dispatch(SearchSermonsFailureAction('Moedas insuficientes.'));
        return; // Não prossegue com a busca
      }

      // Se tem moedas suficientes (e não é premium), deduz as moedas
      print(
          "SermonSearchMiddleware: Deduzindo $SERMON_SEARCH_COST moedas do usuário/convidado.");

      int newCoinTotal = userCoins - SERMON_SEARCH_COST;
      store.dispatch(UpdateUserCoinsAction(newCoinTotal)); // Atualiza o Redux

      if (userId != null) {
        // Usuário Logado
        final firestoreService =
            FirestoreService(); // Instancie se ainda não estiver no escopo
        try {
          await firestoreService.updateUserField(
              userId, 'userCoins', newCoinTotal);
          print(
              "SermonSearchMiddleware: Moedas deduzidas (usuário logado) com sucesso. Novo total: $newCoinTotal");
        } catch (e) {
          print(
              "SermonSearchMiddleware: Erro ao deduzir moedas do Firestore para usuário logado: $e");
          store.dispatch(SearchSermonsFailureAction(
              'Erro ao processar custo da busca de sermões.'));
          return;
        }
      } else if (isGuest) {
        // Usuário Convidado
        try {
          final prefs = await SharedPreferences.getInstance();
          // >>>>> USA A NOVA CHAVE ESPECÍFICA <<<<<
          await prefs.setInt(_guestUserCoinsPrefsKey, newCoinTotal);
          print(
              "SermonSearchMiddleware: Moedas deduzidas (convidado) com sucesso. Novo total: $newCoinTotal");
        } catch (e) {
          print(
              "SermonSearchMiddleware: Erro ao salvar moedas do convidado no SharedPreferences: $e");
          store.dispatch(SearchSermonsFailureAction(
              'Erro ao processar custo da busca de sermões.'));
          return;
        }
      }

      if (currentContext != null && currentContext.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (currentContext.mounted) {
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
          "SermonSearchMiddleware: Usuário é premium. Busca de sermões sem custo de moedas.");
    }
    // --- FIM DA LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---

    // Passa a ação para o reducer (para atualizar isLoading, currentQuery, etc.)
    next(action);

    try {
      print(
          'SermonSearchMiddleware: Iniciando busca por sermões com query="${action.query}", topKSermons=${action.topKSermons}, topKParagraphs=${action.topKParagraphs}');

      final HttpsCallable callable =
          functions.httpsCallable('semantic_sermon_search');

      final requestData = {
        'query': action.query,
        'topKSermons': action.topKSermons,
        'topKParagraphs': action.topKParagraphs,
        // 'filters': action.filters, // Adicionar se você implementar filtros
      };

      print(
          'SermonSearchMiddleware: Chamando Cloud Function "semantic_sermon_search" com dados: $requestData');
      final HttpsCallableResult<dynamic> response =
          await callable.call<Map<String, dynamic>>(requestData);

      final dynamic rawResults = response.data?['sermons'];
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
            'SermonSearchMiddleware: "sermons" não é uma lista, recebido: ${rawResults.runtimeType}');
      }

      print(
          'SermonSearchMiddleware: Resultados de sermões recebidos: ${resultsList.length} itens.');
      store.dispatch(SearchSermonsSuccessAction(resultsList));
    } on FirebaseFunctionsException catch (e) {
      print(
          "SermonSearchMiddleware: Erro FirebaseFunctionsException ao chamar 'semantic_sermon_search': ${e.code} - ${e.message} - Details: ${e.details}");
      store.dispatch(SearchSermonsFailureAction(
          "Erro na busca por sermões (${e.code}): ${e.message ?? 'Falha ao contatar o servidor.'}"));
    } catch (e) {
      print("SermonSearchMiddleware: Erro inesperado ao buscar sermões: $e");
      store.dispatch(SearchSermonsFailureAction(
          "Ocorreu um erro desconhecido durante a busca por sermões."));
    }
  }

  return [
    TypedMiddleware<AppState, SearchSermonsAction>(_handleSearchSermons).call,
  ];
}
