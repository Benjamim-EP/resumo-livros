import 'package:flutter/material.dart';

class TagButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const TagButton({
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
            fontSize: 10, // Reduzindo o tamanho da fonte
          ),
        ),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Usando as cores do tema atual
          backgroundColor: Theme.of(context)
              .filledButtonTheme
              .style
              ?.backgroundColor
              ?.resolve({}),
          foregroundColor: Theme.of(context)
              .filledButtonTheme
              .style
              ?.foregroundColor
              ?.resolve({}),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
