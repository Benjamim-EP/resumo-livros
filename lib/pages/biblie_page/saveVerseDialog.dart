import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class SaveVerseDialog extends StatefulWidget {
  final String bookAbbrev; // Exemplo: "gn"
  final int chapter;
  final int verseNumber;

  const SaveVerseDialog({
    super.key,
    required this.bookAbbrev,
    required this.chapter,
    required this.verseNumber,
  });

  @override
  State<SaveVerseDialog> createState() => _SaveVerseDialogState();
}

class _SaveVerseDialogState extends State<SaveVerseDialog> {
  late TextEditingController collectionController;

  @override
  void initState() {
    super.initState();
    collectionController = TextEditingController();
  }

  @override
  void dispose() {
    collectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, List<String>>>(
      onInit: (store) {
        if (store.state.userState.topicSaves.isEmpty) {
          store.dispatch(LoadUserCollectionsAction());
        }
      },
      converter: (store) => store.state.userState.topicSaves,
      builder: (context, topicSaves) {
        final verseId =
            "bibleverses-${widget.bookAbbrev}-${widget.chapter}-${widget.verseNumber}";

        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          title: const Text(
            'Salvar Versículo',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selecione ou crie uma coleção:',
                  style: TextStyle(color: Colors.white70),
                ),
                if (topicSaves.isNotEmpty)
                  ...topicSaves.keys.map((collectionName) {
                    return ListTile(
                      title: Text(
                        collectionName,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        if (!topicSaves[collectionName]!.contains(verseId)) {
                          StoreProvider.of<AppState>(context).dispatch(
                            SaveVerseToCollectionAction(
                                collectionName, verseId),
                          );
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              'Versículo já está salvo na coleção "$collectionName".',
                            ),
                          ));
                        }
                      },
                    );
                  }),
                const SizedBox(height: 16),
                TextField(
                  controller: collectionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nova coleção',
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
              onPressed: () {
                final newCollection = collectionController.text.trim();
                if (newCollection.isNotEmpty) {
                  StoreProvider.of<AppState>(context).dispatch(
                    SaveVerseToCollectionAction(newCollection, verseId),
                  );
                  Navigator.of(context).pop();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.green,
              ),
              child: const Text('Criar e Salvar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );
  }
}
