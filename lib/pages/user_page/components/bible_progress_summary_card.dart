// lib/pages/user_page/components/bible_progress_summary_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para BibleBookProgressData
import 'package:septima_biblia/redux/store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ 1. VIEWMODEL DEFINIDO DENTRO DO PRÓPRIO ARQUIVO
// Agora este componente é autônomo e não depende da user_page.dart
class _UserProgressViewModel {
  final String? userId;
  final bool isLoadingCounts;
  final bool isLoadingUserProgress;
  final Map<String, BibleBookProgressData> allBooksProgress;
  final Map<String, dynamic> bibleSectionCounts;
  final String? countsError;
  final String? userProgressError;

  _UserProgressViewModel({
    this.userId,
    required this.isLoadingCounts,
    required this.isLoadingUserProgress,
    required this.allBooksProgress,
    required this.bibleSectionCounts,
    this.countsError,
    this.userProgressError,
  });

  static _UserProgressViewModel fromStore(Store<AppState> store) {
    return _UserProgressViewModel(
      userId: store.state.userState.userId,
      isLoadingCounts: store.state.metadataState.isLoadingSectionCounts,
      isLoadingUserProgress: store.state.userState.isLoadingAllBibleProgress,
      allBooksProgress: store.state.userState.allBooksProgress,
      bibleSectionCounts: store.state.metadataState.bibleSectionCounts,
      countsError: store.state.metadataState.sectionCountsError,
      userProgressError: store.state.userState.bibleProgressError,
    );
  }
}

class BibleProgressSummaryCard extends StatelessWidget {
  const BibleProgressSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StoreConnector<AppState, _UserProgressViewModel>(
          converter: (store) => _UserProgressViewModel.fromStore(store),
          distinct: true,
          builder: (context, vm) {
            if (vm.isLoadingCounts || vm.isLoadingUserProgress) {
              return const Center(
                  heightFactor: 3, child: CircularProgressIndicator());
            }

            // ✅ 2. CORREÇÃO DE TIPAGEM: Usamos .toInt() para garantir que o valor seja um inteiro.
            int totalSectionsInBible =
                (vm.bibleSectionCounts['total_secoes_biblia'] as num? ?? 1)
                    .toInt()
                    .clamp(1, 1000000);
            int totalReadSectionsBible = vm.allBooksProgress.values
                .fold<int>(0, (sum, book) => sum + book.readSections.length);
            double overallProgress = (totalSectionsInBible > 0)
                ? (totalReadSectionsBible / totalSectionsInBible)
                    .clamp(0.0, 1.0)
                : 0.0;

            int totalSectionsInAT =
                (vm.bibleSectionCounts['total_secoes_antigo_testamento']
                            as num? ??
                        1)
                    .toInt()
                    .clamp(1, 1000000);
            int totalSectionsInNT =
                (vm.bibleSectionCounts['total_secoes_novo_testamento']
                            as num? ??
                        1)
                    .toInt()
                    .clamp(1, 1000000);

            int totalReadSectionsAT = 0;
            int totalReadSectionsNT = 0;
            final booksMetadataFromCounts =
                vm.bibleSectionCounts['livros'] as Map<String, dynamic>? ?? {};

            vm.allBooksProgress.forEach((bookAbbrev, progressData) {
              final String? testament =
                  booksMetadataFromCounts[bookAbbrev]?['testamento'] as String?;
              if (testament == "Antigo") {
                totalReadSectionsAT += progressData.readSections.length;
              } else if (testament == "Novo") {
                totalReadSectionsNT += progressData.readSections.length;
              }
            });

            double atProgress = (totalSectionsInAT > 0)
                ? (totalReadSectionsAT / totalSectionsInAT).clamp(0.0, 1.0)
                : 0.0;
            double ntProgress = (totalSectionsInNT > 0)
                ? (totalReadSectionsNT / totalSectionsInNT).clamp(0.0, 1.0)
                : 0.0;

            return Column(
              children: [
                Text("Progresso Geral da Bíblia",
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      child: CircularPercentIndicator(
                        radius: 45.0,
                        lineWidth: 10.0,
                        percent: overallProgress,
                        center: Text(
                          "${(overallProgress * 100).toStringAsFixed(1)}%",
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: theme.colorScheme.primary,
                        backgroundColor:
                            theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: [
                          _buildTestamentProgressCard(
                              context,
                              "Antigo Testamento",
                              atProgress,
                              totalReadSectionsAT,
                              totalSectionsInAT,
                              Colors.orange.shade700),
                          const SizedBox(height: 12),
                          _buildTestamentProgressCard(
                              context,
                              "Novo Testamento",
                              ntProgress,
                              totalReadSectionsNT,
                              totalSectionsInNT,
                              Colors.teal.shade600),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Você leu $totalReadSectionsBible de $totalSectionsInBible seções!",
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Widget auxiliar para os cards internos de AT e NT
  Widget _buildTestamentProgressCard(
    BuildContext context,
    String title,
    double progress,
    int readSections,
    int totalSections,
    Color progressColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            percent: progress,
            lineHeight: 12.0,
            barRadius: const Radius.circular(6),
            backgroundColor: progressColor.withOpacity(0.2),
            progressColor: progressColor,
            center: Text(
              "${(progress * 100).toStringAsFixed(0)}%",
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "$readSections / $totalSections seções",
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
