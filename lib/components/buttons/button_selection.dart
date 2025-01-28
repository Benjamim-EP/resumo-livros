import 'package:flutter/material.dart';

class ButtonSelectionWidget extends StatelessWidget {
  final int selectedIndex; // Índice da aba selecionada
  final Function(int)
      onTabSelected; // Callback para notificar o índice selecionado

  ButtonSelectionWidget(
      {required this.selectedIndex, required this.onTabSelected});

  final List<String> _options = ["Livros", "Rotas", "Reviews", "Similares"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _options.asMap().entries.map((entry) {
          int index = entry.key;
          String option = entry.value;

          bool isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () {
              onTabSelected(index); // Chama o callback ao selecionar uma aba
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.greenAccent.shade100
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16.0,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
