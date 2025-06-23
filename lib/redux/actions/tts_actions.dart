// lib/redux/actions/tts_actions.dart

// Ação principal despachada pela UI para INICIAR uma fala
class TtsRequestSpeakAction {
  final String text;
  TtsRequestSpeakAction({required this.text});
}

// Ação principal despachada pela UI para PARAR uma fala
class TtsRequestStopAction {}

// Ações despachadas PELO SERVIÇO TTS para atualizar o estado
class TtsStartedAction {}

class TtsCompletedAction {}

class TtsErrorAction {
  final String error;
  TtsErrorAction({required this.error});
}
