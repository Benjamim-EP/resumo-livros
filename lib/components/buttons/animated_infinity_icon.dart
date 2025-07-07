import 'package:flutter/material.dart';

class AnimatedInfinityIcon extends StatefulWidget {
  const AnimatedInfinityIcon({super.key});

  @override
  State<AnimatedInfinityIcon> createState() => _AnimatedInfinityIconState();
}

class _AnimatedInfinityIconState extends State<AnimatedInfinityIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // A animação repete continuamente
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cores para o gradiente do brilho
    final Color baseColor = Colors.amber.shade600;
    final Color highlightColor = Colors.amber.shade200;

    return Tooltip(
      message: "Você é um assinante Premium",
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              // O gradiente se move da esquerda para a direita baseado no valor do controller
              return LinearGradient(
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                // A transformação animada do gradiente
                transform: _SlideGradientTransform(percent: _controller.value),
              ).createShader(bounds);
            },
            child: child,
          );
        },
        // O ícone em si, que será a "máscara" para o shader
        child: const Icon(
          Icons.all_inclusive_rounded, // Ícone de infinito
          color:
              Colors.white, // A cor base do ícone (será sobreposta pelo shader)
          size: 26,
        ),
      ),
    );
  }
}

// Classe auxiliar para a transformação do gradiente
class _SlideGradientTransform extends GradientTransform {
  final double percent;

  const _SlideGradientTransform({required this.percent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // Move o gradiente horizontalmente
    final double a = percent * 2 - 1; // Mapeia 0.0-1.0 para -1.0-1.0
    final double x = a * bounds.width;
    return Matrix4.translationValues(x, 0.0, 0.0);
  }
}
