// lib/components/tabs/tab_item.dart
import 'package:flutter/material.dart';

class TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const TabItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Cor de fundo para a aba selecionada (cor primária do tema)
    final Color selectedColor = theme.colorScheme.primary;
    // Cor de fundo para as abas não selecionadas (transparente ou sutil)
    final Color unselectedColor = theme.colorScheme.surface.withOpacity(0.1);

    // Cor do texto para a aba selecionada (cor "onPrimary" do tema para contraste)
    final Color selectedTextColor = theme.colorScheme.onPrimary;
    // Cor do texto para as abas não selecionadas (cor de texto secundária do tema)
    final Color unselectedTextColor =
        theme.textTheme.bodyLarge?.color?.withOpacity(0.7) ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20), // Borda arredondada para o efeito splash
        splashColor: selectedColor.withOpacity(0.2),
        highlightColor: selectedColor.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // Duração da animação
          curve: Curves.easeInOut, // Curva suave para a animação
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? selectedColor : unselectedColor,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              // Adiciona uma borda sutil nas abas não selecionadas
              color: isSelected
                  ? selectedColor
                  : theme.dividerColor.withOpacity(0.2),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedTextColor : unselectedTextColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
