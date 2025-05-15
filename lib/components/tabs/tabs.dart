// components/tabs/tabs.dart
import 'package:flutter/material.dart';
import 'tab_item.dart';

class Tabs extends StatelessWidget {
  final List<String> tabs; // NOVO: Recebe a lista de abas
  final Function(String) onTabSelected;
  final String selectedTab;

  const Tabs({
    super.key,
    required this.tabs, // NOVO
    required this.onTabSelected,
    required this.selectedTab,
  });

  // REMOVIDO: final List<String> _tabs = const [ ... ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: tabs.map((label) {
          // USA a lista `tabs` recebida
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
