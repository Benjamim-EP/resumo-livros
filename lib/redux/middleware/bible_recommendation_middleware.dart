// lib/redux/middleware/bible_recommendation_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Cria e retorna a lista de middlewares responsáveis por:
/// 1. Buscar recomendações de versículos de uma Cloud Function.
/// 2. Limpar o cache de recomendações quando o objetivo de estudo do usuário muda.
List<Middleware<AppState>> createBibleRecommendationMiddleware() {
  print(
      "RecommendationMiddleware: Inicializando o middleware de recomendações...");
  // Instancia o cliente do Firebase Functions, apontando para a região correta.
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");
  final firestore = FirebaseFirestore.instance;

  /// Handler que lida com a ação de buscar recomendações para um capítulo específico.
  void _fetchRecommendations(Store<AppState> store,
      FetchVerseRecommendationsAction action, NextDispatcher next) async {
    next(
        action); // Passa a ação adiante, caso algum outro middleware precise dela.

    final state = store.state.userState;

    // --- Guard Clauses (Verificações de Segurança) ---
    if (state.userId == null || (state.learningGoal ?? '').trim().isEmpty) {
      print(
          "RecommendationMiddleware: Busca abortada (usuário não logado ou sem objetivo de estudo).");
      return;
    }

    final chapterId = "${action.bookAbbrev}_${action.chapter}";

    // --- Otimização de Cache (Lado do Cliente/Redux) ---
    if (state.recommendedVerses.containsKey(chapterId)) {
      print(
          "RecommendationMiddleware: Cache do Redux HIT para $chapterId. Nenhuma chamada de rede necessária.");
      return;
    }

    print(
        "RecommendationMiddleware: Cache do Redux MISS para $chapterId. Chamando a Cloud Function 'getVerseRecommendationsForChapter'...");

    try {
      final callable =
          functions.httpsCallable('getVerseRecommendationsForChapter');

      // =================================================================
      // <<< CORREÇÃO DEFINITIVA PARA O ERRO 400 (Bad Request) >>>
      // =================================================================
      // Enviamos o mapa de dados simples. O pacote `cloud_functions`
      // irá encapsular isso automaticamente em um objeto `{"data": ...}`
      // para o backend Python.
      final result = await callable.call<Map<String, dynamic>>({
        'bookAbbrev': action.bookAbbrev,
        'chapter': action.chapter,
      });
      // =================================================================

      // Converte a resposta (que pode ser List<dynamic>) para o tipo correto (List<int>).
      final verses = List<int>.from(result.data['verses'] ?? []);

      print(
          "RecommendationMiddleware: Resposta recebida para $chapterId. Versículos recomendados: $verses");

      // Despacha a ação de sucesso para que o reducer possa atualizar o estado da aplicação.
      store.dispatch(VerseRecommendationsLoadedAction(chapterId, verses));
    } on FirebaseFunctionsException catch (e) {
      print(
          "ERRO na Cloud Function getVerseRecommendationsForChapter: Código=${e.code}, Mensagem=${e.message}");
      // Em caso de erro, despachamos uma lista vazia. Isso funciona como um "cache negativo"
      // para esta sessão, impedindo que o app tente buscar repetidamente por um capítulo que falhou.
      store.dispatch(VerseRecommendationsLoadedAction(chapterId, []));
    } catch (e) {
      print("ERRO inesperado no Middleware de Recomendações: $e");
      store.dispatch(VerseRecommendationsLoadedAction(chapterId, []));
    }
  }

  void _clearRecommendations(Store<AppState> store,
      UpdateLearningGoalAction action, NextDispatcher next) async {
    // 1. Despacha a ação para o user_middleware salvar o novo objetivo no Firestore.
    store.dispatch(UpdateUserFieldAction('learningGoal', action.newGoal));

    // 2. Passa a ação adiante.
    next(action);

    // 3. Limpa o estado local IMEDIATAMENTE para a UI ficar consistente.
    store.dispatch(ClearAllVerseRecommendationsAction());
    print(
        "RecommendationMiddleware: Estado de recomendações locais (Redux) limpo.");

    // 4. Executa a limpeza do cache no Firestore em segundo plano, direto do app.
    final userId = store.state.userState.userId;
    if (userId == null) return;

    print(
        "RecommendationMiddleware: Iniciando limpeza do cache no Firestore para o usuário $userId...");
    try {
      // 4a. Referência para a subcoleção que queremos limpar.
      final collectionRef = firestore
          .collection('users')
          .doc(userId)
          .collection('recommendedVerses');

      // 4b. Busca todos os documentos na subcoleção de cache.
      final snapshot = await collectionRef.get();

      if (snapshot.docs.isEmpty) {
        print(
            "RecommendationMiddleware: Cache do Firestore já estava vazio. Nenhuma ação necessária.");
        return;
      }

      print(
          "RecommendationMiddleware: Encontrados ${snapshot.docs.length} documentos de cache para deletar.");

      // 4c. Cria um "batch" para deletar todos os documentos em uma única operação de rede.
      final batch = firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      // 4d. Executa o batch.
      await batch.commit();

      print(
          "RecommendationMiddleware: Cache de recomendações no Firestore limpo com sucesso.");
    } catch (e) {
      // Este erro pode acontecer se as regras do Firestore não estiverem corretas.
      print("ERRO ao limpar o cache de recomendações no Firestore: $e");
    }
  }

  // Retorna a lista de middlewares para serem adicionados à store.
  return [
    TypedMiddleware<AppState, FetchVerseRecommendationsAction>(
        _fetchRecommendations),
    TypedMiddleware<AppState, UpdateLearningGoalAction>(_clearRecommendations),
  ];
}
