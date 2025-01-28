import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';

class UserInfo extends StatelessWidget {
  void _editField(BuildContext context, String title, String initialValue,
      Function(String) onSave) {
    final TextEditingController controller =
        TextEditingController(text: initialValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Digite o novo $title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                onSave(controller.text.trim());
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>>(
      converter: (store) => store.state.userState.userDetails ?? {},
      builder: (context, userDetails) {
        final nome = userDetails['nome'] ?? '';
        final descricao = userDetails['descrição'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    color: Color(0xFFCDE7BE),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(width: 4), // Espaço entre o texto e o ícone
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFFCDE7BE)),
                  onPressed: () {
                    _editField(context, 'Nome', nome, (newValue) {
                      StoreProvider.of<AppState>(context)
                          .dispatch(UpdateUserFieldAction('nome', newValue));
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    descricao,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC4CCCC),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(width: 4), // Espaço entre o texto e o ícone
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFFC4CCCC)),
                  onPressed: () {
                    _editField(context, 'Descrição', descricao, (newValue) {
                      StoreProvider.of<AppState>(context).dispatch(
                          UpdateUserFieldAction('descrição', newValue));
                    });
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
