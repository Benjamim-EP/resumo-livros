// lib/pages/biblie_page/highlight_color_picker_modal.dart
import 'package:flutter/material.dart';

class HighlightColorPickerModal extends StatelessWidget {
  final String? initialColor; // Hex string, e.g., "#FFFF00"
  final Function(String) onColorSelected;
  final VoidCallback onRemoveHighlight;

  const HighlightColorPickerModal({
    super.key,
    this.initialColor,
    required this.onColorSelected,
    required this.onRemoveHighlight,
  });

  // Cores predefinidas para o picker
  static const List<String> _defaultColorsHex = [
    "#FFFF00", // Amarelo
    "#90EE90", // Verde Claro
    "#ADD8E6", // Azul Claro
    "#FFB6C1", // Rosa Claro
    "#FFA07A", // Salmão Claro
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2F33),
      title: const Text("Escolher Cor do Destaque",
          style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _defaultColorsHex.map((colorHex) {
                final color =
                    Color(int.parse(colorHex.replaceFirst('#', '0xff')));
                final bool isSelected = initialColor == colorHex;
                return GestureDetector(
                  onTap: () {
                    onColorSelected(colorHex);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          )
                        ]),
                  ),
                );
              }).toList(),
            ),
            if (initialColor != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                icon: const Icon(Icons.delete_forever_outlined,
                    color: Colors.redAccent),
                label: const Text("Remover Destaque",
                    style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  onRemoveHighlight();
                  Navigator.of(context).pop();
                },
              ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text("Cancelar", style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}
