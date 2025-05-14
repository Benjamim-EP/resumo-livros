// lib/components/user/user_info.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
// Não precisaremos mais de UpdateUserFieldAction ou showDialog aqui

class UserInfo extends StatelessWidget {
  const UserInfo({super.key});

  // Removida a função _editField, pois a edição será em outra página

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, Map<String, dynamic>>(
      converter: (store) => store.state.userState.userDetails ?? {},
      builder: (context, userDetails) {
        final nome = userDetails['nome'] ?? 'Nome não definido';
        final descricao = userDetails['descrição'] ?? 'Sem descrição';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              nome,
              textAlign: TextAlign
                  .center, // Garante centralização se o texto for longo
              style: const TextStyle(
                color: Color(0xFFCDE7BE),
                fontSize: 20, // Pode aumentar um pouco se não tiver o ícone
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              // Adiciona padding para a descrição
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                descricao.isNotEmpty
                    ? descricao
                    : "Adicione uma descrição nas configurações.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFC4CCCC),
                  fontSize: 14, // Pode aumentar um pouco
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                  height: 1.4, // Melhora a legibilidade de múltiplas linhas
                ),
                maxLines: 3, // Limita o número de linhas visíveis
                overflow: TextOverflow.ellipsis, // Adiciona '...' se exceder
              ),
            ),
          ],
        );
      },
    );
  }
}
