// lib/pages/biblie_page/bible_reader_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_item_widget.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:redux/redux.dart';

class _BibleContentViewModel {
  // >>> TIPO CORRIGIDO AQUI <<<
  final Map<String, Map<String, dynamic>> userHighlights;
  final Map<String, String> userNotes;
  final Set<String> readSectionsForCurrentBook;

  _BibleContentViewModel({
    required this.userHighlights,
    required this.userNotes,
    required this.readSectionsForCurrentBook,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BibleContentViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userHighlights, other.userHighlights) &&
          mapEquals(userNotes, other.userNotes) &&
          setEquals(
              readSectionsForCurrentBook, other.readSectionsForCurrentBook);

  @override
  int get hashCode =>
      userHighlights.hashCode ^
      userNotes.hashCode ^
      readSectionsForCurrentBook.hashCode;
}

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
  });

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  late Future<Map<String, dynamic>> _chapterDataFuture;

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
    });
  }

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
        final List<Map<String, dynamic>> sections =
            List<Map<String, dynamic>>.from(
                chapterData['sectionStructure'] ?? []);
        final Map<String, dynamic> verseDataMap =
            Map<String, dynamic>.from(chapterData['verseData'] ?? {});
        final dynamic primaryTranslationVerseData =
            verseDataMap[widget.selectedTranslation1];

        if (primaryTranslationVerseData == null ||
            (primaryTranslationVerseData is List &&
                primaryTranslationVerseData.isEmpty)) {
          return Center(
              child: Text(
                  'Conteúdo do capítulo não encontrado para a tradução ${widget.selectedTranslation1}.'));
        }

        if (!widget.isCompareMode) {
          return _buildSingleViewContent(
              theme, sections, primaryTranslationVerseData);
        } else {
          final dynamic comparisonVerseData =
              verseDataMap[widget.selectedTranslation2];
          if (comparisonVerseData == null ||
              (comparisonVerseData is List && comparisonVerseData.isEmpty)) {
            return Center(
                child: Text(
                    'Tradução de comparação "${widget.selectedTranslation2}" não encontrada.'));
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _buildComparisonColumn(
                      context,
                      sections,
                      primaryTranslationVerseData as List,
                      widget.scrollController1,
                      widget.selectedTranslation1,
                      isHebrew:
                          widget.selectedTranslation1 == 'hebrew_original',
                      isGreek:
                          widget.selectedTranslation1 == 'greek_interlinear',
                      listViewKey: PageStorageKey<String>(
                          '${widget.selectedBook}-${widget.selectedChapter}-${widget.selectedTranslation1}-compareView'))),
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
                      isHebrew:
                          widget.selectedTranslation2 == 'hebrew_original',
                      isGreek:
                          widget.selectedTranslation2 == 'greek_interlinear',
                      listViewKey: PageStorageKey<String>(
                          '${widget.selectedBook}-${widget.selectedChapter}-${widget.selectedTranslation2}-compareView'))),
            ],
          );
        }
      },
    );
  }

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
        return ListView.builder(
          key: PageStorageKey<String>(
              '${widget.selectedBook}-${widget.selectedChapter}-${widget.selectedTranslation1}-singleView-${widget.showHebrewInterlinear}-${widget.showGreekInterlinear}-${widget.fontSizeMultiplier}'),
          padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 16.0,
              top: widget.isFocusMode ? 8.0 : 0.0),
          itemCount: sections.isNotEmpty
              ? sections.length
              : (primaryTranslationVerseData as List?)?.length ?? 0,
          itemBuilder: (context, index) {
            if (sections.isNotEmpty) {
              final section = sections[index];
              final List<int> verseNumbersInSection =
                  (section['verses'] as List?)?.cast<int>() ?? [];
              final String versesRangeStrInSection = verseNumbersInSection
                      .isNotEmpty
                  ? (verseNumbersInSection.length == 1
                      ? verseNumbersInSection.first.toString()
                      : "${verseNumbersInSection.first}-${verseNumbersInSection.last}")
                  : "all_verses_in_section_${index}";

              List<List<Map<String, String>>>? hebrewDataForThisSection;
              if (widget.showHebrewInterlinear &&
                  !(widget.selectedTranslation1 == 'hebrew_original') &&
                  widget.currentChapterHebrewData != null) {
                final allHebrewVerses =
                    widget.currentChapterHebrewData!['data'] as List?;
                if (allHebrewVerses != null) {
                  hebrewDataForThisSection = verseNumbersInSection
                      .where(
                          (vNum) => allHebrewVerses.length >= vNum && vNum > 0)
                      .map((vNum) => List<Map<String, String>>.from(
                          allHebrewVerses[vNum - 1]))
                      .toList();
                }
              }

              List<List<Map<String, String>>>? greekDataForThisSection;
              if (widget.showGreekInterlinear &&
                  !(widget.selectedTranslation1 == 'greek_interlinear') &&
                  widget.currentChapterGreekData != null) {
                final allGreekVerses =
                    widget.currentChapterGreekData!['data'] as List?;
                if (allGreekVerses != null) {
                  greekDataForThisSection = verseNumbersInSection
                      .where(
                          (vNum) => allGreekVerses.length >= vNum && vNum > 0)
                      .map((vNum) => List<Map<String, String>>.from(
                          allGreekVerses[vNum - 1]))
                      .toList();
                }
              }

              return SectionItemWidget(
                sectionTitle: section['title'] ?? 'Seção Desconhecida',
                verseNumbersInSection: verseNumbersInSection,
                allVerseDataInChapter: primaryTranslationVerseData,
                bookSlug: widget.bookSlug!,
                bookAbbrev: widget.selectedBook,
                chapterNumber: widget.selectedChapter,
                versesRangeStr: versesRangeStrInSection,
                userHighlights: contentViewModel.userHighlights,
                userNotes: contentViewModel.userNotes,
                isHebrew: widget.selectedTranslation1 == 'hebrew_original',
                isGreekInterlinear:
                    widget.selectedTranslation1 == 'greek_interlinear',
                isRead: contentViewModel.readSectionsForCurrentBook.contains(
                    "${widget.selectedBook}_c${widget.selectedChapter}_v$versesRangeStrInSection"),
                showHebrewInterlinear: widget.showHebrewInterlinear &&
                    !(widget.selectedTranslation1 == 'hebrew_original'),
                showGreekInterlinear: widget.showGreekInterlinear &&
                    !(widget.selectedTranslation1 == 'greek_interlinear'),
                hebrewInterlinearSectionData: hebrewDataForThisSection,
                greekInterlinearSectionData: greekDataForThisSection,
                fontSizeMultiplier: widget.fontSizeMultiplier,
                onPlayRequest: widget.onPlayRequest,
                currentPlayerState: widget.currentPlayerState,
                currentlyPlayingSectionId: widget.currentlyPlayingSectionId,
                currentlyPlayingContentType: widget.currentlyPlayingContentType,
              );
            } else {
              final verseNumber = index + 1;
              return BiblePageWidgets.buildVerseItem(
                key: ValueKey(
                    '${widget.selectedBook}-${widget.selectedChapter}-$verseNumber-single'),
                verseNumber: verseNumber,
                verseData: (primaryTranslationVerseData as List)[index],
                selectedBook: widget.selectedBook,
                selectedChapter: widget.selectedChapter,
                context: context,
                userHighlights: contentViewModel.userHighlights,
                userNotes: contentViewModel.userNotes,
                fontSizeMultiplier: widget.fontSizeMultiplier,
                isHebrew: widget.selectedTranslation1 == 'hebrew_original',
                isGreekInterlinear:
                    widget.selectedTranslation1 == 'greek_interlinear',
                showHebrewInterlinear: false,
                showGreekInterlinear: false,
              );
            }
          },
        );
      },
    );
  }

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
}
