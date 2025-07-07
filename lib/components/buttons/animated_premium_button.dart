import 'package:flutter/material.dart';

class AnimatedPremiumButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedPremiumButton({super.key, required this.onPressed});

  @override
  State<AnimatedPremiumButton> createState() => _AnimatedPremiumButtonState();
}

class _AnimatedPremiumButtonState extends State<AnimatedPremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shineAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 3), // Duração completa da animação de brilho
    )..repeat(); // Repete a animação continuamente

    // Animação para o brilho (vai de -1.5 a 1.5 para o gradiente se mover)
    _shineAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Animação para o pulsar sutil
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.slowMiddle));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cores premium
    const Color goldColor = Color(0xFFFFD700);
    const Color darkGoldColor = Color(0xFFB8860B);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedBuilder(
            animation: _shineAnimation,
            builder: (context, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: const [
                      darkGoldColor,
                      goldColor,
                      darkGoldColor,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                    // A animação controla a transformação do gradiente
                    transform:
                        GradientRotation(_shineAnimation.value * (3.14 / 2)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: goldColor.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    shadows: [
                      Shadow(
                        color: Colors.black38,
                        blurRadius: 2,
                        offset: Offset(1, 1),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
