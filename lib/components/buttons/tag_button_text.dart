import 'package:flutter/material.dart';

// Componente de Tag que usa Filled Tonal Button com cores e bordas personalizadas
class TagButtonText extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const TagButtonText({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical:
                  3), // Reduzindo o padding para ajustar o tamanho do botão
          backgroundColor:
              const Color.fromARGB(255, 233, 225, 255), // Cor de fundo do botão
          foregroundColor: const Color.fromARGB(255, 0, 0, 0), // Cor do texto
          minimumSize: const Size(60, 30), // Tamanho mínimo do botão
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Mantendo as bordas
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10, // Reduzindo o tamanho da fonte
            fontFamily: 'Abel',
          ),
        ),
      ),
    );
  }
}
