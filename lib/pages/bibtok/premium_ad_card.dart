// lib/pages/bibtok/premium_ad_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';

class PremiumAdCard extends StatefulWidget {
  // <<< NOVO PARÂMETRO >>>
  final PageController pageController;
  final int currentPageIndex;

  const PremiumAdCard({
    super.key,
    required this.pageController,
    required this.currentPageIndex,
  });

  @override
  State<PremiumAdCard> createState() => _PremiumAdCardState();
}

class _PremiumAdCardState extends State<PremiumAdCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _lockScrollTimer;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    // Inicia um timer que "prende" o usuário na página atual
    _lockScrollTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (widget.pageController.page != widget.currentPageIndex.toDouble()) {
        // Se o usuário tentar rolar, força a volta para a página do anúncio
        widget.pageController.animateToPage(
          widget.currentPageIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    // Para o timer de travamento após 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      _lockScrollTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _lockScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.deepOrange.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        color: Colors.white, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      "Desbloqueie Todo o Potencial",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Estudo interlinear, busca com IA, biblioteca exclusiva e uma experiência sem anúncios.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SubscriptionSelectionPage()));
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.amber.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Ver Planos Premium",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.white,
                  minHeight: 6,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
