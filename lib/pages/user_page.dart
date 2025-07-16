// lib/pages/user_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals and mapEquals
import 'package:flutter_animate/flutter_animate.dart';
import 'package:septima_biblia/main.dart';
import 'package:septima_biblia/models/highlight_item_model.dart';
import 'package:septima_biblia/pages/biblie_page/note_editor_modal.dart';
import 'package:septima_biblia/pages/user_page/denomination_card.dart';
import 'package:septima_biblia/pages/user_page/highlight_item_card.dart';
import 'package:septima_biblia/pages/user_page/profile_action_button.dart';
import 'package:septima_biblia/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart'; // Para Store
import 'package:intl/intl.dart';
import 'package:septima_biblia/redux/actions/metadata_actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Para BibleBookProgressData
import 'package:percent_indicator/percent_indicator.dart';
import 'package:septima_biblia/consts/bible_constants.dart'; // Para CANONICAL_BOOK_ORDER
import 'package:cloud_firestore/cloud_firestore.dart';

enum HighlightType { verse, literature }

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  Map<String, dynamic>? _localBooksMap;
  bool _isLoadingBooksMap = true;
  String _selectedTab = 'Progresso';
  bool _showAllBookProgress =
      false; // NOVO: Para controlar a expansão da lista de progresso por livro

  bool _initialProgressLoadDispatched =
      false; // Flag para controlar o despacho da ação
  final TextEditingController _tagSearchController = TextEditingController();
  String _tagSearchQuery = '';
  Timer? _debounce;

  HighlightType? _selectedHighlightType = null;

  final List<String> _availableTabs = const [
    'Progresso',
    'Destaques',
    'Notas',
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalBooksMap();

    _tagSearchController.addListener(() {
      // Se já houver um timer rodando, cancele-o.
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      // Inicie um novo timer.
      _debounce = Timer(const Duration(milliseconds: 400), () {
        // Esta parte do código só será executada 400ms depois que o usuário parar de digitar.
        if (mounted && _tagSearchController.text != _tagSearchQuery) {
          setState(() {
            _tagSearchQuery = _tagSearchController.text;
          });
        }
      });
    });

    @override
    void dispose() {
      // >>> INÍCIO DA MODIFICAÇÃO 3/3: Cancelar o debounce no dispose <<<
      _debounce?.cancel();
      // >>> FIM DA MODIFICAÇÃO 3/3 <<<
      _tagSearchController.dispose();
      super.dispose();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);

      if (storeInstance.state.metadataState.bibleSectionCounts.isEmpty &&
          !storeInstance.state.metadataState.isLoadingSectionCounts) {
        storeInstance.dispatch(LoadBibleSectionCountsAction());
      }

      // >>> INÍCIO DA CORREÇÃO <<<
      // Movemos a lógica de carregamento inicial para o initState
      _dispatchInitialLoadActions(storeInstance);
      // >>> FIM DA CORREÇÃO <<<
    });
  }

  // >>> INÍCIO DA CORREÇÃO <<<
  // Nova função para centralizar o carregamento inicial
  void _dispatchInitialLoadActions(Store<AppState> storeInstance) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    if (storeInstance.state.userState.userId != null) {
      // Carrega o progresso se ainda não foi solicitado
      if (!_initialProgressLoadDispatched &&
          storeInstance.state.userState.allBooksProgress.isEmpty &&
          !storeInstance.state.userState.isLoadingAllBibleProgress) {
        print(
            "UserPage: Disparando carregamento inicial do progresso bíblico.");
        storeInstance.dispatch(LoadAllBibleProgressAction());
        setState(() {
          _initialProgressLoadDispatched =
              true; // Marca que a ação já foi despachada
        });
      }

      // Carrega outros dados do usuário
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

      // <<< ADICIONE ESTA LINHA AQUI >>>
      // Garante que as tags sejam carregadas quando a UserPage é inicializada.
      storeInstance.dispatch(LoadUserTagsAction());
    }
  }
  // >>> FIM DA CORREÇÃO <<<

  Future<void> _loadLocalBooksMap() async {
    // ... (sem alterações) ...
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
      // A lógica de carregamento foi movida para o initState e para o RefreshIndicator.
      // Não precisamos mais despachar ações aqui, pois isso estava causando o loop.
      // A UI vai simplesmente mudar de aba, e o StoreConnector de cada aba cuidará de mostrar
      // os dados que já estão no estado ou um indicador de loading se o carregamento inicial ainda estiver ocorrendo.
    }
  }

  void _navigateToBibleVerseAndTab(String verseId) {
    print("Navegando para o versículo: $verseId");
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      if (chapter != null && context.mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        // Assumindo que o índice da aba Bíblia é 1, não 2
        store.dispatch(RequestBottomNavChangeAction(1));
      }
    }
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required HighlightType? value,
    required HighlightType? groupValue,
    required Function(bool) onSelected,
  }) {
    final theme = Theme.of(context);
    final bool isSelected = value == groupValue;

    return ChoiceChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 16, // <<< MUDANÇA: Ícone um pouco menor
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.primary,
      ),
      selected: isSelected,
      onSelected: onSelected,
      labelStyle: TextStyle(
        fontSize: 12.5, // <<< MUDANÇA: Fonte um pouco menor
        fontWeight: FontWeight.w600,
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.textTheme.bodyLarge?.color,
      ),
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      selectedColor: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
        ),
      ),
      // <<< MUDANÇA PRINCIPAL: Padding reduzido para um botão mais compacto >>>
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize
          .shrinkWrap, // Remove o padding extra da área de toque
      showCheckmark: false,
    );
  }

  Widget _buildTestamentProgress(String title, double progress,
      int readSections, int totalSections, ThemeData theme) {
    // ... (sem alterações, apenas ajuste de estilo se desejar) ...
    if (totalSections == 0 && readSections == 0) {
      // Ainda não começou ou não há dados
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 8),
            LinearPercentIndicator(
              percent: 0.0,
              lineHeight: 10.0,
              barRadius: const Radius.circular(5),
              backgroundColor:
                  theme.colorScheme.surfaceVariant.withOpacity(0.3),
              progressColor:
                  theme.colorScheme.onSurface.withOpacity(0.1), // Cor neutra
              center: Text("0%",
                  style: TextStyle(
                      fontSize: 10,
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.5))),
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
          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
    // ... (sem alterações) ...
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
          distinct: true,
          // A lógica de onInit foi movida para o initState da página para evitar chamadas repetidas
          builder: (context, vm) {
            final theme = Theme.of(context);

            // --- LÓGICA DE RENDERIZAÇÃO CONDICIONAL ---

            // 1. Estado de Loading: Mostra um indicador enquanto os metadados da Bíblia (essenciais para o cálculo)
            // ou o progresso inicial do usuário estão sendo carregados.
            final bool isStillLoading = vm.isLoadingCounts ||
                vm.isLoadingUserProgress ||
                (vm.bibleSectionCounts.isEmpty && vm.userId != null);

            if (isStillLoading) {
              return Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      key: const ValueKey("progress_tab_loader_userpage")));
            }

            // 2. Estado de Erro: Se houve falha ao carregar os dados.
            if (vm.countsError != null || vm.userProgressError != null) {
              return Center(
                  child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    const Text(
                      "Erro ao Carregar Progresso",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Não foi possível carregar seus dados de leitura. Verifique sua conexão e tente novamente.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ));
            }

            // 3. Estado Vazio: Para um usuário novo que ainda não leu nada.
            if (vm.allBooksProgress.isEmpty && vm.userId != null) {
              // Envolve o conteúdo com SingleChildScrollView para evitar overflow em telas menores.
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  // Usamos um padding vertical maior para centralizar melhor visualmente,
                  // já que o SingleChildScrollView pode não preencher a tela toda.
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 64.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 60,
                          color: theme.colorScheme.primary.withOpacity(0.8)),
                      const SizedBox(height: 16),
                      Text(
                        "Seu Progresso de Leitura aparecerá aqui!",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Vá para a aba 'Bíblia' e comece a marcar seções como lidas para ver suas estatísticas.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }
            // 4. Estado com Dados: Renderiza a UI de progresso normal.
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('userBibleProgress')
                  .doc(vm.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: theme.colorScheme.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text("Erro ao carregar progresso geral.",
                          style: TextStyle(color: theme.colorScheme.error)));
                }

                final progressData =
                    snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final overallProgress =
                    (progressData['currentProgressPercent'] as num?)
                            ?.toDouble() ??
                        0.0;
                final completionCount =
                    progressData['bibleCompletionCount'] as int? ?? 0;

                // --- CÁLCULOS DETALHADOS (usando dados do Redux/VM) ---
                int totalSectionsInBible =
                    (vm.bibleSectionCounts['total_secoes_biblia'] as int? ?? 1)
                        .clamp(1, 1000000);
                int totalSectionsInAT =
                    (vm.bibleSectionCounts['total_secoes_antigo_testamento']
                                as int? ??
                            1)
                        .clamp(1, 1000000);
                int totalSectionsInNT =
                    (vm.bibleSectionCounts['total_secoes_novo_testamento']
                                as int? ??
                            1)
                        .clamp(1, 1000000);

                int totalReadSectionsBible = vm.allBooksProgress.values
                    .fold<int>(
                        0, (sum, book) => sum + book.readSections.length);
                int totalReadSectionsAT = 0;
                int totalReadSectionsNT = 0;
                final booksMetadataFromCounts =
                    vm.bibleSectionCounts['livros'] as Map<String, dynamic>? ??
                        {};

                vm.allBooksProgress.forEach((bookAbbrev, progressData) {
                  final String? testament = booksMetadataFromCounts[bookAbbrev]
                      ?['testamento'] as String?;
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

                List<Widget> bookProgressWidgets = [];
                if (_localBooksMap != null &&
                    vm.bibleSectionCounts.isNotEmpty) {
                  int index = 0;
                  for (String bookAbbrev in CANONICAL_BOOK_ORDER) {
                    final bookMetaForName =
                        _localBooksMap![bookAbbrev] as Map<String, dynamic>?;
                    final bookMetaFromCounts =
                        booksMetadataFromCounts[bookAbbrev]
                            as Map<String, dynamic>?;
                    if (bookMetaForName == null || bookMetaFromCounts == null)
                      continue;

                    final bookProgressData = vm.allBooksProgress[bookAbbrev];
                    int totalSectionsInThisBook =
                        (bookMetaFromCounts['total_secoes_livro'] as int? ?? 1)
                            .clamp(1, 1000000);
                    int readSectionsInThisBook =
                        bookProgressData?.readSections.length ?? 0;
                    double bookProgressPercent = (totalSectionsInThisBook > 0)
                        ? (readSectionsInThisBook / totalSectionsInThisBook)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    String bookFullName =
                        bookMetaForName['nome'] ?? bookAbbrev.toUpperCase();

                    bookProgressWidgets.add(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(bookFullName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.9)))),
                              Text(
                                  "${(bookProgressPercent * 100).toStringAsFixed(0)}% ($readSectionsInThisBook/$totalSectionsInThisBook)",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.7))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearPercentIndicator(
                            percent: bookProgressPercent,
                            lineHeight: 10.0,
                            barRadius: const Radius.circular(5),
                            backgroundColor: theme.colorScheme.surfaceVariant
                                .withOpacity(0.4),
                            progressColor: theme.colorScheme.primary,
                            animation: !kIsIntegrationTest,
                            animationDuration: 600,
                          ),
                        ],
                      ),
                    )
                        .animate(delay: (50 * (index % 10)).ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.2, curve: Curves.easeOut));
                    index++;
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        color: theme.cardColor.withOpacity(0.8),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text("Progresso Geral da Bíblia",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              if (completionCount > 0) ...[
                                Chip(
                                  avatar: Icon(Icons.workspace_premium_rounded,
                                      color: Colors.amber.shade800, size: 20),
                                  label: Text(
                                      '$completionCount ${completionCount > 1 ? "Leituras Completas" : "Leitura Completa"}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  backgroundColor:
                                      Colors.amber.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                              ],
                              CircularPercentIndicator(
                                radius: 80.0,
                                lineWidth: 12.0,
                                percent: overallProgress / 100,
                                center: Text(
                                    "${overallProgress.toStringAsFixed(1)}%",
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary)),
                                footer: Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                      "Você leu $totalReadSectionsBible de $totalSectionsInBible seções!",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.8)),
                                      textAlign: TextAlign.center),
                                ),
                                circularStrokeCap: CircularStrokeCap.round,
                                progressColor: theme.colorScheme.primary,
                                backgroundColor: theme
                                    .colorScheme.surfaceVariant
                                    .withOpacity(0.5),
                                animation: !kIsIntegrationTest,
                                animationDuration: 1000,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTestamentProgressCard(
                                  "Antigo Testamento",
                                  atProgress,
                                  totalReadSectionsAT,
                                  totalSectionsInAT,
                                  theme,
                                  Colors.orange.shade700)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildTestamentProgressCard(
                                  "Novo Testamento",
                                  ntProgress,
                                  totalReadSectionsNT,
                                  totalSectionsInNT,
                                  theme,
                                  Colors.teal.shade600)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: const PageStorageKey<String>(
                              'book_progress_expansion_tile_userpage'),
                          tilePadding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 4.0),
                          backgroundColor: theme.cardColor.withOpacity(0.5),
                          collapsedBackgroundColor:
                              theme.cardColor.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          title: Text("Progresso Detalhado por Livro",
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface)),
                          subtitle: Text(
                              "Toque para ver o progresso em cada livro",
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6))),
                          trailing: Icon(
                              _showAllBookProgress
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: theme.colorScheme.primary,
                              size: 28),
                          onExpansionChanged: (bool expanded) {
                            if (mounted) {
                              setState(() => _showAllBookProgress = expanded);
                            }
                          },
                          initiallyExpanded: _showAllBookProgress,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 0,
                                  left: 16.0,
                                  right: 16.0,
                                  bottom: 16.0),
                              child: Column(children: bookProgressWidgets),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        );
      case 'Destaques':
        return Column(
          children: [
            // Botões de filtro atualizados
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 2.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Botão "Todos"
                  Expanded(
                    child: _buildFilterChip(
                      context: context,
                      label: "Todos",
                      icon: Icons.list_alt_rounded,
                      value: null,
                      groupValue: _selectedHighlightType,
                      onSelected: (value) {
                        setState(() => _selectedHighlightType = null);
                      },
                    ),
                  ),

                  // Botão "Bíblia"
                  Expanded(
                    child: _buildFilterChip(
                      context: context,
                      label: "Bíblia",
                      icon: Icons.menu_book,
                      value: HighlightType.verse,
                      groupValue: _selectedHighlightType,
                      onSelected: (value) {
                        setState(
                            () => _selectedHighlightType = HighlightType.verse);
                      },
                    ),
                  ),

                  // Botão "Biblioteca" (um nome mais intuitivo que "Literatura")
                  Expanded(
                    child: _buildFilterChip(
                      context: context,
                      label: "Biblioteca",
                      icon: Icons.import_contacts_outlined,
                      value: HighlightType.literature,
                      groupValue: _selectedHighlightType,
                      onSelected: (value) {
                        setState(() =>
                            _selectedHighlightType = HighlightType.literature);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Barra de pesquisa (permanece a mesma)
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
              child: TextField(
                controller: _tagSearchController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  hintText: 'Pesquisar destaques por tag...',
                  prefixIcon: Icon(Icons.label_outline, color: theme.hintColor),
                  suffixIcon: _tagSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _tagSearchController.clear();
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide(color: theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide(
                        color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
            ),

            // Lista de destaques com a LÓGICA DE FILTRAGEM CORRIGIDA
            Expanded(
              child: StoreConnector<AppState, _HighlightsViewModel>(
                converter: (store) =>
                    _HighlightsViewModel.fromStore(store, _localBooksMap),
                builder: (context, vm) {
                  // Inicia com a lista completa
                  List<HighlightItem> filteredList = vm.allHighlights;

                  // 1. Filtra por tipo (versículo/literatura) PRIMEIRO
                  if (_selectedHighlightType == HighlightType.verse) {
                    filteredList = vm.allHighlights
                        .where((item) => item.type == HighlightItemType.verse)
                        .toList();
                  } else if (_selectedHighlightType ==
                      HighlightType.literature) {
                    filteredList = vm.allHighlights
                        .where(
                            (item) => item.type == HighlightItemType.literature)
                        .toList();
                  } else {
                    // Se _selectedHighlightType for null (Todos), começa com a lista completa
                    filteredList = vm.allHighlights;
                  }

                  // 2. Filtra por TAG na lista JÁ filtrada por tipo
                  if (_tagSearchQuery.isNotEmpty) {
                    final query = _tagSearchQuery.toLowerCase();
                    filteredList = filteredList.where((item) {
                      return item.tags
                          .any((tag) => tag.toLowerCase().contains(query));
                    }).toList();
                  }

                  // Mensagem de "Nenhum item"
                  if (filteredList.isEmpty) {
                    return Center(
                        child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        _tagSearchQuery.isEmpty
                            ? "Nenhum destaque encontrado."
                            : "Nenhum destaque com a tag '$_tagSearchQuery' encontrado.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7)),
                      ),
                    ));
                  }

                  // Constrói a lista com os itens filtrados
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      // <<< ADICIONE A ANIMAÇÃO AQUI >>>
                      return HighlightItemCard(
                        item: item,
                        onNavigateToVerse: _navigateToBibleVerseAndTab,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (100 * index).ms)
                          .moveX(begin: -20, curve: Curves.easeOutCubic);
                    },
                  );
                },
              ),
            ),
          ],
        );
      case 'Notas':
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.userNotes,
          onInit: (store) {
            if (store.state.userState.userNotes.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadUserNotesAction());
            }
          },
          builder: (context, notes) {
            if (notes.isEmpty) {
              // Um "empty state" mais informativo e visualmente agradável.
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_note_outlined,
                          size: 60,
                          color: theme.iconTheme.color?.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        "Suas anotações aparecerão aqui",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Para adicionar uma nota, pressione e segure um versículo na tela da Bíblia e escolha a opção.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Ordena as notas pela data, da mais recente para a mais antiga.
            notes.sort((a, b) {
              final Timestamp? tsA = a['timestamp'];
              final Timestamp? tsB = b['timestamp'];
              if (tsA == null && tsB == null) return 0;
              if (tsA == null) return 1;
              if (tsB == null) return -1;
              return tsB.compareTo(tsA);
            });

            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final noteData = notes[index];
                final verseId = noteData['verseId'] as String;
                final noteText = noteData['noteText'] as String;
                final verseContent = noteData['verseContent'] as String? ??
                    'Carregando versículo...';

                final parts = verseId.split('_');
                String referenceText = verseId;
                if (_localBooksMap != null &&
                    parts.length == 3 &&
                    _localBooksMap!.containsKey(parts[0])) {
                  final bookData = _localBooksMap![parts[0]];
                  final bookName = bookData?['nome'] ?? parts[0].toUpperCase();
                  referenceText = "$bookName ${parts[1]}:${parts[2]}";
                }

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- CABEÇALHO DO CARD ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                referenceText,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            // --- BOTÃO DE AÇÕES (EDITAR/EXCLUIR) ---
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showDialog(
                                    context: context,
                                    builder: (_) => NoteEditorModal(
                                      verseId: verseId,
                                      initialText: noteText,
                                      bookReference: referenceText,
                                      verseTextSample: verseContent,
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text("Confirmar Remoção"),
                                      content: Text(
                                          "Tem certeza que deseja remover esta nota para $referenceText?"),
                                      actions: [
                                        TextButton(
                                          child: const Text("Cancelar"),
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                        ),
                                        TextButton(
                                          child: Text("Remover",
                                              style: TextStyle(
                                                  color:
                                                      theme.colorScheme.error)),
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop();
                                            StoreProvider.of<AppState>(context,
                                                    listen: false)
                                                .dispatch(
                                                    DeleteNoteAction(verseId));
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline,
                                        color: theme.colorScheme.error),
                                    title: Text('Excluir',
                                        style: TextStyle(
                                            color: theme.colorScheme.error)),
                                  ),
                                ),
                              ],
                              icon: Icon(Icons.more_vert,
                                  color:
                                      theme.iconTheme.color?.withOpacity(0.6)),
                            ),
                          ],
                        ),
                        const Divider(height: 16),

                        // --- O TEXTO DA NOTA DO USUÁRIO ---
                        Text(
                          noteText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- BLOCO DE CITAÇÃO PARA O VERSÍCULO ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.5),
                                width: 4,
                              ),
                            ),
                          ),
                          child: Text(
                            verseContent,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.1, curve: Curves.easeOutCubic);
              },
            );
          },
        );
      default:
        return Center(
            child: Text('Aba não implementada: $_selectedTab',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color)));
    }
  }

  // NOVO WIDGET HELPER para Card de Testamento
  Widget _buildTestamentProgressCard(
      String title,
      double progress,
      int readSections,
      int totalSections,
      ThemeData theme,
      Color progressColor) {
    String sectionsText = "Nenhum progresso";
    if (totalSections > 0 || readSections > 0) {
      sectionsText =
          "$readSections / ${totalSections > 0 ? totalSections : readSections} seções";
    }

    // O Card é o widget raiz. O SizedBox problemático foi removido.
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.cardColor.withOpacity(0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        child: Column(
          // Distribui o espaço verticalmente para um visual equilibrado
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.95),
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            // Usamos um SizedBox com altura fixa pequena para garantir espaçamento
            const SizedBox(height: 8),
            LinearPercentIndicator(
              percent: progress,
              lineHeight: 14.0,
              barRadius: const Radius.circular(7),
              backgroundColor: progressColor.withOpacity(0.25),
              progressColor: progressColor,
              center: Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Cor de alto contraste
                ),
              ),
              animation: true,
            ),
            // Usamos um SizedBox com altura fixa pequena para garantir espaçamento
            const SizedBox(height: 8),
            Text(sectionsText,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                    fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StoreConnector<AppState, _UserPageViewModel>(
      converter: (store) => _UserPageViewModel.fromStore(store),
      onInit: (store) {
        if (store.state.metadataState.bibleSectionCounts.isEmpty &&
            !store.state.metadataState.isLoadingSectionCounts) {
          store.dispatch(LoadBibleSectionCountsAction());
        }
      },
      builder: (context, vm) {
        // A lógica de loading permanece aqui para mostrar o spinner na tela toda.
        bool shouldShowPageLoader = _isLoadingBooksMap &&
            (_selectedTab == 'Destaques' ||
                _selectedTab == 'Notas' ||
                _selectedTab == 'Progresso');

        if (shouldShowPageLoader ||
            (vm.isLoadingAllBibleProgress && _selectedTab == 'Progresso')) {
          return Center(
              child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ));
        }

        if (vm.bibleProgressError != null && _selectedTab == 'Progresso') {
          return Center(
              child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Erro ao carregar progresso: ${vm.bibleProgressError}",
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center),
          ));
        }

        // ✅ REFINAMENTO PRINCIPAL:
        // O `Scaffold` e a `AppBar` foram removidos. O widget agora retorna
        // diretamente o conteúdo que deve aparecer DENTRO da aba.
        return RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: theme.scaffoldBackgroundColor,
          onRefresh: () {
            // ... (sua lógica de onRefresh permanece a mesma)
            final completer = Completer<void>();
            final storeInstance =
                StoreProvider.of<AppState>(context, listen: false);

            if (vm.userId != null) {
              storeInstance.dispatch(LoadUserStatsAction());
              storeInstance.dispatch(LoadUserHighlightsAction());
              storeInstance.dispatch(LoadUserCommentHighlightsAction());
              storeInstance.dispatch(LoadUserNotesAction());
              storeInstance.dispatch(LoadBibleSectionCountsAction());
              storeInstance
                  .dispatch(LoadAllBibleProgressAction(completer: completer));
            } else {
              completer.complete();
            }
            return completer.future;
          },
          // O SafeArea não é mais necessário aqui, pois a MainAppScreen já tem um.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A UI agora começa diretamente com os TABS de controle.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16.0, 16.0, 16.0, 0), // Padding no topo para dar espaço
                child: Column(
                  children: [
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
        );
      },
    );
  }
}

// ViewModels _UserPageViewModel, _HighlightsViewModel, _UserProgressViewModel permanecem os mesmos.
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
  // A ViewModel agora expõe uma única lista de itens unificados
  final List<HighlightItem> allHighlights;
  final bool isLoading;

  _HighlightsViewModel({required this.allHighlights, required this.isLoading});

  static _HighlightsViewModel fromStore(
      Store<AppState> store, Map<String, dynamic>? booksMap) {
    List<HighlightItem> combinedList = [];

    // 1. Processa os destaques de versículos bíblicos
    store.state.userState.userHighlights.forEach((verseId, highlightData) {
      final parts = verseId.split('_');
      String referenceText = verseId; // Fallback

      // Tenta traduzir a abreviação do livro para o nome completo
      if (parts.length == 3 &&
          booksMap != null &&
          booksMap.containsKey(parts[0])) {
        final bookData = booksMap[parts[0]];
        final bookName = bookData?['nome'] ?? parts[0].toUpperCase();
        referenceText = "$bookName ${parts[1]}:${parts[2]}";
      } else if (parts.length == 3) {
        referenceText = "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
      }

      combinedList.add(
        HighlightItem(
          id: verseId,
          type: HighlightItemType.verse,
          referenceText: referenceText, // Usa o nome completo do livro
          contentPreview:
              "Carregando texto do versículo...", // Será carregado depois
          tags: List<String>.from(highlightData['tags'] ?? []),
          colorHex: highlightData['color'] as String?,
          originalData: {'verseId': verseId, ...highlightData},
        ),
      );
    });

    // 2. Processa os destaques de literatura (comentários, sermões, etc.)
    store.state.userState.userCommentHighlights.forEach((commentData) {
      // Cria um texto de referência mais descritivo e amigável
      String referenceText;
      final String sourceType =
          commentData['sourceType'] as String? ?? 'literature';
      final String sourceTitle =
          commentData['sourceTitle'] as String? ?? 'Fonte desconhecida';

      switch (sourceType) {
        case 'sermon':
          // Limita o tamanho do título para não quebrar a UI
          referenceText =
              "Sermão: ${sourceTitle.length > 40 ? sourceTitle.substring(0, 40) + '...' : sourceTitle}";
          break;
        case 'church_history':
          referenceText = "Hist. da Igreja: $sourceTitle";
          break;
        case 'turretin':
          referenceText = "Institutas: $sourceTitle";
          break;
        case 'bible_commentary':
          // Usa a referência do versículo associado ao comentário
          referenceText =
              commentData['verseReferenceText'] ?? 'Comentário Bíblico';
          break;
        default:
          referenceText =
              commentData['verseReferenceText'] ?? 'Referência desconhecida';
      }

      combinedList.add(
        HighlightItem(
          id: commentData['id'] as String? ?? '',
          type: HighlightItemType.literature,
          referenceText: referenceText, // Usa o texto de referência formatado
          contentPreview:
              commentData['selectedSnippet'] ?? 'Trecho indisponível',
          tags: List<String>.from(commentData['tags'] ?? []),
          colorHex: commentData['color'] as String? ?? "#FFA07A",
          originalData: commentData,
        ),
      );
    });

    // 3. Ordena a lista combinada pela data do timestamp, do mais recente para o mais antigo
    combinedList.sort((a, b) {
      final timestampA = a.originalData['timestamp'] as Timestamp?;
      final timestampB = b.originalData['timestamp'] as Timestamp?;

      if (timestampA == null && timestampB == null) return 0;
      if (timestampA == null) return 1; // Coloca itens sem timestamp no final
      if (timestampB == null) return -1; // Coloca itens sem timestamp no final
      return timestampB
          .compareTo(timestampA); // Ordena do mais novo para o mais velho
    });

    return _HighlightsViewModel(
      allHighlights: combinedList,
      isLoading: false, // Assumimos que o carregamento já terminou
    );
  }
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
