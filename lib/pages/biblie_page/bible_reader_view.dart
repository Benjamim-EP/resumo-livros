// lib/pages/biblie_page/bible_reader_view.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/mind_map_fullscreen_page.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_item_widget.dart';
import 'package:septima_biblia/pages/components/mind_map_view.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/actions/library_reference_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/tts_manager.dart';

// ViewModel permanece o mesmo, pois já está otimizado.
class _BibleContentViewModel {
  final Map<String, Map<String, dynamic>> userHighlights;
  final List<Map<String, dynamic>> userNotes;
  final Set<String> readSectionsForCurrentBook;
  final List<String> allUserTags;

  _BibleContentViewModel({
    required this.userHighlights,
    required this.userNotes,
    required this.readSectionsForCurrentBook,
    required this.allUserTags,
  });

  static _BibleContentViewModel fromStore(
      Store<AppState> store, String? currentSelectedBook) {
    return _BibleContentViewModel(
      userHighlights: store.state.userState.userHighlights,
      userNotes: store.state.userState.userNotes,
      readSectionsForCurrentBook: currentSelectedBook != null
          ? store.state.userState.readSectionsByBook[currentSelectedBook] ??
              const {}
          : const {},
      allUserTags: store.state.userState.allUserTags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BibleContentViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userHighlights, other.userHighlights) &&
          listEquals(userNotes, other.userNotes) &&
          setEquals(
              readSectionsForCurrentBook, other.readSectionsForCurrentBook) &&
          listEquals(allUserTags, other.allUserTags);

  @override
  int get hashCode =>
      userHighlights.hashCode ^
      Object.hashAll(userNotes) ^
      readSectionsForCurrentBook.hashCode ^
      allUserTags.hashCode;
}

// O construtor e os parâmetros do StatefulWidget permanecem os mesmos.
class BibleReaderView extends StatefulWidget {
  final String selectedBook;
  final int selectedChapter;
  final String selectedTranslation1;
  final String? selectedTranslation2;
  final String? bookSlug;
  final bool isCompareMode;
  final bool isFocusMode;
  final bool showHebrewInterlinear;
  final bool showGreekInterlinear;
  final double fontSizeMultiplier;
  final Function(String, TtsContentType) onPlayRequest;
  final TtsPlayerState currentPlayerState;
  final String? currentlyPlayingSectionId;
  final TtsContentType? currentlyPlayingContentType;
  final ScrollController scrollController1;
  final ScrollController scrollController2;
  final Map<String, dynamic>? currentChapterHebrewData;
  final Map<String, dynamic>? currentChapterGreekData;
  final Future<void> Function(String, String) onShowSummaryRequest;
  final bool showMindMaps;
  final bool isStudyModeActive;

  const BibleReaderView({
    super.key,
    required this.selectedBook,
    required this.selectedChapter,
    required this.selectedTranslation1,
    this.selectedTranslation2,
    this.bookSlug,
    required this.isCompareMode,
    required this.isFocusMode,
    required this.showHebrewInterlinear,
    required this.showGreekInterlinear,
    required this.fontSizeMultiplier,
    required this.onPlayRequest,
    required this.currentPlayerState,
    this.currentlyPlayingSectionId,
    this.currentlyPlayingContentType,
    required this.scrollController1,
    required this.scrollController2,
    this.currentChapterHebrewData,
    this.currentChapterGreekData,
    required this.onShowSummaryRequest,
    required this.showMindMaps,
    required this.isStudyModeActive,
  });

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  late Future<Map<String, dynamic>> _chapterDataFuture;
  // ✅ ADICIONADO: Instância do FirestoreService para ser usada no widget.
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadChapterData();
  }

  @override
  void didUpdateWidget(BibleReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedBook != oldWidget.selectedBook ||
        widget.selectedChapter != oldWidget.selectedChapter ||
        widget.selectedTranslation1 != oldWidget.selectedTranslation1 ||
        widget.selectedTranslation2 != oldWidget.selectedTranslation2 ||
        widget.isCompareMode != oldWidget.isCompareMode) {
      _loadChapterData();
    }
  }

  void _loadChapterData() {
    setState(() {
      _chapterDataFuture = BiblePageHelper.loadChapterDataComparison(
        widget.selectedBook,
        widget.selectedChapter,
        widget.selectedTranslation1,
        widget.isCompareMode ? widget.selectedTranslation2 : null,
      );
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        // Despacha a ação para buscar as recomendações para este capítulo
        store.dispatch(FetchVerseRecommendationsAction(
            widget.selectedBook, widget.selectedChapter));
      }
      if (mounted) {
        StoreProvider.of<AppState>(context, listen: false).dispatch(
            LoadLibraryReferencesForChapterAction(
                bookAbbrev: widget.selectedBook,
                chapter: widget.selectedChapter));
      }
    });
  }

  // A função build() principal agora delega a construção da UI para os métodos auxiliares.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _chapterDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'ERRO AO CARREGAR CAPÍTULO ${widget.selectedBook} ${widget.selectedChapter}:\n${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          return Center(
              child: Text(
                  'Nenhum dado bíblico encontrado para ${widget.selectedBook} ${widget.selectedChapter}.'));
        }

        final chapterData = snapshot.data!;
        final sections = List<Map<String, dynamic>>.from(
            chapterData['sectionStructure'] ?? []);
        final verseDataMap =
            Map<String, dynamic>.from(chapterData['verseData'] ?? {});
        final primaryVerseData = verseDataMap[widget.selectedTranslation1];

        if (primaryVerseData == null ||
            (primaryVerseData is List && primaryVerseData.isEmpty)) {
          return Center(
              child: Text(
                  'Conteúdo não encontrado para a tradução ${widget.selectedTranslation1}.'));
        }

        if (!widget.isCompareMode) {
          return _buildSingleViewContent(theme, sections, primaryVerseData);
        } else {
          final comparisonVerseData = verseDataMap[widget.selectedTranslation2];
          if (comparisonVerseData == null ||
              (comparisonVerseData is List && comparisonVerseData.isEmpty)) {
            return Center(
                child: Text(
                    'Tradução "${widget.selectedTranslation2}" não encontrada.'));
          }
          return _buildCompareViewContent(
              theme, sections, primaryVerseData, comparisonVerseData);
        }
      },
    );
  }

  // ✅ NOVO MÉTODO: Lógica de construção da visão única, agora mais limpa.
  Widget _buildSingleViewContent(
    ThemeData theme,
    List<Map<String, dynamic>> sections,
    dynamic primaryTranslationVerseData,
  ) {
    return StoreConnector<AppState, _BibleContentViewModel>(
      converter: (store) =>
          _BibleContentViewModel.fromStore(store, widget.selectedBook),
      distinct: true,
      builder: (context, contentViewModel) {
        // 1. Constrói a lista de widgets de forma dinâmica
        List<Widget> contentWidgets = [];

        if (sections.isNotEmpty) {
          for (var sectionData in sections) {
            final sectionId = _getSectionIdFromData(sectionData);

            // Adiciona o Card da seção de versículos
            contentWidgets.add(
              SectionItemWidget(
                sectionTitle: sectionData['title'] ?? 'Seção Desconhecida',
                verseNumbersInSection:
                    (sectionData['verses'] as List?)?.cast<int>() ?? [],
                allVerseDataInChapter: primaryTranslationVerseData,
                bookSlug: widget.bookSlug!,
                bookAbbrev: widget.selectedBook,
                chapterNumber: widget.selectedChapter,
                versesRangeStr: _getVersesRangeFromData(sectionData),
                userHighlights: contentViewModel.userHighlights,
                userNotes: contentViewModel.userNotes,
                isRead: contentViewModel.readSectionsForCurrentBook
                    .contains(sectionId),
                showHebrewInterlinear: widget.showHebrewInterlinear,
                showGreekInterlinear: widget.showGreekInterlinear,
                hebrewInterlinearSectionData:
                    _getHebrewDataForSection(sectionData),
                greekInterlinearSectionData:
                    _getGreekDataForSection(sectionData),
                fontSizeMultiplier: widget.fontSizeMultiplier,
                onPlayRequest: widget.onPlayRequest,
                currentPlayerState: widget.currentPlayerState,
                currentlyPlayingSectionId: widget.currentlyPlayingSectionId,
                currentlyPlayingContentType: widget.currentlyPlayingContentType,
                allUserTags: contentViewModel.allUserTags,
                onShowSummaryRequest: widget.onShowSummaryRequest,
                isStudyModeActive: widget.isStudyModeActive,
              ),
            );

            // 2. Se a opção estiver ativa, ADICIONA o Card do Mapa Mental
            if (widget.showMindMaps) {
              contentWidgets.add(_buildMindMapCard(theme, sectionId));
            }
          }
        } else {
          // Fallback para renderizar versículo por versículo
          final verseList = (primaryTranslationVerseData as List?) ?? [];
          for (int i = 0; i < verseList.length; i++) {
            contentWidgets.add(
              BiblePageWidgets.buildVerseItem(
                key: ValueKey(
                    '${widget.selectedBook}-${widget.selectedChapter}-${i + 1}-single'),
                verseNumber: i + 1,
                verseData: verseList[i],
                selectedBook: widget.selectedBook,
                selectedChapter: widget.selectedChapter,
                context: context,
                userHighlights: contentViewModel.userHighlights,
                userNotes: contentViewModel.userNotes,
                allUserTags: contentViewModel.allUserTags,
                fontSizeMultiplier: widget.fontSizeMultiplier,
                isHebrew: widget.selectedTranslation1 == 'hebrew_original',
                isGreekInterlinear:
                    widget.selectedTranslation1 == 'greek_interlinear',
              ),
            );
          }
        }

        // 3. Adiciona o rodapé no final da lista
        contentWidgets.add(
            _buildChapterFooter(context, theme, contentViewModel, sections));

        // 4. Renderiza a lista de widgets construída
        return ListView.builder(
          controller: widget.scrollController1,
          key: PageStorageKey<String>(
              '${widget.selectedBook}-${widget.selectedChapter}-singleView-${widget.showMindMaps}'),
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
            top: widget.isFocusMode ? 8.0 : 0.0,
          ),
          itemCount: contentWidgets.length,
          itemBuilder: (context, index) {
            return contentWidgets[index];
          },
        );
      },
    );
  }

  // ✅ NOVO MÉTODO: Lógica de construção da visão de comparação.
  Widget _buildCompareViewContent(
    ThemeData theme,
    List<Map<String, dynamic>> sections,
    dynamic primaryVerseData,
    dynamic comparisonVerseData,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildComparisonColumn(
            context,
            sections,
            primaryVerseData as List,
            widget.scrollController1,
            widget.selectedTranslation1,
            isHebrew: widget.selectedTranslation1 == 'hebrew_original',
            isGreek: widget.selectedTranslation1 == 'greek_interlinear',
            listViewKey: PageStorageKey<String>(
                '${widget.selectedBook}-${widget.selectedChapter}-${widget.selectedTranslation1}-compareView'),
          ),
        ),
        VerticalDivider(
            width: 1,
            color: theme.dividerColor.withOpacity(0.5),
            thickness: 0.5),
        Expanded(
          child: _buildComparisonColumn(
            context,
            sections,
            comparisonVerseData as List,
            widget.scrollController2,
            widget.selectedTranslation2!,
            isHebrew: widget.selectedTranslation2 == 'hebrew_original',
            isGreek: widget.selectedTranslation2 == 'greek_interlinear',
            listViewKey: PageStorageKey<String>(
                '${widget.selectedBook}-${widget.selectedChapter}-${widget.selectedTranslation2}-compareView'),
          ),
        ),
      ],
    );
  }

  // ✅ NOVO MÉTODO HELPER: Constrói o Card do Mapa Mental.
  Widget _buildMindMapCard(ThemeData theme, String sectionId) {
    final FirestoreService _firestoreService = FirestoreService();

    return FutureBuilder<Map<String, dynamic>?>(
      future: _firestoreService.getMindMap(sectionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData ||
            snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final mapData = snapshot.data!;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias, // Importante para o Stack
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              // O conteúdo do card que você já tinha
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapData['title'] ?? 'Mapa Mental',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 400,
                      child: MindMapView(mapData: mapData),
                    ),
                  ],
                ),
              ),
              // ✅ O NOVO BOTÃO DE TELA CHEIA
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Ver em Tela Cheia',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true, // Abre como uma sobreposição
                        builder: (context) => MindMapFullscreenPage(
                          mapData: mapData,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ NOVO MÉTODO HELPER: Extrai o ID da seção dos dados.
  String _getSectionIdFromData(Map<String, dynamic> sectionData) {
    final verseNumbers = (sectionData['verses'] as List?)?.cast<int>() ?? [];
    final range = verseNumbers.isNotEmpty
        ? (verseNumbers.length == 1
            ? verseNumbers.first.toString()
            : "${verseNumbers.first}-${verseNumbers.last}")
        : "unknown";
    return "${widget.selectedBook}_c${widget.selectedChapter}_v$range";
  }

  // ✅ NOVO MÉTODO HELPER: Extrai a string de range dos dados.
  String _getVersesRangeFromData(Map<String, dynamic> sectionData) {
    final verseNumbers = (sectionData['verses'] as List?)?.cast<int>() ?? [];
    return verseNumbers.isNotEmpty
        ? (verseNumbers.length == 1
            ? verseNumbers.first.toString()
            : "${verseNumbers.first}-${verseNumbers.last}")
        : "unknown_range";
  }

  // ✅ NOVO MÉTODO HELPER: Extrai dados do interlinear para uma seção.
  List<List<Map<String, String>>>? _getHebrewDataForSection(
      Map<String, dynamic> sectionData) {
    if (!widget.showHebrewInterlinear ||
        widget.selectedTranslation1 == 'hebrew_original' ||
        widget.currentChapterHebrewData == null) {
      return null;
    }
    final allHebrewVerses = widget.currentChapterHebrewData!['data'] as List?;
    if (allHebrewVerses == null) return null;

    final verseNumbersInSection =
        (sectionData['verses'] as List?)?.cast<int>() ?? [];
    return verseNumbersInSection
        .where((vNum) => allHebrewVerses.length >= vNum && vNum > 0)
        .map(
            (vNum) => List<Map<String, String>>.from(allHebrewVerses[vNum - 1]))
        .toList();
  }

  // ✅ NOVO MÉTODO HELPER: Extrai dados do interlinear para uma seção.
  List<List<Map<String, String>>>? _getGreekDataForSection(
      Map<String, dynamic> sectionData) {
    if (!widget.showGreekInterlinear ||
        widget.selectedTranslation1 == 'greek_interlinear' ||
        widget.currentChapterGreekData == null) {
      return null;
    }
    final allGreekVerses = widget.currentChapterGreekData!['data'] as List?;
    if (allGreekVerses == null) return null;

    final verseNumbersInSection =
        (sectionData['verses'] as List?)?.cast<int>() ?? [];
    return verseNumbersInSection
        .where((vNum) => allGreekVerses.length >= vNum && vNum > 0)
        .map((vNum) => List<Map<String, String>>.from(allGreekVerses[vNum - 1]))
        .toList();
  }

  // O resto dos seus métodos (_buildComparisonColumn, _buildChapterFooter) permanecem os mesmos.
  // Cole-os aqui, sem alterações.

  Widget _buildComparisonColumn(
      BuildContext context,
      List<Map<String, dynamic>> sections,
      List verseColumnData,
      ScrollController scrollController,
      String currentTranslation,
      {bool isHebrew = false,
      bool isGreek = false,
      required PageStorageKey listViewKey}) {
    final theme = Theme.of(context);
    return StoreConnector<AppState, _BibleContentViewModel>(
        converter: (store) =>
            _BibleContentViewModel.fromStore(store, widget.selectedBook),
        distinct: true,
        builder: (context, contentViewModel) {
          return ListView.builder(
            key: listViewKey,
            controller: scrollController,
            padding: EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 16.0,
                top: widget.isFocusMode ? 8.0 : 0.0),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              final String sectionTitle = section['title'] ?? 'Seção';
              final List<int> verseNumbersInSection =
                  (section['verses'] as List?)?.cast<int>() ?? [];

              return Column(
                key: ValueKey(
                    'compare_col_section_${currentTranslation}_$sectionTitle'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
                      child: Text(sectionTitle,
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 16 * widget.fontSizeMultiplier,
                              fontWeight: FontWeight.bold))),
                  ...verseNumbersInSection.map((verseNumber) {
                    final verseIndex = verseNumber - 1;
                    dynamic verseDataItem =
                        (verseIndex >= 0 && verseIndex < verseColumnData.length)
                            ? verseColumnData[verseIndex]
                            : (isHebrew || isGreek ? [] : "[N/A]");
                    return BiblePageWidgets.buildVerseItem(
                      key: ValueKey<String>(
                          'compare_col_${currentTranslation}_${widget.selectedBook}_${widget.selectedChapter}_$verseNumber'),
                      verseNumber: verseNumber,
                      verseData: verseDataItem,
                      selectedBook: widget.selectedBook,
                      selectedChapter: widget.selectedChapter,
                      context: context,
                      userHighlights: contentViewModel.userHighlights,
                      userNotes: contentViewModel.userNotes,
                      allUserTags: contentViewModel.allUserTags,
                      fontSizeMultiplier: widget.fontSizeMultiplier,
                      isHebrew: isHebrew,
                      isGreekInterlinear: isGreek,
                    );
                  }),
                ],
              );
            },
          );
        });
  }

  Widget _buildChapterFooter(
      BuildContext context,
      ThemeData theme,
      _BibleContentViewModel contentViewModel,
      List<Map<String, dynamic>> sections) {
    final allSectionIdsInChapter = sections
        .map((section) => _getSectionIdFromData(section))
        .where((id) => !id.contains("unknown"))
        .toSet();

    final bool isChapterComplete = allSectionIdsInChapter.isNotEmpty &&
        contentViewModel.readSectionsForCurrentBook
            .containsAll(allSectionIdsInChapter);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      margin: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Center(
        child: ElevatedButton.icon(
          icon: Icon(
            isChapterComplete ? Icons.check_circle : Icons.check_circle_outline,
            color: isChapterComplete ? Colors.white : theme.colorScheme.primary,
          ),
          label: Text(isChapterComplete
              ? "Capítulo Lido"
              : "Marcar Capítulo Como Lido"),
          style: ElevatedButton.styleFrom(
            backgroundColor: isChapterComplete
                ? theme.colorScheme.primary
                : theme.colorScheme.surface,
            foregroundColor:
                isChapterComplete ? Colors.white : theme.colorScheme.primary,
            side: isChapterComplete
                ? null
                : BorderSide(color: theme.colorScheme.primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          onPressed: isChapterComplete
              ? null
              : () {
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                    MarkChapterAsReadAction(
                      bookAbbrev: widget.selectedBook,
                      chapterNumber: widget.selectedChapter,
                      sectionIdsInChapter: allSectionIdsInChapter.toList(),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${widget.selectedBook.toUpperCase()} ${widget.selectedChapter} marcado como lido!')),
                  );
                },
        ),
      ),
    );
  }
}
