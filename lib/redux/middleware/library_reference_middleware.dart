// lib/redux/middleware/library_reference_middleware.dart
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/store.dart';
import '../actions/library_reference_actions.dart';
import '../reducers/library_reference_reducer.dart';
import '../../pages/biblie_page/bible_page_helper.dart'; // Para buscar IDs de seção
import '../../services/firestore_service.dart'; // Para buscar no Firestore

List<Middleware<AppState>> createLibraryReferenceMiddleware() {
  final firestoreService = FirestoreService();

  void _handleLoad(Store<AppState> store,
      LoadLibraryReferencesForChapterAction action, NextDispatcher next) async {
    next(action);

    try {
      final sectionIds = await BiblePageHelper.getAllSectionIdsForChapter(
          action.bookAbbrev, action.chapter);
      if (sectionIds.isEmpty) {
        print(
            "LibraryReferenceMiddleware: Nenhuma seção encontrada para ${action.bookAbbrev} ${action.chapter}.");
        store.dispatch(LibraryReferencesLoadedAction({}));
        return;
      }

      // Chama a função que acabamos de adicionar no FirestoreService
      final results =
          await firestoreService.fetchLibraryReferencesForSections(sectionIds);
      print(
          "LibraryReferenceMiddleware: Resultados recebidos do Firestore. Total de seções com dados: ${results.length}");
      if (results.isNotEmpty) {
        print(
            "LibraryReferenceMiddleware: Exemplo de resultado para a primeira seção '${results.keys.first}': ${results.values.first.length} recomendações.");
      }
      store.dispatch(LibraryReferencesLoadedAction(results));
      print(
          "LibraryReferenceMiddleware: Referências para ${action.bookAbbrev} ${action.chapter} carregadas com sucesso.");
    } catch (e) {
      print(
          "ERRO no LibraryReferenceMiddleware para ${action.bookAbbrev} ${action.chapter}: $e");
      store.dispatch(LibraryReferencesFailedAction(e.toString()));
    }
  }

  return [
    TypedMiddleware<AppState, LoadLibraryReferencesForChapterAction>(
        _handleLoad),
  ];
}
