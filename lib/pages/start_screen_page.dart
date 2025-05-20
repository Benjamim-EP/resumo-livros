import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/care_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/moody_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/relax_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/splash_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/welcome_view.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class StartScreenPage extends StatefulWidget {
  const StartScreenPage({super.key});

  @override
  _SelectTribePageState createState() => _SelectTribePageState();
}

class _SelectTribePageState extends State<StartScreenPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  bool isRecording = false; // Controle do estado de gravação

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _animationController.animateTo(0.0);

    // Inicia a gravação de tela automaticamente
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   startScreenRecording();
    // });
  }

  // Future<void> startScreenRecording() async {
  //   try {
  //     bool started = await FlutterScreenRecording.startRecordScreen(
  //       "GravacaoStartScreen",
  //       titleNotification: "Gravação Iniciada",
  //       messageNotification: "Gravando tela do aplicativo",
  //     );

  //     if (started) {
  //       setState(() {
  //         isRecording = true;
  //       });

  //       // Para a gravação automaticamente após 5 segundos
  //       await Future.delayed(const Duration(seconds: 5));
  //       await stopScreenRecording();
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Falha ao iniciar gravação.")),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Erro ao iniciar gravação: $e")),
  //     );
  //   }
  // }

  // Future<void> stopScreenRecording() async {
  //   try {
  //     bool stopped = await FlutterScreenRecording.stopRecordScreen;

  //     if (stopped) {
  //       setState(() {
  //         isRecording = false;
  //       });
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Gravação finalizada e salva.")),
  //       );
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Erro ao parar gravação.")),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text("Erro ao parar gravação: $e")),
  //     );
  //   }
  // }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A1A),
      body: Stack(
        children: [
          SplashView(animationController: _animationController),
          RelaxView(animationController: _animationController),
          MoodDiaryVew(animationController: _animationController),
          //CareView(animationController: _animationController),
          //WelcomeView(animationController: _animationController),
          _TopBackSkipView(
            animationController: _animationController,
            onSkip: _onSkip,
            onBack: _onBack,
          ),
          _CenterNextButton(
            animationController: _animationController,
            onNext: _onNext,
          ),
        ],
      ),
    );
  }

  void _onSkip() {
    _animationController.animateTo(0.4,
        duration: const Duration(milliseconds: 1200));
  }

  void _onNext() {
    final value = _animationController.value;
    if (value >= 0.0 && value < 0.2) {
      _animationController.animateTo(0.2);
    } else if (value >= 0.2 && value < 0.4) {
      _animationController.animateTo(0.4);
    } else if (value >= 0.4 && value < 0.6) {
      //_animationController.animateTo(0.6);
      Navigator.pushReplacementNamed(context, '/login');
      // } else if (value >= 0.6 && value < 0.8) {
      //   Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onBack() {
    final value = _animationController.value;

    if (value >= 0.6) {
      _animationController.animateTo(0.4);
    } else if (value >= 0.4) {
      _animationController.animateTo(0.2);
    } else if (value >= 0.2) {
      _animationController.animateTo(0.0);
    }
  }
}

class _CenterNextButton extends StatefulWidget {
  final AnimationController animationController;
  final VoidCallback onNext;

  const _CenterNextButton({
    required this.animationController,
    required this.onNext,
  });

  @override
  State<_CenterNextButton> createState() => _CenterNextButtonState();
}

class _CenterNextButtonState extends State<_CenterNextButton> {
  bool _isLoading = false; // Estado de carregamento

  void _handleNext() {
    if (widget.animationController.value >= 0.4) {
      setState(() {
        _isLoading = true;
      });
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Center(
        child: ScaleTransition(
          scale: scaleAnimation,
          child: AnimatedBuilder(
            animation: widget.animationController,
            builder: (context, child) {
              if (widget.animationController.value < 0.2) {
                return const SizedBox.shrink();
              }

              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: !_isLoading ? _handleNext : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232538),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFEAF4F4),
                            ),
                          )
                        : const Text(
                            'Próximo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEAF4F4),
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopBackSkipView extends StatelessWidget {
  final AnimationController animationController;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  const _TopBackSkipView({
    required this.animationController,
    required this.onSkip,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 50, // Botões mais abaixo
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão de voltar
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(30), // Arredondamento
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 77, 81, 114), // Gradiente verde
                    Color(0xFF141629),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // Botão de pular
          InkWell(
            onTap: onSkip,
            borderRadius: BorderRadius.circular(30), // Arredondamento
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  colors: [
                    Color.fromARGB(255, 231, 250, 220), // Gradiente azul
                    Color.fromARGB(255, 158, 187, 140),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text(
                'Pular',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF141629),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
