// lib/pages/biblie_page/font_size_slider_dialog.dart

import 'package:flutter/material.dart';

class FontSizeSliderDialog extends StatefulWidget {
  final double initialSize;
  final double minSize;
  final double maxSize;
  final Function(double) onSizeChanged;

  const FontSizeSliderDialog({
    super.key,
    required this.initialSize,
    required this.minSize,
    required this.maxSize,
    required this.onSizeChanged,
  });

  @override
  State<FontSizeSliderDialog> createState() => _FontSizeSliderDialogState();
}

class _FontSizeSliderDialogState extends State<FontSizeSliderDialog> {
  late double _currentSize;

  @override
  void initState() {
    super.initState();
    _currentSize = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      title: const Text("Ajustar Tamanho da Fonte"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Exemplo de texto para visualização
          Text(
            "O Senhor é o meu pastor; nada me faltará.",
            style: TextStyle(
                fontSize: _currentSize,
                color: theme.textTheme.bodyLarge?.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // O Slider
          Slider(
            value: _currentSize,
            min: widget.minSize,
            max: widget.maxSize,
            divisions: ((widget.maxSize - widget.minSize) / 0.5)
                .round(), // Controla os "passos" do slider
            label: _currentSize.toStringAsFixed(1),
            onChanged: (double value) {
              setState(() {
                _currentSize = value;
              });
              // Chama o callback em tempo real para a UI principal atualizar
              widget.onSizeChanged(value);
            },
          ),
          // Ícones de - e + para referência visual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.text_fields_rounded, size: widget.minSize + 4),
              Icon(Icons.text_fields_rounded, size: widget.maxSize + 4),
            ],
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    );
  }
}
