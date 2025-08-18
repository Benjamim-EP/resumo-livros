// lib/redux/reducers/library_reference_reducer.dart
import 'package:septima_biblia/redux/actions/library_reference_actions.dart';

// Modelo para uma recomendação (o que vem do Firestore)
class LibraryReference {
  final String contentId;
  final String reason;

  LibraryReference({required this.contentId, required this.reason});

  factory LibraryReference.fromJson(Map<String, dynamic> json) {
    return LibraryReference(
      contentId: json['contentId'] ?? '',
      reason: json['reason'] ?? 'Recomendação relacionada.',
    );
  }
}

// Estado
class LibraryReferenceState {
  final bool isLoading;
  // Mapeia um sectionId (ex: "gn_1_1-2") para uma lista de recomendações
  final Map<String, List<LibraryReference>> referencesBySection;
  final String? error;

  LibraryReferenceState({
    this.isLoading = false,
    this.referencesBySection = const {},
    this.error,
  });

  LibraryReferenceState copyWith({
    bool? isLoading,
    Map<String, List<LibraryReference>>? referencesBySection,
    String? error,
  }) {
    return LibraryReferenceState(
      isLoading: isLoading ?? this.isLoading,
      referencesBySection: referencesBySection ?? this.referencesBySection,
      error: error ?? this.error,
    );
  }
}

// Reducer
LibraryReferenceState libraryReferenceReducer(
    LibraryReferenceState state, dynamic action) {
  if (action is LoadLibraryReferencesForChapterAction) {
    return state.copyWith(isLoading: true, error: null);
  }
  if (action is LibraryReferencesLoadedAction) {
    // Mescla os novos resultados com os existentes para não perder dados de outros capítulos
    final newMap =
        Map<String, List<LibraryReference>>.from(state.referencesBySection)
          ..addAll(action.references);
    return state.copyWith(isLoading: false, referencesBySection: newMap);
  }
  if (action is LibraryReferencesFailedAction) {
    return state.copyWith(isLoading: false, error: action.error);
  }
  return state;
}
