import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExploreItens extends StatelessWidget {
  final List<String> itens;
  final int buttonType;
  final String selectedTab;
  final Function(String) onTabSelected;

  const ExploreItens({
    super.key,
    required this.itens,
    required this.buttonType,
    required this.selectedTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Map para associar cada aba a um ícone SVG
    final Map<String, String> tabIcons = {
      "Livros": "assets/icons/books.svg",
      "Autores": "assets/icons/autores.svg",
      "Rotas": "assets/icons/rotas.svg",
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: itens.map((tab) {
        final isSelected = tab == selectedTab;
        final iconPath = tabIcons[tab] ?? '';

        return GestureDetector(
          onTap: () => onTabSelected(tab),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFCDE7BE) // Cor do botão selecionado
                  : const Color(0xFF313333)
                      .withOpacity(0.2), // Cor do não selecionado
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFCDE7BE) // Borda do botão selecionado
                    : const Color(0xFF313333)
                        .withOpacity(0.5), // Borda do não selecionado
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconPath.isNotEmpty) ...[
                  SvgPicture.asset(
                    iconPath,
                    color: isSelected
                        ? const Color(0xFF000000) // Cor do ícone selecionado
                        : const Color(0xFFFFFFFF)
                            .withOpacity(0.7), // Cor do ícone não selecionado
                    height: 20,
                    width: 20,
                  ),
                  const SizedBox(width: 8), // Espaço entre o ícone e o texto
                ],
                Text(
                  tab,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF000000) // Texto do botão selecionado
                        : const Color(0xFFFFFFFF)
                            .withOpacity(0.7), // Texto do não selecionado
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
