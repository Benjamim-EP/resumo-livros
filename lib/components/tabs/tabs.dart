import 'package:flutter/material.dart';
import 'tab_item.dart';

class Tabs extends StatelessWidget {
  final Function(String)
      onTabSelected; // Callback para passar a aba selecionada.
  final String selectedTab; // Aba atualmente selecionada.

  final List<String> _tabs = const [
    'Lendo',
    'Salvos',
    'Destaques',
    'Notas',
    'Diário'
  ];
  Tabs({required this.onTabSelected, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    // <<< MODIFICAÇÃO: Usa a lista _tabs e ajusta o layout se necessário >>>
    return SingleChildScrollView(
      // Permite rolagem se as abas não couberem
      scrollDirection: Axis.horizontal,
      child: Row(
        // Usar MainAxisAlignment.start se quiser alinhar à esquerda com rolagem
        mainAxisAlignment: MainAxisAlignment.spaceAround, // Ou spaceEvenly
        children: _tabs.map((label) {
          // Adiciona um pouco de padding horizontal para cada item
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TabItem(
              label: label,
              isSelected: selectedTab == label,
              onTap: () => onTabSelected(label),
            ),
          );
        }).toList(),
      ),
    );
    // <<< FIM MODIFICAÇÃO >>>
  }
}
