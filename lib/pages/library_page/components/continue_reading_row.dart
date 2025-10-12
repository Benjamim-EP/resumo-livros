// lib/pages/library_page/components/continue_reading_row.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'in_progress_card.dart';

// ViewModel para conectar o widget ao estado Redux
class _ViewModel {
  final List<Map<String, dynamic>> inProgressItems;

  _ViewModel({required this.inProgressItems});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      inProgressItems: store.state.userState.inProgressItems,
    );
  }
}

class ContinueReadingRow extends StatelessWidget {
  const ContinueReadingRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _ViewModel>(
      converter: _ViewModel.fromStore,
      distinct: true,
      builder: (context, viewModel) {
        // <<< INÍCIO DA CORREÇÃO >>>
        // Filtramos a lista para remover qualquer item cujo ID comece com 'sermon_'.
        // Isso garante que apenas livros e outros recursos da biblioteca sejam exibidos.
        final filteredItems = viewModel.inProgressItems.where((item) {
          final contentId = item['contentId'] as String?;
          // Se o ID não for nulo E NÃO começar com 'sermon_', o item é mantido.
          return contentId != null && !contentId.startsWith('sermon_');
        }).toList();
        // <<< FIM DA CORREÇÃO >>>

        // Se a lista filtrada estiver vazia, não renderiza nada.
        if (filteredItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                "Continuar Lendo",
                style: theme.textTheme.titleLarge,
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                // <<< CORREÇÃO AQUI: Usa a contagem da lista filtrada >>>
                itemCount: filteredItems.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  // <<< CORREÇÃO AQUI: Pega o item da lista filtrada >>>
                  final item = filteredItems[index];
                  return InProgressCard(progressData: item);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
