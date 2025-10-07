// lib/redux/reducers/metadata_reducer.dart

import 'package:septima_biblia/models/bible_saga_model.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';

class MetadataState {
  final Map<String, dynamic> bibleSectionCounts;
  final bool isLoadingSectionCounts;
  final String? sectionCountsError;

  final List<BibleSaga> bibleSagas;
  final bool isLoadingSagas;
  final String? sagasError;

  MetadataState({
    this.bibleSectionCounts = const {},
    this.isLoadingSectionCounts = false,
    this.sectionCountsError,
    this.bibleSagas = const [],
    this.isLoadingSagas = false,
    this.sagasError,
  });

  MetadataState copyWith({
    Map<String, dynamic>? bibleSectionCounts,
    bool? isLoadingSectionCounts,
    String? sectionCountsError,
    bool clearError = false,
    List<BibleSaga>? bibleSagas,
    bool? isLoadingSagas,
    String? sagasError,
    bool clearSagasError = false,
  }) {
    return MetadataState(
      bibleSectionCounts: bibleSectionCounts ?? this.bibleSectionCounts,
      isLoadingSectionCounts:
          isLoadingSectionCounts ?? this.isLoadingSectionCounts,
      sectionCountsError:
          clearError ? null : sectionCountsError ?? this.sectionCountsError,
      bibleSagas: bibleSagas ?? this.bibleSagas,
      isLoadingSagas: isLoadingSagas ?? this.isLoadingSagas,
      sagasError: clearSagasError ? null : (sagasError ?? this.sagasError),
    );
  }
}

MetadataState metadataReducer(MetadataState state, dynamic action) {
  if (action is LoadBibleSectionCountsAction) {
    return state.copyWith(isLoadingSectionCounts: true, clearError: true);
  }
  if (action is BibleSectionCountsLoadedAction) {
    return state.copyWith(
      isLoadingSectionCounts: false,
      bibleSectionCounts: action.sectionCounts,
    );
  }
  if (action is BibleSectionCountsFailureAction) {
    return state.copyWith(
      isLoadingSectionCounts: false,
      sectionCountsError: action.error,
    );
  }

  if (action is LoadBibleSagasAction) {
    return state.copyWith(isLoadingSagas: true, clearSagasError: true);
  }
  if (action is BibleSagasLoadedAction) {
    return state.copyWith(isLoadingSagas: false, bibleSagas: action.sagas);
  }
  if (action is BibleSagasFailedAction) {
    return state.copyWith(isLoadingSagas: false, sagasError: action.error);
  }

  return state;
}
