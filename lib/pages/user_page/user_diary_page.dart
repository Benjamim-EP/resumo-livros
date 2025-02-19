import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/add_diary_dialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/diary_list.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class UserDiaryPage extends StatelessWidget {
  const UserDiaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<Map<String, dynamic>>>(
      converter: (store) => store.state.userState.userDiaries,
      onInit: (store) {
        if (store.state.userState.userDiaries.isEmpty) {
          store.dispatch(LoadUserDiariesAction());
        }
      },
      builder: (context, userDiaries) {
        return Column(
          children: [
            // 🔹 Botão para adicionar uma nova nota
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => showAddDiaryDialog(context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Adicionar Nota",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF129575),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            // 🔹 Lista de diários
            Expanded(child: DiaryList(userDiaries: userDiaries)),
          ],
        );
      },
    );
  }
}
