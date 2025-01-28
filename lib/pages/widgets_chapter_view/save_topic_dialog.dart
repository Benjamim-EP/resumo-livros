import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class SaveTopicDialog extends StatefulWidget {
  final String topicId;

  const SaveTopicDialog({super.key, required this.topicId});

  @override
  State<SaveTopicDialog> createState() => _SaveTopicDialogState();
}

class _SaveTopicDialogState extends State<SaveTopicDialog> {
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
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2F33),
          title: const Text(
            'Salvar Tópico',
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
                        if (!topicSaves[collectionName]!
                            .contains(widget.topicId)) {
                          StoreProvider.of<AppState>(context).dispatch(
                            SaveTopicToCollectionAction(
                                collectionName, widget.topicId),
                          );
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                              'Tópico já está salvo na coleção "$collectionName".',
                            ),
                          ));
                        }
                      },
                    );
                  }).toList(),
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
                    SaveTopicToCollectionAction(newCollection, widget.topicId),
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
