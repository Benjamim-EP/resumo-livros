//components/tabs/tabs.dart
import 'package:flutter/material.dart';
import 'tab_item.dart';

class Tabs extends StatelessWidget {
  final Function(String)
      onTabSelected; // Callback para passar a aba selecionada.
  final String selectedTab; // Aba atualmente selecionada.

  final List<String> _tabs = const [
    'Lendo',
    'Salvos',
    'Histórico',
    'Destaques',
    'Notas',
    'Diário'
  ];
  Tabs({required this.onTabSelected, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround, // Ou spaceEvenly, ou start
        children: _tabs.map((label) {
          return Padding(
            // Adiciona um padding para espaçamento, especialmente útil com rolagem
            padding: const EdgeInsets.symmetric(
                horizontal: 10.0), // Ajuste o padding
            child: TabItem(
              label: label,
              isSelected: selectedTab == label,
              onTap: () => onTabSelected(label),
            ),
          );
        }).toList(),
      ),
    );
  }
}
