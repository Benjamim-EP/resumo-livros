// lib/pages/biblie_page/tag_editor_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';

class TagEditorDialog extends StatefulWidget {
  final List<String> initialTags;

  const TagEditorDialog({
    super.key,
    this.initialTags = const [],
  });

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  late final TextEditingController _textController;
  late final Set<String> _currentTags;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _currentTags = Set<String>.from(widget.initialTags);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addTagFromInput() {
    final newTag = _textController.text.trim();
    if (newTag.isNotEmpty && _currentTags.length < 7) {
      setState(() {
        _currentTags.add(newTag);
      });
      _textController.clear();
    }
  }

  void _addTagFromSuggestion(String tag) {
    if (_currentTags.length < 7) {
      setState(() {
        _currentTags.add(tag);
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _currentTags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      title: Text("Adicionar Tags (Máx. 7)",
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18)),
      content: StoreConnector<AppState, List<String>>(
        converter: (store) => store.state.userState.allUserTags,
        builder: (context, allUserTags) {
          final suggestedTags =
              allUserTags.where((tag) => !_currentTags.contains(tag)).toList();

          return SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de texto para nova tag
                  TextField(
                    controller: _textController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Nova tag...",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _addTagFromInput,
                      ),
                    ),
                    onSubmitted: (_) => _addTagFromInput(),
                  ),
                  const SizedBox(height: 16),

                  // Tags atualmente selecionadas
                  if (_currentTags.isNotEmpty) ...[
                    Text("Tags Selecionadas:",
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: _currentTags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          onDeleted: () => _removeTag(tag),
                          deleteIconColor:
                              theme.colorScheme.error.withOpacity(0.7),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                  ],

                  // Tags sugeridas
                  if (suggestedTags.isNotEmpty) ...[
                    Text("Sugestões:", style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: suggestedTags.map((tag) {
                        return InkWell(
                          onTap: () => _addTagFromSuggestion(tag),
                          borderRadius: BorderRadius.circular(20),
                          child: Chip(
                            label: Text(tag),
                            avatar: const Icon(Icons.add, size: 16),
                            backgroundColor: theme.colorScheme.surfaceVariant,
                          ),
                        );
                      }).toList(),
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancelar"),
        ),
        FilledButton(
          onPressed: () {
            // Retorna a lista final de tags para a chamada anterior
            Navigator.of(context).pop(_currentTags.toList());
          },
          child: const Text("Salvar"),
        ),
      ],
    );
  }
}
