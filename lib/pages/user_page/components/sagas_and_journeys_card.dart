// lib/pages/user_page/components/sagas_and_journeys_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/models/bible_saga_model.dart';
import 'package:septima_biblia/pages/user_page/components/saga_progress_card.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';
import 'package:septima_biblia/redux/store.dart';

class SagasAndJourneysCard extends StatelessWidget {
  const SagasAndJourneysCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sagas e Jornadas", style: theme.textTheme.headlineSmall),
            const Divider(height: 24),
            StoreConnector<AppState, List<BibleSaga>>(
              onInit: (store) {
                print(
                    "✅ SagasAndJourneysCard: onInit - Despachando LoadBibleSagasAction...");
                // Dispara a ação para carregar as sagas quando o widget for construído
                store.dispatch(LoadBibleSagasAction());
              },
              converter: (store) => store.state.metadataState.bibleSagas,
              builder: (context, sagas) {
                if (sagas.isEmpty) {
                  // Você pode mostrar um loader aqui se quiser
                  return const Center(child: Text("Nenhuma saga encontrada."));
                }

                // Separa as sagas por tipo
                final personagens =
                    sagas.where((s) => s.type == 'personagem').toList();
                final eventos = sagas.where((s) => s.type == 'evento').toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (personagens.isNotEmpty) ...[
                      Text("Jornadas de Personagens",
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...personagens
                          .map((saga) => SagaProgressCard(saga: saga)),
                      const SizedBox(height: 24),
                    ],
                    if (eventos.isNotEmpty) ...[
                      Text("Grandes Eventos",
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      ...eventos.map((saga) => SagaProgressCard(saga: saga)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
