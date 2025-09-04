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
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color color1 = theme.colorScheme.primary;
    final Color color2 = theme.colorScheme.secondary.withOpacity(0.8);

    // ✅✅✅ INÍCIO DA CORREÇÃO ✅✅✅
    // Pega o caminho da imagem dos dados do item
    final String coverPath = widget.itemData['coverImagePath'] ?? '';
    // Cria o ImageProvider a partir do caminho
    final ImageProvider? coverImageProvider =
        coverPath.isNotEmpty ? AssetImage(coverPath) : null;
    // ✅✅✅ FIM DA CORREÇÃO ✅✅✅

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Color.lerp(color1, color2, _controller.value)!
                    .withOpacity(0.7),
                blurRadius: 10.0,
                spreadRadius: 2.0,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ResourceCard(
        title: widget.itemData['title'],
        description: widget.itemData['description'],
        author: widget.itemData['author'],
        pageCount: widget.itemData['pageCount'],
        // ✅✅✅ CORREÇÃO APLICADA AQUI ✅✅✅
        // Passa o ImageProvider em vez do String path
        coverImage: coverImageProvider,
        onTap: widget.onTap,
        hasPremiumFeature: true,
      ),
    );
  }
}
