import 'package:flutter/material.dart';
import 'tab_item.dart';

class Tabs extends StatelessWidget {
  final Function(String)
      onTabSelected; // Callback para passar a aba selecionada.
  final String selectedTab; // Aba atualmente selecionada.

  Tabs({required this.onTabSelected, required this.selectedTab});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TabItem(
          label: 'Lendo',
          isSelected: selectedTab == 'Lendo',
          onTap: () => onTabSelected('Lendo'),
        ),
        TabItem(
          label: 'Salvos',
          isSelected: selectedTab == 'Salvos',
          onTap: () => onTabSelected('Salvos'),
        ),
        TabItem(
          label: 'Diário',
          isSelected: selectedTab == 'Diário',
          onTap: () => onTabSelected('Diário'),
        ),
      ],
    );
  }
}
