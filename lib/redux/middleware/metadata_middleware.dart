// lib/redux/middleware/metadata_middleware.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';

List<Middleware<AppState>> createMetadataMiddleware() {
  void _handleLoadBibleSectionCounts(Store<AppState> store,
      LoadBibleSectionCountsAction action, NextDispatcher next) async {
    next(action);
    try {
      if (store.state.metadataState.bibleSectionCounts.isEmpty) {
        final String jsonString = await rootBundle
            .loadString('assets/metadata/bible_sections_count.json');
        final Map<String, dynamic> data = json.decode(jsonString);
        store.dispatch(BibleSectionCountsLoadedAction(data));
      }
    } catch (e) {
      store.dispatch(BibleSectionCountsFailureAction(e.toString()));
    }
  }

  void _handleLoadBibleSagas(Store<AppState> store, LoadBibleSagasAction action,
      NextDispatcher next) async {
    next(action);

    if (store.state.metadataState.bibleSagas.isNotEmpty) {
      return;
    }

    try {
      final firestoreService = FirestoreService();
      final sagas = await firestoreService.fetchBibleSagas();
      store.dispatch(BibleSagasLoadedAction(sagas));
    } catch (e) {
      store.dispatch(BibleSagasFailedAction(e.toString()));
    }
  }

  return [
    TypedMiddleware<AppState, LoadBibleSectionCountsAction>(
        _handleLoadBibleSectionCounts),
    TypedMiddleware<AppState, LoadBibleSagasAction>(_handleLoadBibleSagas),
  ];
}
