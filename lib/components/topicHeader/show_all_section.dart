import 'package:flutter/material.dart';
import 'show_all_text.dart'; // Importa o componente ShowAllText
import 'show_all_icon.dart'; // Importa o componente ShowAllIcon

// Componente que une o texto "Show all" e o ícone verde
class ShowAllSection extends StatelessWidget {
  const ShowAllSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ShowAllText(text: "Show all"), // Texto "Show all"
        const SizedBox(width: 4),
        ShowAllIcon(), // Ícone verde
      ],
    );
  }
}
