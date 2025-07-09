// lib/components/user/user_info.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';

class UserInfo extends StatelessWidget {
  const UserInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return StoreConnector<AppState, Map<String, dynamic>>(
      // O converter continua o mesmo, pois ele já pega todos os detalhes
      converter: (store) => store.state.userState.userDetails ?? {},
      builder: (context, userDetails) {
        final nome = userDetails['nome'] ?? 'Nome não definido';
        final descricao = userDetails['descrição'] ?? 'Sem descrição';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // O nome agora ocupa toda a largura disponível
            Text(
              nome,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2, // Permite que nomes mais longos quebrem a linha
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // A descrição permanece igual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Text(
                descricao.isNotEmpty
                    ? descricao
                    : "Adicione uma descrição nas configurações.",
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
