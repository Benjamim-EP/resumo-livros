// lib/pages/library_page/glowing_resource_card.dart
import 'package:flutter/material.dart';
// ✅ 1. IMPORTA O NOVO CARD COMPACTO
import 'package:septima_biblia/pages/library_page/compact_resource_card.dart';
import 'package:septima_biblia/pages/library_page/resource_detail_modal.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class GlowingResourceCard extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final VoidCallback onCardTap; // Renomeado para clareza
  final VoidCallback onExpandTap; // Renomeado para clareza

  const GlowingResourceCard({
    super.key,
    required this.itemData,
    required this.onCardTap,
    required this.onExpandTap,
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12), // Borda consistente
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
      // ✅ 2. O CHILD AGORA É O CompactResourceCard
      child: CompactResourceCard(
        title: widget.itemData['title'],
        author: widget.itemData['author'],
        onCardTap: widget.onCardTap,
        onExpandTap: widget.onExpandTap,
      ),
    );
  }
}
