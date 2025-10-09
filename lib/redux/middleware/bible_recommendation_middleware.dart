// lib/redux/middleware/bible_recommendation_middleware.dart

import 'package:redux/redux.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

/// Cria e retorna a lista de middlewares responsáveis por:
/// 1. Buscar recomendações de versículos de uma Cloud Function.
/// 2. Limpar o cache de recomendações quando o objetivo de estudo do usuário muda.
List<Middleware<AppState>> createBibleRecommendationMiddleware() {
  print(
      "RecommendationMiddleware: Inicializando o middleware de recomendações...");
  // Instancia o cliente do Firebase Functions, apontando para a região correta.
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

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

  /// Handler que lida com a ação de limpar todas as recomendações.
  /// É disparado quando o usuário salva um novo `learningGoal`.
  void _clearRecommendations(Store<AppState> store,
      UpdateLearningGoalAction action, NextDispatcher next) async {
    // 1. Despacha a ação genérica para que o user_middleware salve o novo objetivo no Firestore.
    store.dispatch(UpdateUserFieldAction('learningGoal', action.newGoal));

    // 2. Passa a ação `UpdateLearningGoalAction` adiante.
    next(action);

    // 3. Limpa o estado local IMEDIATAMENTE. A UI refletirá a limpeza na hora.
    store.dispatch(ClearAllVerseRecommendationsAction());
    print(
        "RecommendationMiddleware: Estado de recomendações locais (Redux) limpo.");

    // 4. Chama a Cloud Function para limpar o cache no backend em segundo plano.
    try {
      final callable = functions.httpsCallable('clearVerseRecommendations');
      // Uma chamada sem parâmetros é enviada como `{"data": null}` pelo pacote, o que é
      // aceito por uma função `onCall` do Python que não lê o `req.data`.
      await callable.call();
      print(
          "RecommendationMiddleware: Cache de recomendações no backend limpo com sucesso via Cloud Function.");
    } catch (e) {
      // Este erro não é crítico para a experiência do usuário, então apenas o registramos.
      print("ERRO ao chamar a Cloud Function 'clearVerseRecommendations': $e");
    }
  }

  // Retorna a lista de middlewares para serem adicionados à store.
  return [
    TypedMiddleware<AppState, FetchVerseRecommendationsAction>(
        _fetchRecommendations),
    TypedMiddleware<AppState, UpdateLearningGoalAction>(_clearRecommendations),
  ];
}
