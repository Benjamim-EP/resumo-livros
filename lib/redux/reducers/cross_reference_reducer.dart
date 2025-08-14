// lib/redux/reducers/cross_reference_reducer.dart

import 'package:septima_biblia/redux/actions.dart';

class CrossReferenceState {
  final bool isLoading;
  final Map<String, dynamic> data;
  final String? error;

  CrossReferenceState({
    this.isLoading = false,
    this.data = const {},
    this.error,
  });

  CrossReferenceState copyWith({
    bool? isLoading,
    Map<String, dynamic>? data,
    String? error,
    bool clearError = false,
  }) {
    return CrossReferenceState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: clearError ? null : error ?? this.error,
    );
  }
}

CrossReferenceState crossReferenceReducer(
    CrossReferenceState state, dynamic action) {
  if (action is LoadCrossReferencesAction) {
    return state.copyWith(isLoading: true, clearError: true);
  }
  if (action is CrossReferencesLoadedAction) {
    return state.copyWith(isLoading: false, data: action.data);
  }
  if (action is CrossReferencesFailedAction) {
    return state.copyWith(isLoading: false, error: action.error);
  }
  return state;
}
