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
      distinct: true, // Otimização: só reconstrói se inProgressItems mudar
      builder: (context, viewModel) {
        // Se não houver itens em progresso, não renderiza nada.
        if (viewModel.inProgressItems.isEmpty) {
          return const SizedBox.shrink();
        }

        // Se houver itens, constrói a linha completa.
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
              height: 220, // Altura fixa para a linha horizontal
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: viewModel.inProgressItems.length,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemBuilder: (context, index) {
                  final item = viewModel.inProgressItems[index];
                  // Cria um InProgressCard para cada item na lista do Redux
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
