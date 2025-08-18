// lib/redux/actions/library_reference_actions.dart
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart';

// Disparada pela UI para buscar as referências de um capítulo inteiro
class LoadLibraryReferencesForChapterAction {
  final String bookAbbrev;
  final int chapter;

  LoadLibraryReferencesForChapterAction(
      {required this.bookAbbrev, required this.chapter});
}

// Disparada pelo middleware em caso de sucesso
class LibraryReferencesLoadedAction {
  // O payload é um mapa de sectionId -> lista de referências para aquele capítulo
  final Map<String, List<LibraryReference>> references;

  LibraryReferencesLoadedAction(this.references);
}

// Disparada pelo middleware em caso de falha
class LibraryReferencesFailedAction {
  final String error;
  LibraryReferencesFailedAction(this.error);
}
