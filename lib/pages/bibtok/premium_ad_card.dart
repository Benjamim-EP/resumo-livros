// lib/pages/bibtok/premium_ad_card.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';

class PremiumAdCard extends StatefulWidget {
  final VoidCallback onTimerStart;
  final VoidCallback onTimerEnd;

  const PremiumAdCard({
    super.key,
    required this.onTimerStart,
    required this.onTimerEnd,
  });

  @override
  State<PremiumAdCard> createState() => _PremiumAdCardState();
}

class _PremiumAdCardState extends State<PremiumAdCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  Timer? _unlockScrollTimer;

  @override
  void initState() {
    super.initState();

    // Inicia o controlador da animação da barra de progresso
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward(); // Inicia a animação

    // Chama o callback para travar o scroll na página pai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTimerStart();
    });

    // Agenda o destravamento do scroll após 3 segundos
    _unlockScrollTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onTimerEnd();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _unlockScrollTimer?.cancel();
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
            // Conteúdo principal do Card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade600,
                    Colors.deepOrange.shade400,
                  ],
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
                    Icon(
                      Icons.workspace_premium_outlined,
                      color: Colors.white,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Desbloqueie Todo o Potencial",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Estudo interlinear, busca com IA, biblioteca exclusiva e uma experiência sem anúncios.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SubscriptionSelectionPage()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.amber.shade800,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Ver Planos Premium",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Barra de Progresso/Timer
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
