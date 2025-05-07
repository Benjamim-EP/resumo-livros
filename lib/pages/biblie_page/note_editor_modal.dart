// lib/pages/biblie_page/note_editor_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class NoteEditorModal extends StatefulWidget {
  final String verseId;
  final String? initialText;
  final String bookReference;
  final String verseTextSample;

  const NoteEditorModal({
    Key? key,
    required this.verseId,
    this.initialText,
    required this.bookReference,
    required this.verseTextSample,
  }) : super(key: key);

  @override
  State<NoteEditorModal> createState() => _NoteEditorModalState();
}

class _NoteEditorModalState extends State<NoteEditorModal> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2F33),
      title: Text("Nota para ${widget.bookReference}",
          style: const TextStyle(color: Colors.white, fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.verseTextSample,
              style: const TextStyle(
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Digite sua nota aqui...",
                hintStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:
              const Text("Cancelar", style: TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () {
            final noteText = _textController.text.trim();
            if (noteText.isNotEmpty) {
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(SaveNoteAction(widget.verseId, noteText));
            } else {
              // Se o texto estiver vazio, considera remover a nota (ou não salvar)
              StoreProvider.of<AppState>(context, listen: false)
                  .dispatch(DeleteNoteAction(widget.verseId));
            }
            Navigator.of(context).pop();
          },
          child: const Text("Salvar", style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}
