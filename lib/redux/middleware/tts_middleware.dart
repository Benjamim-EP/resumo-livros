// lib/redux/middleware/tts_middleware.dart
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions/tts_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_service.dart';

List<Middleware<AppState>> createTtsMiddleware() {
  // Pega a instância Singleton do serviço
  final ttsService = TextToSpeechService();

  // Função para configurar os callbacks do serviço para despachar ações do Redux.
  // Isso é feito uma vez quando o middleware é criado.
  void setupTtsCallbacks(Store<AppState> store) {
    ttsService.onStart = () {
      store.dispatch(TtsStartedAction());
    };
    ttsService.onComplete = () {
      store.dispatch(TtsCompletedAction());
    };
    ttsService.onError = (errorMsg) {
      store.dispatch(TtsErrorAction(error: errorMsg));
    };
  }

  // Handler para a ação de Falar
  void _handleSpeak(Store<AppState> store, TtsRequestSpeakAction action,
      NextDispatcher next) {
    next(action); // Passa a ação para o reducer
    // Configura os callbacks com o store atual antes de cada chamada, se necessário (embora o store seja o mesmo)
    setupTtsCallbacks(store);
    ttsService.speak(action.text);
  }

  // Handler para a ação de Parar
  void _handleStop(
      Store<AppState> store, TtsRequestStopAction action, NextDispatcher next) {
    next(action);
    setupTtsCallbacks(store);
    ttsService.stop();
  }

  return [
    TypedMiddleware<AppState, TtsRequestSpeakAction>(_handleSpeak),
    TypedMiddleware<AppState, TtsRequestStopAction>(_handleStop),
  ];
}
