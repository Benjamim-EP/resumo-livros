// lib/pages/library_page/components/in_progress_card.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/library_page.dart'; // Importa para acessar allLibraryItems
import 'package:septima_biblia/services/custom_page_route.dart';

class InProgressCard extends StatelessWidget {
  /// Contém os dados de progresso vindos do Redux (Firestore).
  /// Ex: {'contentId': 'o-peregrino', 'progressPercentage': 0.45, ...}
  final Map<String, dynamic> progressData;

  const InProgressCard({super.key, required this.progressData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String contentId = progressData['contentId'] ?? '';
    final double progressPercentage =
        (progressData['progressPercentage'] as num?)?.toDouble() ?? 0.0;

    final fullItemData = allLibraryItems.firstWhere(
      (item) => item['id'] == contentId,
      orElse: () => {},
    );

    if (fullItemData.isEmpty) {
      print(
          "InProgressCard: ERRO - Não foi possível encontrar metadados para o contentId: '$contentId'");
      return const SizedBox(
        width: 120,
        child: Center(child: Text("Item não encontrado")),
      );
    }

    final String title = fullItemData['title'] ?? 'Sem Título';
    final String coverPath = fullItemData['coverImagePath'] ?? '';
    final Widget destinationPage = fullItemData['destinationPage'];

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            FadeScalePageRoute(page: destinationPage),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 120,
          // <<< INÍCIO DA CORREÇÃO >>>
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // mainAxisSize foi removido, permitindo que a Column ocupe toda a altura disponível (220px)
            children: [
              // O AspectRatio agora está dentro de um Expanded,
              // tornando-o flexível para ocupar o espaço vertical restante.
              Expanded(
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Card(
                    elevation: 4,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverPath.isNotEmpty)
                          Image.asset(coverPath, fit: BoxFit.cover)
                        else
                          Container(color: theme.colorScheme.surfaceVariant),
                        Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            color: Colors.white.withOpacity(0.8),
                            size: 40,
                            shadows: const [
                              Shadow(blurRadius: 6, color: Colors.black54)
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // <<< FIM DA CORREÇÃO >>>
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  color: theme.colorScheme.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
