// lib/redux/reducers/metadata_reducer.dart
import 'package:resumo_dos_deuses_flutter/redux/actions/metadata_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Para MetadataState

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
  return state;
}
