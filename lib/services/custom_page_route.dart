// lib/services/custom_page_route.dart
import 'package:flutter/material.dart';

/// Uma PageRoute customizada que aplica uma animação de Fade (esmaecer)
/// e Scale (escala) ao navegar entre telas.
///
/// Isso cria uma transição suave e moderna, que é consistente
/// em todas as plataformas (Android e iOS).
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  FadeScalePageRoute({required this.page})
      : super(
          // Define a duração da animação. 300-400ms é um bom valor.
          transitionDuration: const Duration(milliseconds: 350),

          // pageBuilder apenas constrói a página de destino, sem animação.
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,

          // transitionsBuilder é onde a mágica acontece. Ele recebe a animação
          // e o widget filho (a nova página) e aplica as transições.
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            // A animação de escala começará em 95% do tamanho e irá até 100%.
            // A curva `easeOutCubic` faz a animação desacelerar suavemente no final.
            const begin = 0.95;
            const end = 1.0;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: Curves.easeOutCubic));

            // Combina uma transição de Fade (opacidade) com a de Escala.
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation.drive(tween),
                child: child,
              ),
            );
          },
        );
}
