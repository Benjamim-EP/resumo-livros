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
  final functions = FirebaseFunctions.instanceFor(region: "southamerica-east1");

  void _fetchRecommendations(Store<AppState> store,
      FetchVerseRecommendationsAction action, NextDispatcher next) async {
    next(action);

    final state = store.state.userState;
    if (state.userId == null || (state.learningGoal ?? '').trim().isEmpty) {
      return;
    }

    final chapterId = "${action.bookAbbrev}_${action.chapter}";
    if (state.recommendedVerses.containsKey(chapterId)) {
      return;
    }

    try {
      final callable =
          functions.httpsCallable('getVerseRecommendationsForChapter');
      final result = await callable.call<Map<String, dynamic>>({
        'bookAbbrev': action.bookAbbrev,
        'chapter': action.chapter,
      });

      final verses = List<int>.from(result.data['verses'] ?? []);
      store.dispatch(VerseRecommendationsLoadedAction(chapterId, verses));
    } catch (e) {
      print("ERRO no BibleRecommendationMiddleware: $e");
      store.dispatch(VerseRecommendationsLoadedAction(chapterId, []));
    }
  }

  // Retorna a lista de middlewares para serem adicionados à store.
  return [
    TypedMiddleware<AppState, FetchVerseRecommendationsAction>(
        _fetchRecommendations),
  ];
}
