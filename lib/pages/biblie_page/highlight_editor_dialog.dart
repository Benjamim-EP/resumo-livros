// lib/pages/biblie_page/highlight_editor_dialog.dart
import 'package:flutter/material.dart';

// Classe para encapsular o resultado do diálogo.
// Permite retornar múltiplos valores (cor, tags, ação de remover) de forma organizada.
class HighlightResult {
  final String? colorHex;
  final List<String> tags;
  final bool shouldRemove;

  HighlightResult({
    this.colorHex,
    required this.tags,
    this.shouldRemove = false,
  });
}

// O Widget agora é um StatefulWidget. Ele não tem mais nenhuma conexão direta com o Redux.
// Ele é um componente de UI "puro" que recebe os dados de que precisa via construtor.
class HighlightEditorDialog extends StatefulWidget {
  final String? initialColor;
  final List<String> initialTags;
  final List<String> allUserTags; // Recebe a lista de todas as tags do usuário

  const HighlightEditorDialog({
    super.key,
    this.initialColor,
    this.initialTags = const [],
    required this.allUserTags, // Parâmetro obrigatório
  });

  @override
  State<HighlightEditorDialog> createState() => _HighlightEditorDialogState();
}

class _HighlightEditorDialogState extends State<HighlightEditorDialog> {
  late final TextEditingController _textController;
  late Set<String> _currentTags;
  String? _selectedColorHex;

  static const List<String> _defaultColorsHex = [
    "#FFFF00",
    "#90EE90",
    "#ADD8E6",
    "#FFB6C1",
    "#FFA07A"
  ];

  @override
  void initState() {
    super.initState();
    _currentTags = Set<String>.from(widget.initialTags);
    _selectedColorHex = widget.initialColor;
    _textController = TextEditingController();
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final newTag = _textController.text.trim();
    if (newTag.isNotEmpty && _currentTags.length < 7) {
      setState(() => _currentTags.add(newTag));
      _textController.clear();
    }
  }

  void _addTagFromSuggestion(String tag) {
    if (_currentTags.length < 7) {
      setState(() => _currentTags.add(tag));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchQuery = _textController.text.toLowerCase();
    final List<String> availableSuggestions = widget.allUserTags
        .where((tag) => !_currentTags.contains(tag))
        .where((tag) => tag.toLowerCase().contains(searchQuery))
        .toList();

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      title: Text("Destaque e Tags",
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Escolha uma cor:", style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _defaultColorsHex.map((colorHex) {
                  final color =
                      Color(int.parse(colorHex.replaceFirst('#', '0xff')));
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorHex = colorHex),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _selectedColorHex == colorHex
                            ? Border.all(
                                color: theme.colorScheme.primary, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 32),
              Text("Adicione tags (opcional, máx. 7):",
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: "Nova tag ou filtre abaixo...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addTagFromInput,
                  ),
                ),
                onSubmitted: (_) => _addTagFromInput(),
              ),
              const SizedBox(height: 12),
              if (_currentTags.isNotEmpty)
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: _currentTags
                      .map((tag) => Chip(
                            label: Text(tag),
                            onDeleted: () =>
                                setState(() => _currentTags.remove(tag)),
                          ))
                      .toList(),
                ),
              const Divider(height: 24),
              Text("Tags disponíveis:", style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (availableSuggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    widget.allUserTags.isEmpty
                        ? "Nenhuma tag salva ainda."
                        : "Nenhuma tag encontrada para '${_textController.text}'.",
                    style: TextStyle(
                        color: theme.hintColor, fontStyle: FontStyle.italic),
                  ),
                )
              else
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: availableSuggestions
                      .take(20)
                      .map((tag) => InkWell(
                            onTap: () => _addTagFromSuggestion(tag),
                            borderRadius: BorderRadius.circular(20),
                            child: Chip(
                              label: Text(tag,
                                  style: const TextStyle(fontSize: 11)),
                              avatar: const Icon(Icons.add, size: 14),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ))
                      .toList(),
                )
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initialColor != null)
          TextButton(
            onPressed: () => Navigator.of(context)
                .pop(HighlightResult(shouldRemove: true, tags: [])),
            child: Text("Remover Destaque",
                style: TextStyle(color: theme.colorScheme.error)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text("Cancelar"),
        ),
        FilledButton(
          onPressed: _selectedColorHex == null
              ? null
              : () => Navigator.of(context).pop(
                    HighlightResult(
                      colorHex: _selectedColorHex,
                      tags: _currentTags.toList(),
                    ),
                  ),
          child: const Text("Salvar"),
        ),
      ],
    );
  }
}
