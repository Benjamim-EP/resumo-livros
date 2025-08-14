// lib/redux/middleware/cross_reference_middleware.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';

List<Middleware<AppState>> createCrossReferenceMiddleware() {
  return [
    TypedMiddleware<AppState, LoadCrossReferencesAction>(_loadCrossReferences),
  ];
}

void _loadCrossReferences(Store<AppState> store,
    LoadCrossReferencesAction action, NextDispatcher next) async {
  next(action);

  // Evita recarregar se os dados já estiverem no estado
  if (store.state.crossReferenceState.data.isNotEmpty) {
    print("Middleware: Referências cruzadas já carregadas.");
    return;
  }

  try {
    print("Middleware: Carregando cross_references.json do asset...");
    final String jsonString =
        await rootBundle.loadString('assets/data/cross_references.json');
    final Map<String, dynamic> data = json.decode(jsonString);
    store.dispatch(CrossReferencesLoadedAction(data));
    print("Middleware: Referências cruzadas carregadas com sucesso.");
  } catch (e) {
    print("Middleware: ERRO CRÍTICO ao carregar referências: $e");
    store.dispatch(CrossReferencesFailedAction(e.toString()));
  }
}
