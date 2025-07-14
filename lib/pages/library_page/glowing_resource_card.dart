// lib/pages/library_page/glowing_resource_card.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/library_page.dart'; // Para reutilizar o ResourceCard

class GlowingResourceCard extends StatefulWidget {
  final Map<String, dynamic> itemData; // Recebe os dados do card
  final VoidCallback onTap;

  const GlowingResourceCard({
    super.key,
    required this.itemData,
    required this.onTap,
  });

  @override
  State<GlowingResourceCard> createState() => _GlowingResourceCardState();
}

class _GlowingResourceCardState extends State<GlowingResourceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // A animação vai e volta continuamente
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Cores para o efeito neon. Você pode ajustar para combinar com seu tema.
    final Color color1 = theme.colorScheme.primary;
    final Color color2 = theme.colorScheme.secondary.withOpacity(0.8);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          // O Container externo cria o brilho
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15), // Mesmas bordas do card
            boxShadow: [
              BoxShadow(
                color: Color.lerp(color1, color2, _controller.value)!
                    .withOpacity(0.7),
                blurRadius: 10.0, // O "blur" cria o efeito de brilho
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: child,
        );
      },
      // O child é o ResourceCard original, que não precisa saber da animação
      child: ResourceCard(
        title: widget.itemData['title'],
        description: widget.itemData['description'],
        author: widget.itemData['author'],
        pageCount: widget.itemData['pageCount'],
        coverImagePath: widget.itemData['coverImagePath'],
        onTap: widget.onTap,
        // Força a borda do ResourceCard a ser mais visível ou de uma cor específica
        hasPremiumFeature: true,
      ),
    );
  }
}
