// lib/redux/reducers/tts_reducer.dart

import 'package:septima_biblia/redux/actions/tts_actions.dart';

// Renomeie a classe aqui
class AppTtsState {
  final bool isPlaying;
  final String? error;

  AppTtsState({
    this.isPlaying = false,
    this.error,
  });

  AppTtsState copyWith({
    bool? isPlaying,
    String? error,
    bool clearError = false,
  }) {
    return AppTtsState(
      isPlaying: isPlaying ?? this.isPlaying,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// E renomeie a assinatura do seu reducer
AppTtsState ttsReducer(AppTtsState state, dynamic action) {
  // ... (a lógica interna permanece a mesma)
  if (action is TtsStartedAction) {
    return state.copyWith(isPlaying: true, clearError: true);
  }
  if (action is TtsCompletedAction || action is TtsRequestStopAction) {
    return state.copyWith(isPlaying: false);
  }
  if (action is TtsErrorAction) {
    return state.copyWith(isPlaying: false, error: action.error);
  }
  return state;
}
