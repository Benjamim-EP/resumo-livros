// lib/redux/middleware/bible_search_middleware.dart
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart'; // Para SubscriptionStatus
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:septima_biblia/main.dart'; // Para navigatorKey
import 'package:septima_biblia/redux/actions.dart'; // Para UpdateUserCoinsAction, RequestRewardedAdAction
import 'package:septima_biblia/services/firestore_service.dart'; // Para FirestoreService
import 'package:shared_preferences/shared_preferences.dart'; // Para SharedPreferences

// Custo da busca semântica na Bíblia
const int BIBLE_SEARCH_COST =
    3; // Você mencionou 3, mas no código anterior estava 5. Ajuste conforme necessário.

// Chave para SharedPreferences para moedas do usuário convidado.
// Certifique-se de que esta chave seja consistente onde quer que você leia/escreva as moedas do convidado.
const String guestUserCoinsPrefsKeyForBibleSearch = 'shared_guest_user_coins';

void _handleSearchBibleSemantic(Store<AppState> store,
    SearchBibleSemanticAction action, NextDispatcher next) async {
  // 1. Verifica se uma busca (incluindo o processamento de pagamento/dedução) já está em andamento.
  //    Esta verificação usa o estado ANTES de 'next(action)' ser chamado.
  if (store.state.bibleSearchState.isLoading ||
      store.state.bibleSearchState.isProcessingPayment) {
    print(
        "BibleSearchMiddleware: Busca ou pagamento/dedução já em andamento. Nova solicitação ignorada para query: '${action.query}'.");
    return; // Ignora a ação se já estiver processando
  }

  // 2. Despacha a ação IMEDIATAMENTE para o reducer.
  //    O reducer deve definir isLoading = true E isProcessingPayment = true.
  next(action);

  // 3. Pega o estado ATUALIZADO após o reducer ter sido executado.
  final BuildContext? currentContext = navigatorKey.currentContext;
  final UserState currentUserState = store.state.userState; // Estado do usuário
  // O bibleSearchState já foi atualizado pelo 'next(action)' acima.

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
    // Notifica o reducer para resetar isLoading e isProcessingPayment
    store.dispatch(SearchBibleSemanticFailureAction(
        'Usuário não autenticado ou convidado.'));
    return;
  }

  // --- LÓGICA DE CUSTO E VERIFICAÇÃO DE MOEDAS ---
  if (!isPremium) {
    print(
        "BibleSearchMiddleware: Usuário não é premium. Verificando moedas para busca bíblica... Moedas atuais: $userCoins, Custo: $BIBLE_SEARCH_COST");
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
                onPressed: () => store.dispatch(RequestRewardedAdAction())),
          ),
        );
      }
      store.dispatch(SearchBibleSemanticFailureAction('Moedas insuficientes.'));
      return;
    }

    print(
        "BibleSearchMiddleware: Deduzindo $BIBLE_SEARCH_COST moedas do usuário/convidado.");
    int newCoinTotal = userCoins - BIBLE_SEARCH_COST;
    store.dispatch(UpdateUserCoinsAction(newCoinTotal)); // Atualiza o Redux

    String? errorPersistence;

    if (userId != null) {
      // Usuário Logado
      final firestoreService = FirestoreService();
      try {
        await firestoreService.updateUserField(
            userId, 'userCoins', newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas deduzidas (usuário logado) com sucesso. Novo total: $newCoinTotal");
      } catch (e) {
        errorPersistence = "Erro ao deduzir moedas do Firestore (logado): $e";
      }
    } else if (isGuest) {
      // Usuário Convidado
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(guestUserCoinsPrefsKeyForBibleSearch, newCoinTotal);
        print(
            "BibleSearchMiddleware: Moedas deduzidas (convidado) com sucesso. Novo total: $newCoinTotal");
      } catch (e) {
        errorPersistence =
            "Erro ao salvar moedas do convidado (SharedPreferences): $e";
      }
    }

    if (errorPersistence != null) {
      print("BibleSearchMiddleware: $errorPersistence");
      store.dispatch(SearchBibleSemanticFailureAction(
          'Erro ao processar custo da busca bíblica.'));
      // Opcional: Reverter a dedução no Redux se a persistência falhar.
      // store.dispatch(UpdateUserCoinsAction(userCoins));
      return;
    }

    if (currentContext != null && currentContext.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentContext.mounted) {
          // Verifica novamente se está montado
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
  // --- FIM DA LÓGICA DE CUSTO ---

  // 4. Executa a busca real (chamada da Cloud Function)
  try {
    print(
        'BibleSearchMiddleware: Iniciando chamada da Cloud Function para query="${action.query}"...');
    final functions =
        FirebaseFunctions.instanceFor(region: "southamerica-east1");
    final HttpsCallable callable =
        functions.httpsCallable('semantic_bible_search');

    // Usa o estado atual dos filtros, que foi atualizado pelo reducer se a ação SetBibleSearchFilterAction
    // foi despachada antes desta SearchBibleSemanticAction.
    final requestData = {
      'query': action.query,
      'filters': store.state.bibleSearchState.activeFilters,
      'topK': 30, // Ajuste este valor conforme necessário
    };

    print(
        'BibleSearchMiddleware: Chamando Cloud Function "semantic_bible_search" com dados: $requestData');
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
            return <String,
                dynamic>{}; // Caso o item não seja um Map, retorna um mapa vazio
          })
          .where((item) => item.isNotEmpty) // Filtra mapas vazios
          .toList();
      print(
          'BibleSearchMiddleware: Resultados recebidos e processados: ${resultsList.length} itens.');
    } else if (rawResults != null) {
      print(
          'BibleSearchMiddleware: "results" da Cloud Function não é uma lista, recebido: ${rawResults.runtimeType}');
    } else {
      print('BibleSearchMiddleware: "results" da Cloud Function é nulo.');
    }

    store.dispatch(SearchBibleSemanticSuccessAction(resultsList));
  } on FirebaseFunctionsException catch (e) {
    print(
        "BibleSearchMiddleware: Erro FirebaseFunctionsException ao chamar 'semantic_bible_search': code=${e.code}, message=${e.message}, details=${e.details}");
    store.dispatch(SearchBibleSemanticFailureAction(
        "Erro na busca (${e.code}): ${e.message ?? 'Falha no servidor.'}"));
  } catch (e) {
    print(
        "BibleSearchMiddleware: Erro inesperado na chamada da Cloud Function: $e");
    store.dispatch(SearchBibleSemanticFailureAction(
        "Ocorreu um erro desconhecido durante a busca."));
  }
}

List<Middleware<AppState>> createBibleSearchMiddleware() {
  return [
    TypedMiddleware<AppState, SearchBibleSemanticAction>(
            _handleSearchBibleSemantic)
        .call,
  ];
}
