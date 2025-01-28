import 'package:flutter/material.dart';

// Componente de Tag que usa Filled Tonal Button com cores e bordas personalizadas
class ButtonNoIcon extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const ButtonNoIcon({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          backgroundColor:
              const Color.fromARGB(255, 134, 197, 138), // Cor de fundo do botão
          foregroundColor: const Color.fromARGB(255, 0, 0, 0), // Cor do texto
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                20), // Define o raio das bordas (menos arredondadas)
          ),
        ),
      ),
    );
  }
}
