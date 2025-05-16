// lib/redux/middleware/metadata_middleware.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:redux/redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/metadata_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

List<Middleware<AppState>> createMetadataMiddleware() {
  void _handleLoadBibleSectionCounts(Store<AppState> store,
      LoadBibleSectionCountsAction action, NextDispatcher next) async {
    next(action);
    try {
      // Só carrega se ainda não estiver no estado
      if (store.state.metadataState.bibleSectionCounts.isEmpty) {
        print("MetadataMiddleware: Carregando contagem de seções do asset...");
        final String jsonString = await rootBundle
            .loadString('assets/metadata/bible_sections_count.json');
        final Map<String, dynamic> data = json.decode(jsonString);
        store.dispatch(BibleSectionCountsLoadedAction(data));
        print("MetadataMiddleware: Contagem de seções carregada com sucesso.");
      } else {
        print("MetadataMiddleware: Contagem de seções já carregada no estado.");
      }
    } catch (e) {
      print("Erro ao carregar bible_sections_count.json: $e");
      store.dispatch(BibleSectionCountsFailureAction(
          "Erro ao carregar metadados de progresso: $e"));
    }
  }

  return [
    TypedMiddleware<AppState, LoadBibleSectionCountsAction>(
        _handleLoadBibleSectionCounts),
  ];
}
