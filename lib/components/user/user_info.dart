// lib/components/user/user_info.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

class UserInfo extends StatelessWidget {
  const UserInfo({super.key});

  @override
  Widget build(BuildContext context) {
    // Obter o tema atual
    final ThemeData theme = Theme.of(context);

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
              textAlign: TextAlign.center,
              style: TextStyle(
                // Usar uma cor primária do tema ou uma cor de texto proeminente
                color: theme.colorScheme
                    .primary, // OU theme.textTheme.titleLarge?.color
                fontSize: 20,
                fontWeight: FontWeight.w600,
                // fontFamily: 'Inter', // O fontFamily será herdado do tema geral se não especificado aqui
                // Se você definiu textTheme.titleLarge para usar 'Inter', não precisa repetir.
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                descricao.isNotEmpty
                    ? descricao
                    : "Adicione uma descrição nas configurações.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  // Usar uma cor de texto secundária do tema
                  color: theme.textTheme.bodyMedium
                      ?.color, // OU theme.colorScheme.onSurface.withOpacity(0.7)
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  // fontFamily: 'Inter', // Idem acima, provavelmente herdado
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
