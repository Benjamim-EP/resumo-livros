// lib/services/reading_time_tracker.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart'; // Importe a sua ação aqui
import 'package:septima_biblia/redux/store.dart';

// Mixin para ser usado com um StatefulWidget
mixin ReadingTimeTrackerMixin<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver {
  Timer? _readingTimer;
  final int _secondsPerTick = 20;
  int _accumulatedSeconds = 0;

  bool _isAppInForeground = true;
  bool _userHasInteracted = false;
  ScrollController? _scrollControllerToTrack;

  // --- MÉTODOS PÚBLICOS DO MIXIN ---

  void startReadingTracker({ScrollController? scrollController}) {
    WidgetsBinding.instance.addObserver(this);
    _scrollControllerToTrack = scrollController;
    _scrollControllerToTrack?.addListener(_onUserInteracted);

    _readingTimer = Timer.periodic(Duration(seconds: _secondsPerTick), _tick);
    print("ReadingTimeTracker: Rastreador iniciado.");
  }

  void stopReadingTracker() {
    print("ReadingTimeTracker: Rastreador parado.");
    _readingTimer?.cancel();
    _saveAccumulatedTime();

    _scrollControllerToTrack?.removeListener(_onUserInteracted);
    WidgetsBinding.instance.removeObserver(this);
  }

  Widget buildInteractionDetector({required Widget child}) {
    return GestureDetector(
      onTap: _onUserInteracted,
      onPanDown: (_) => _onUserInteracted(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  // --- LÓGICA INTERNA ---

  void _onUserInteracted() {
    _userHasInteracted = true;
  }

  void _tick(Timer timer) {
    if (_isAppInForeground && _userHasInteracted) {
      print("ReadingTimeTracker: Tick! Adicionando $_secondsPerTick segundos.");
      _accumulatedSeconds += _secondsPerTick;
      if (_accumulatedSeconds >= 60) {
        _saveAccumulatedTime();
      }
    } else {
      print(
          "ReadingTimeTracker: Tick ignorado (inativo ou app em background).");
    }
    _userHasInteracted = false;
  }

  void _saveAccumulatedTime() {
    if (_accumulatedSeconds > 0 && context.mounted) {
      print("ReadingTimeTracker: Enviando $_accumulatedSeconds segundos.");
      StoreProvider.of<AppState>(context, listen: false).dispatch(
          UpdateReadingTimeAction(accumulatedSeconds: _accumulatedSeconds));
      _accumulatedSeconds = 0;
    }
  }

  // --- IMPLEMENTAÇÃO COMPLETA DE WidgetsBindingObserver ---

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) {
      setState(() {
        _isAppInForeground = state == AppLifecycleState.resumed;
        if (!_isAppInForeground) {
          print("ReadingTimeTracker: App em background. Salvando tempo.");
          _saveAccumulatedTime();
        }
      });
    }
  }

  @override
  void didChangeAccessibilityFeatures() {}

  @override
  void didChangeLocales(List<Locale>? locales) {}

  @override
  void didChangeMetrics() {}

  @override
  void didHaveMemoryPressure() {}

  @override
  void didChangePlatformBrightness() {}

  @override
  void didChangeTextScaleFactor() {}

  @override
  Future<bool> didPushRoute(String route) => Future.value(false);

  @override
  Future<bool> didPopRoute() => Future.value(false);

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      Future.value(false);

  @override
  Future<AppExitResponse> didRequestAppExit() async => AppExitResponse.cancel;

  @override
  void didChangeViewFocus(ViewFocusEvent event) {}

  // Note: O método `didChangeViewPadding` foi removido em versões mais recentes
  // e substituído por `didChangeMetrics`. Se seu SDK for muito novo, ele pode não ser necessário.
  // Mantenha apenas os métodos que o seu SDK exige.

  @override
  Future<void> handleCancelBackGesture() async {}

  @override
  Future<void> handleCommitBackGesture() async {}

  @override
  Future<AppExitResponse> handleRequestAppExit() async =>
      AppExitResponse.cancel;

  // Em versões mais antigas, era `handleStartBackGesture(PredictiveBackEvent event)`
  // Em versões mais novas, pode ser apenas `handleStartBackGesture()`
  // Se o erro persistir, verifique a assinatura exata que o seu SDK do Flutter espera.
  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    // Retorne false para indicar que não está lidando com o gesto de back preditivo.
    return false;
  }

  // >>>>> INÍCIO DA CORREÇÃO <<<
  // Adiciona a implementação para o método que está faltando.
  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {}
  // >>>>> FIM DA CORREÇÃO <<<
}
