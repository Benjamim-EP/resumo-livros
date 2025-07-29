// lib/pages/community/animated_article_button.dart

import 'package:flutter/material.dart';

class AnimatedArticleButton extends StatefulWidget {
  final VoidCallback onPressed;

  const AnimatedArticleButton({super.key, required this.onPressed});

  @override
  State<AnimatedArticleButton> createState() => _AnimatedArticleButtonState();
}

class _AnimatedArticleButtonState extends State<AnimatedArticleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // --- ALTERAÇÃO AQUI: Usa a cor primária do tema ---
              color: theme.colorScheme.primary.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: FilledButton.icon(
          onPressed: widget.onPressed,
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text("Ler Artigo"),
          style: FilledButton.styleFrom(
            // --- ALTERAÇÃO AQUI: Usa as cores do tema ---
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }
}
