// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals and mapEquals
import 'package:resumo_dos_deuses_flutter/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart';
import 'package:intl/intl.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/metadata_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para BibleBookProgressData
import 'package:percent_indicator/percent_indicator.dart';
import 'package:resumo_dos_deuses_flutter/consts/bible_constants.dart';

enum HighlightType { verses, comments }

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  Map<String, dynamic>? _localBooksMap;
  bool _isLoadingBooksMap = true;
  String _selectedTab = 'Progresso'; // Aba padrão
  HighlightType _selectedHighlightType = HighlightType.verses;

  final List<String> _availableTabs = const [
    'Progresso',
    'Destaques',
    'Notas',
    'Histórico',
    'Diário'
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalBooksMap();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);

      // Carrega contagens de seções se não estiverem carregadas e não estiverem carregando
      if (storeInstance.state.metadataState.bibleSectionCounts.isEmpty &&
          !storeInstance.state.metadataState.isLoadingSectionCounts) {
        print("UserPage initState: Disparando LoadBibleSectionCountsAction");
        storeInstance.dispatch(LoadBibleSectionCountsAction());
      }
      // Carrega progresso de todos os livros se não estiver carregado e não estiver carregando
      if (storeInstance.state.userState.allBooksProgress.isEmpty &&
          storeInstance.state.userState.userId != null &&
          !storeInstance.state.userState.isLoadingAllBibleProgress) {
        print("UserPage initState: Disparando LoadAllBibleProgressAction");
        storeInstance.dispatch(LoadAllBibleProgressAction());
      }

      // Outros carregamentos
      if (storeInstance.state.userState.userId != null) {
        storeInstance.dispatch(LoadUserStatsAction());
        storeInstance.dispatch(LoadUserDiariesAction());
        storeInstance.dispatch(LoadReadingHistoryAction());
        if (storeInstance.state.userState.userHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserHighlightsAction());
        }
        if (storeInstance.state.userState.userCommentHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserCommentHighlightsAction());
        }
        if (storeInstance.state.userState.userNotes.isEmpty) {
          storeInstance.dispatch(LoadUserNotesAction());
        }
      }
    });
  }

  Future<void> _loadLocalBooksMap() async {
    try {
      final map = await BiblePageHelper.loadBooksMap();
      if (mounted) {
        setState(() {
          _localBooksMap = map;
          _isLoadingBooksMap = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar booksMap localmente em UserPage: $e");
      if (mounted) {
        setState(() {
          _isLoadingBooksMap = false;
        });
      }
    }
  }

  void _onTabSelected(String tab) {
    if (mounted) {
      setState(() {
        _selectedTab = tab;
      });
      // Se a aba "Progresso" for selecionada e os dados ainda não foram carregados/estão sendo carregados,
      // a lógica no onInit do StoreConnector dela cuidará disso.
      if (tab == 'Progresso') {
        final storeInstance =
            StoreProvider.of<AppState>(context, listen: false);
        if (storeInstance.state.metadataState.bibleSectionCounts.isEmpty &&
            !storeInstance.state.metadataState.isLoadingSectionCounts) {
          storeInstance.dispatch(LoadBibleSectionCountsAction());
        }
        if (storeInstance.state.userState.allBooksProgress.isEmpty &&
            storeInstance.state.userState.userId != null &&
            !storeInstance.state.userState.isLoadingAllBibleProgress) {
          storeInstance.dispatch(LoadAllBibleProgressAction());
        }
      }
    }
  }

  void _navigateToBibleVerseAndTab(String verseId) {
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      if (chapter != null && context.mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        store.dispatch(RequestBottomNavChangeAction(2));
      }
    }
  }

  Widget _buildTestamentProgress(String title, double progress,
      int readSections, int totalSections, ThemeData theme) {
    if (totalSections == 0 && readSections == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Text(title,
                style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.secondary.withOpacity(0.7))),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              percent: 0.0,
              lineHeight: 10.0,
              barRadius: const Radius.circular(5),
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              progressColor: theme.colorScheme.secondary.withOpacity(0.3),
              center: Text("0%",
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSecondary.withOpacity(0.5))),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("0 / 0 seções",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
            ),
          ],
        ),
      );
    }
    double safeProgress = totalSections > 0
        ? (readSections / totalSections).clamp(0.0, 1.0)
        : (readSections > 0 ? 1.0 : 0.0);
    int displayTotalSections = totalSections > 0
        ? totalSections
        : (readSections > 0 ? readSections : 0);

    return Column(
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.secondary)),
        const SizedBox(height: 8),
        LinearPercentIndicator(
          percent: safeProgress,
          lineHeight: 10.0,
          barRadius: const Radius.circular(5),
          backgroundColor:
              theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          progressColor: theme.colorScheme.secondary,
          center: Text(
            "${(safeProgress * 100).toStringAsFixed(0)}%",
            style:
                TextStyle(fontSize: 10, color: theme.colorScheme.onSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text("$readSections / $displayTotalSections seções",
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _buildCommentHighlightCard(
      Map<String, dynamic> highlight, BuildContext context, ThemeData theme) {
    final String selectedSnippet =
        highlight['selectedSnippet'] ?? 'Trecho indisponível';
    final String fullCommentText =
        highlight['fullCommentText'] ?? 'Comentário completo indisponível';
    final String referenceText =
        highlight['verseReferenceText'] ?? 'Referência desconhecida';
    final String highlightId = highlight['id'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$selectedSnippet"',
              style: TextStyle(
                backgroundColor: Colors.amber.withOpacity(0.3),
                color: theme.brightness == Brightness.dark
                    ? Colors.amber[300]
                    : Colors.amber[800],
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              "No contexto de: ${fullCommentText.length > 100 ? "${fullCommentText.substring(0, 100)}..." : fullCommentText}",
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    referenceText,
                    style: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (highlightId.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error.withOpacity(0.7),
                        size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Remover Marcação do Comentário",
                    onPressed: () {
                      if (context.mounted) {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                                RemoveCommentHighlightAction(highlightId));
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final theme = Theme.of(context);
    bool stillLoadingBookNames = _isLoadingBooksMap &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico' ||
            _selectedTab == 'Progresso');

    if (stillLoadingBookNames && _selectedTab != 'Diário') {
      return Center(
          child: CircularProgressIndicator(
              color: theme.colorScheme.primary,
              key: const ValueKey("tab_content_books_map_loader")));
    }
    if (_localBooksMap == null &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico' ||
            _selectedTab == 'Progresso')) {
      return Center(
          child: Text("Erro ao carregar nomes dos livros.",
              style: TextStyle(color: theme.colorScheme.error)));
    }

    switch (_selectedTab) {
      case 'Progresso':
        return StoreConnector<AppState, _UserProgressViewModel>(
          converter: (store) => _UserProgressViewModel.fromStore(store),
          onInit: (store) {
            if (store.state.userState.allBooksProgress.isEmpty &&
                store.state.userState.userId != null &&
                !store.state.userState.isLoadingAllBibleProgress) {
              print(
                  "UserPage Progresso onInit: Disparando LoadAllBibleProgressAction");
              store.dispatch(LoadAllBibleProgressAction());
            }
            if (store.state.metadataState.bibleSectionCounts.isEmpty &&
                !store.state.metadataState.isLoadingSectionCounts) {
              print(
                  "UserPage Progresso onInit: Disparando LoadBibleSectionCountsAction");
              store.dispatch(LoadBibleSectionCountsAction());
            }
          },
          builder: (context, vm) {
            if (vm.isLoadingCounts || vm.isLoadingUserProgress) {
              return Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      key: const ValueKey("progress_tab_loader")));
            }
            if (vm.countsError != null) {
              return Center(
                  child: Text(
                "Erro ao carregar metadados: ${vm.countsError}",
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ));
            }
            if (vm.userProgressError != null) {
              return Center(
                  child: Text(
                "Erro ao carregar progresso do usuário: ${vm.userProgressError}",
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ));
            }
            if (vm.bibleSectionCounts.isEmpty &&
                vm.userId != null &&
                !vm.isLoadingCounts) {
              return Center(
                  child: Text(
                "Metadados de progresso da Bíblia não disponíveis ou erro ao carregar.",
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                textAlign: TextAlign.center,
              ));
            }

            int totalSectionsInBible =
                vm.bibleSectionCounts['total_secoes_biblia'] as int? ?? 0;
            if (totalSectionsInBible == 0 && vm.bibleSectionCounts.isNotEmpty) {
              print(
                  "AVISO UserPage Progresso: 'total_secoes_biblia' é 0 ou nulo nos metadados carregados. Verifique o JSON bible_sections_count.json.");
              totalSectionsInBible =
                  1; // Fallback para evitar divisão por zero, mas indica problema no JSON.
            } else if (totalSectionsInBible == 0) {
              totalSectionsInBible = 1;
            }

            int totalSectionsInAT =
                vm.bibleSectionCounts['total_secoes_antigo_testamento']
                        as int? ??
                    0;
            int totalSectionsInNT =
                vm.bibleSectionCounts['total_secoes_novo_testamento'] as int? ??
                    0;

            if (totalSectionsInAT == 0 && vm.bibleSectionCounts.isNotEmpty) {
              print(
                  "AVISO UserPage Progresso: 'total_secoes_antigo_testamento' é 0 ou nulo nos metadados.");
            }
            if (totalSectionsInNT == 0 && vm.bibleSectionCounts.isNotEmpty) {
              print(
                  "AVISO UserPage Progresso: 'total_secoes_novo_testamento' é 0 ou nulo nos metadados.");
            }

            if (totalSectionsInAT == 0) totalSectionsInAT = 1;
            if (totalSectionsInNT == 0) totalSectionsInNT = 1;

            int totalReadSectionsBible = 0;
            int totalReadSectionsAT = 0;
            int totalReadSectionsNT = 0;

            final booksMetadataFromCounts =
                vm.bibleSectionCounts['livros'] as Map<String, dynamic>? ?? {};

            vm.allBooksProgress.forEach((bookAbbrev, progressData) {
              totalReadSectionsBible += progressData.readSections.length;
              final String? testament =
                  booksMetadataFromCounts[bookAbbrev]?['testamento'] as String?;

              if (testament == "Antigo") {
                totalReadSectionsAT += progressData.readSections.length;
              } else if (testament == "Novo") {
                totalReadSectionsNT += progressData.readSections.length;
              }
            });

            double overallProgress =
                (totalReadSectionsBible / totalSectionsInBible).clamp(0.0, 1.0);
            double atProgress =
                (totalReadSectionsAT / totalSectionsInAT).clamp(0.0, 1.0);
            double ntProgress =
                (totalReadSectionsNT / totalSectionsInNT).clamp(0.0, 1.0);

            List<Widget> bookProgressWidgets = [];
            for (String bookAbbrev in CANONICAL_BOOK_ORDER) {
              final bookMetaFromCounts =
                  booksMetadataFromCounts[bookAbbrev] as Map<String, dynamic>?;
              final bookMetaForName =
                  _localBooksMap?[bookAbbrev] as Map<String, dynamic>?;

              if (bookMetaFromCounts == null || bookMetaForName == null) {
                continue;
              }

              final bookProgressData = vm.allBooksProgress[bookAbbrev];
              int totalSectionsInThisBook =
                  bookMetaFromCounts['total_secoes_livro'] as int? ?? 0;
              if (totalSectionsInThisBook == 0) totalSectionsInThisBook = 1;

              int readSectionsInThisBook =
                  bookProgressData?.readSections.length ?? 0;
              double bookProgressPercent =
                  (readSectionsInThisBook / totalSectionsInThisBook)
                      .clamp(0.0, 1.0);
              String bookFullName =
                  bookMetaForName['nome'] ?? bookAbbrev.toUpperCase();

              bookProgressWidgets.add(Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(bookFullName,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        theme.textTheme.titleMedium?.color))),
                        Text(
                            "${(bookProgressPercent * 100).toStringAsFixed(0)}% ($readSectionsInThisBook/$totalSectionsInThisBook)",
                            style: TextStyle(
                                fontSize: 14,
                                color: theme.textTheme.bodySmall?.color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearPercentIndicator(
                      percent: bookProgressPercent,
                      lineHeight: 12.0,
                      barRadius: const Radius.circular(6),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest
                          .withOpacity(0.5),
                      progressColor: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ));
            }

            if (vm.allBooksProgress.isEmpty &&
                vm.userId != null &&
                !vm.isLoadingUserProgress) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                    Icon(Icons.auto_stories_outlined,
                        size: 60,
                        color: theme.colorScheme.primary.withOpacity(0.7)),
                    const SizedBox(height: 20),
                    Text(
                      "Seu progresso na Bíblia aparecerá aqui!",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: theme.textTheme.bodyMedium?.color),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        "Comece a ler os livros e marcar seções como lidas para acompanhar sua jornada pela Palavra.",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.textTheme.bodySmall?.color),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Progresso Geral da Bíblia",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 20),
                  CircularPercentIndicator(
                    radius: 90.0,
                    lineWidth: 12.0,
                    animation: true,
                    percent: overallProgress,
                    center: Text(
                      "${(overallProgress * 100).toStringAsFixed(1)}%",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.0,
                          color: theme.textTheme.titleLarge?.color),
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        "Você leu $totalReadSectionsBible de $totalSectionsInBible seções!",
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    circularStrokeCap: CircularStrokeCap.round,
                    progressColor: theme.colorScheme.primary,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  _buildTestamentProgress("Antigo Testamento", atProgress,
                      totalReadSectionsAT, totalSectionsInAT, theme),
                  const SizedBox(height: 12),
                  _buildTestamentProgress("Novo Testamento", ntProgress,
                      totalReadSectionsNT, totalSectionsInNT, theme),
                  const SizedBox(height: 24),
                  Divider(color: theme.dividerColor),
                  const SizedBox(height: 16),
                  Text("Progresso por Livro",
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (bookProgressWidgets.isEmpty &&
                      vm.userId != null &&
                      !vm.isLoadingUserProgress)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Seu progresso por livro aparecerá aqui.",
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...bookProgressWidgets,
                ],
              ),
            );
          },
        );

      case 'Destaques':
        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SegmentedButton<HighlightType>(
                segments: const <ButtonSegment<HighlightType>>[
                  ButtonSegment<HighlightType>(
                      value: HighlightType.verses,
                      label: Text('Versículos'),
                      icon: Icon(Icons.menu_book)),
                  ButtonSegment<HighlightType>(
                      value: HighlightType.comments,
                      label: Text('Comentários'),
                      icon: Icon(Icons.comment_bank_outlined)),
                ],
                selected: <HighlightType>{_selectedHighlightType},
                onSelectionChanged: (Set<HighlightType> newSelection) {
                  if (mounted) {
                    setState(() => _selectedHighlightType = newSelection.first);
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.onSurface,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: StoreConnector<AppState, _HighlightsViewModel>(
                converter: (store) => _HighlightsViewModel.fromStore(store),
                builder: (context, highlightsVm) {
                  if (_selectedHighlightType == HighlightType.verses) {
                    final highlights = highlightsVm.userVerseHighlights;
                    if (highlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum versículo destacado ainda.",
                              style: TextStyle(fontSize: 16)));
                    }
                    final highlightList = highlights.entries.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: highlightList.length,
                      itemBuilder: (context, index) {
                        final entry = highlightList[index];
                        final verseId = entry.key;
                        final colorHex = entry.value;
                        final colorForIndicator = Color(
                            int.parse(colorHex.replaceFirst('#', '0xff')));
                        final parts = verseId.split('_');
                        String referenceText = verseId;
                        if (parts.length == 3 &&
                            _localBooksMap != null &&
                            _localBooksMap!.containsKey(parts[0])) {
                          final bookData = _localBooksMap![parts[0]];
                          referenceText =
                              "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        } else if (parts.length == 3) {
                          referenceText =
                              "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            leading: Container(
                                width: 10,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                    color: colorForIndicator,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10)))),
                            title: Text(referenceText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: FutureBuilder<String>(
                              future: BiblePageHelper.loadSingleVerseText(
                                  verseId, 'nvi'),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text("Carregando texto...",
                                      style: TextStyle(
                                          color:
                                              theme.textTheme.bodySmall?.color,
                                          fontSize: 12));
                                }
                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Text("Texto indisponível",
                                      style: TextStyle(
                                          color: theme.colorScheme.error
                                              .withOpacity(0.7),
                                          fontSize: 12));
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(snapshot.data!,
                                      style: TextStyle(
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                          fontSize: 13.5,
                                          height: 1.4),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis),
                                );
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color:
                                      theme.colorScheme.error.withOpacity(0.7),
                                  size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Remover Destaque",
                              onPressed: () {
                                if (mounted) {
                                  StoreProvider.of<AppState>(context,
                                          listen: false)
                                      .dispatch(ToggleHighlightAction(verseId));
                                }
                              },
                            ),
                            onTap: () => _navigateToBibleVerseAndTab(verseId),
                          ),
                        );
                      },
                    );
                  } else {
                    // Comments
                    final commentHighlights =
                        highlightsVm.userCommentHighlights;
                    if (commentHighlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum comentário marcado ainda.",
                              style: TextStyle(fontSize: 16)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: commentHighlights.length,
                      itemBuilder: (context, index) =>
                          _buildCommentHighlightCard(
                              commentHighlights[index], context, theme),
                    );
                  }
                },
              ),
            ),
          ],
        );

      case 'Notas':
        return StoreConnector<AppState, Map<String, String>>(
          converter: (store) => store.state.userState.userNotes,
          onInit: (store) {
            if (store.state.userState.userNotes.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadUserNotesAction());
            }
          },
          builder: (context, notes) {
            if (notes.isEmpty) {
              return Center(
                  child: Text("Nenhuma nota adicionada ainda.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                          fontSize: 16)));
            }
            final noteList = notes.entries.toList();
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: noteList.length,
              itemBuilder: (context, index) {
                final entry = noteList[index];
                final verseId = entry.key;
                final noteText = entry.value;
                final parts = verseId.split('_');
                String referenceText = verseId;
                if (parts.length == 3 &&
                    _localBooksMap != null &&
                    _localBooksMap!.containsKey(parts[0])) {
                  final bookData = _localBooksMap![parts[0]];
                  referenceText =
                      "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                } else if (parts.length == 3) {
                  referenceText =
                      "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                }
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: Icon(Icons.note_alt_outlined,
                        color: theme.colorScheme.secondary, size: 28),
                    title: Text(referenceText,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(noteText,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error.withOpacity(0.7),
                          size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Nota",
                      onPressed: () {
                        if (mounted) {
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(DeleteNoteAction(verseId));
                        }
                      },
                    ),
                    onTap: () => _navigateToBibleVerseAndTab(verseId),
                  ),
                );
              },
            );
          },
        );

      case 'Histórico':
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.readingHistory,
          onInit: (store) {
            if (store.state.userState.readingHistory.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadReadingHistoryAction());
            }
          },
          builder: (context, history) {
            if (history.isEmpty) {
              return Center(
                  child: Text("Nenhum histórico de leitura encontrado.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                          fontSize: 16)));
            }
            final DateFormat formatter = DateFormat('dd/MM/yy \'às\' HH:mm');
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final bookAbbrev = entry['bookAbbrev'] ?? '?';
                final chapter = entry['chapter'] ?? '?';
                final bookName = _localBooksMap?[bookAbbrev]?['nome'] ??
                    bookAbbrev.toUpperCase();
                final timestamp = entry['timestamp'] as DateTime?;
                final verseIdForNav = "${bookAbbrev}_${chapter}_1";
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: Icon(Icons.history_edu_outlined,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                        size: 28),
                    title: Text("$bookName $chapter",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                          timestamp != null
                              ? formatter.format(timestamp.toLocal())
                              : "Data indisponível",
                          style: TextStyle(
                              color: theme.textTheme.bodySmall?.color,
                              fontSize: 13)),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 18,
                        color: theme.iconTheme.color?.withOpacity(0.7)),
                    onTap: () => _navigateToBibleVerseAndTab(verseIdForNav),
                  ),
                );
              },
            );
          },
        );

      case 'Diário':
        return const UserDiaryPage();

      default:
        return Center(
            child: Text('Aba não implementada: $_selectedTab',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StoreConnector<AppState, _UserPageViewModel>(
      converter: (store) => _UserPageViewModel.fromStore(store),
      onInit: (store) {
        // Ações globais que não dependem da aba selecionada podem ir aqui,
        // mas com cuidado para não causar loops se já estiverem sendo carregadas.
        // A lógica de onInit de CADA StoreConnector de ABA é mais específica.
        if (store.state.metadataState.bibleSectionCounts.isEmpty &&
            !store.state.metadataState.isLoadingSectionCounts) {
          // print("UserPage onInit (main): Disparando LoadBibleSectionCountsAction");
          // store.dispatch(LoadBibleSectionCountsAction()); // Pode ser redundante se a aba progresso carregar
        }
      },
      builder: (context, vm) {
        bool shouldShowPageLoader = _isLoadingBooksMap &&
            (_selectedTab == 'Destaques' ||
                _selectedTab == 'Notas' ||
                _selectedTab == 'Histórico' ||
                _selectedTab == 'Progresso');

        if (shouldShowPageLoader && _selectedTab != 'Diário') {
          return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      key: const ValueKey("user_page_book_map_loader"))));
        }

        // Indicador de loading para a aba "Progresso" se os dados estiverem carregando
        if (vm.isLoadingAllBibleProgress && _selectedTab == 'Progresso') {
          return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      key:
                          const ValueKey("userpage_general_progress_loader"))));
        }
        // Mostrar erro geral do progresso se houver e a aba "Progresso" estiver selecionada
        if (vm.bibleProgressError != null && _selectedTab == 'Progresso') {
          return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                  child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                    "Erro ao carregar progresso: ${vm.bibleProgressError}",
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
              )));
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: RefreshIndicator(
            color: theme.colorScheme.primary,
            backgroundColor: theme.scaffoldBackgroundColor,
            onRefresh: () async {
              if (!mounted) return;
              final storeInstance =
                  StoreProvider.of<AppState>(context, listen: false);
              if (vm.userId != null) {
                storeInstance.dispatch(LoadUserStatsAction());
                storeInstance.dispatch(LoadUserDiariesAction());
                storeInstance.dispatch(LoadUserHighlightsAction());
                storeInstance.dispatch(LoadUserCommentHighlightsAction());
                storeInstance.dispatch(LoadUserNotesAction());
                storeInstance.dispatch(LoadReadingHistoryAction());
                storeInstance.dispatch(LoadAllBibleProgressAction());
                storeInstance.dispatch(LoadBibleSectionCountsAction());
              }
            },
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(
                              child: Column(
                                children: [
                                  ProfilePicture(),
                                  SizedBox(height: 12),
                                  UserInfo(),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.settings_outlined,
                                  color: theme.colorScheme.primary, size: 28),
                              tooltip: 'Configurações',
                              onPressed: () {
                                if (context.mounted) {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/userSettings');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Tabs(
                          tabs: _availableTabs,
                          onTabSelected: _onTabSelected,
                          selectedTab: _selectedTab,
                        ),
                        Divider(
                            color: theme.dividerColor.withOpacity(0.5),
                            height: 1,
                            thickness: 0.5),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTabContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserPageViewModel {
  final String? userId;
  final Map<String, dynamic> userDetails;
  final int userDiariesCount;
  final bool isLoadingAllBibleProgress;
  final String? bibleProgressError;

  _UserPageViewModel({
    required this.userId,
    required this.userDetails,
    required this.userDiariesCount,
    required this.isLoadingAllBibleProgress,
    this.bibleProgressError,
  });

  static _UserPageViewModel fromStore(Store<AppState> store) {
    return _UserPageViewModel(
      userId: store.state.userState.userId,
      userDetails: store.state.userState.userDetails ?? {},
      userDiariesCount: store.state.userState.userDiaries.length,
      isLoadingAllBibleProgress:
          store.state.userState.isLoadingAllBibleProgress,
      bibleProgressError: store.state.userState.bibleProgressError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserPageViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          mapEquals(userDetails, other.userDetails) &&
          userDiariesCount == other.userDiariesCount &&
          isLoadingAllBibleProgress == other.isLoadingAllBibleProgress &&
          bibleProgressError == other.bibleProgressError;

  @override
  int get hashCode =>
      userId.hashCode ^
      userDetails.hashCode ^
      userDiariesCount.hashCode ^
      isLoadingAllBibleProgress.hashCode ^
      bibleProgressError.hashCode;
}

class _HighlightsViewModel {
  final Map<String, String> userVerseHighlights;
  final List<Map<String, dynamic>> userCommentHighlights;

  _HighlightsViewModel({
    required this.userVerseHighlights,
    required this.userCommentHighlights,
  });

  static _HighlightsViewModel fromStore(Store<AppState> store) {
    return _HighlightsViewModel(
      userVerseHighlights: store.state.userState.userHighlights,
      userCommentHighlights: store.state.userState.userCommentHighlights,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HighlightsViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userVerseHighlights, other.userVerseHighlights) &&
          listEquals(userCommentHighlights, other.userCommentHighlights);

  @override
  int get hashCode =>
      userVerseHighlights.hashCode ^ userCommentHighlights.hashCode;
}

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserProgressViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          isLoadingCounts == other.isLoadingCounts &&
          isLoadingUserProgress == other.isLoadingUserProgress &&
          mapEquals(allBooksProgress, other.allBooksProgress) &&
          mapEquals(bibleSectionCounts, other.bibleSectionCounts) &&
          countsError == other.countsError &&
          userProgressError == other.userProgressError;

  @override
  int get hashCode =>
      userId.hashCode ^
      isLoadingCounts.hashCode ^
      isLoadingUserProgress.hashCode ^
      allBooksProgress.hashCode ^
      bibleSectionCounts.hashCode ^
      countsError.hashCode ^
      userProgressError.hashCode;
}
