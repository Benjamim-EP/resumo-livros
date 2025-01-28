import 'package:flutter/material.dart';

// Componente de Tag que usa Filled Tonal Button com cores e bordas personalizadas
class TagButton2 extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const TagButton2({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16, // Reduzindo o tamanho da fonte
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          backgroundColor:
              const Color.fromARGB(255, 49, 51, 51), // Cor de fundo do botão
          foregroundColor:
              const Color.fromARGB(255, 255, 255, 255), // Cor do texto
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                20), // Define o raio das bordas (menos arredondadas)
          ),
        ),
      ),
    );
  }
}
