// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_commentary_modal.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/services/tts_manager.dart';

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int> verseNumbersInSection;
  final dynamic allVerseDataInChapter;
  final String bookSlug;
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final bool isHebrew;
  final bool isGreekInterlinear;
  final bool isRead;
  final bool showHebrewInterlinear;
  final bool showGreekInterlinear;
  final List<List<Map<String, String>>>? hebrewInterlinearSectionData;
  final List<List<Map<String, String>>>? greekInterlinearSectionData;
  final double fontSizeMultiplier;

  // Propriedades para a funcionalidade de TTS
  final Function(String startSectionId, TtsContentType contentType)
      onPlayRequest;

  // Parâmetros de estado recebidos da BiblePage para UI do player
  final TtsPlayerState currentPlayerState;
  final String? currentlyPlayingSectionId;
  final TtsContentType? currentlyPlayingContentType;

  const SectionItemWidget({
    super.key,
    required this.sectionTitle,
    required this.verseNumbersInSection,
    required this.allVerseDataInChapter,
    required this.bookSlug,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.userHighlights,
    required this.userNotes,
    this.isHebrew = false,
    this.isGreekInterlinear = false,
    required this.isRead,
    required this.showHebrewInterlinear,
    required this.showGreekInterlinear,
    this.hebrewInterlinearSectionData,
    this.greekInterlinearSectionData,
    required this.fontSizeMultiplier,
    required this.onPlayRequest,
    required this.currentPlayerState,
    this.currentlyPlayingSectionId,
    this.currentlyPlayingContentType,
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Nenhum listener de TTS aqui, pois o estado é gerenciado pela BiblePage.
  }

  @override
  void dispose() {
    // Nenhum listener para remover.
    super.dispose();
  }

  String get _sectionIdForTracking {
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v$range";
  }

  /// Apenas reporta o clique para a BiblePage.
  void _handlePlayRequest(TtsContentType contentType) {
    widget.onPlayRequest(_sectionIdForTracking, contentType);
  }

  String get _commentaryDocId {
    final range = widget.versesRangeStr.isNotEmpty
        ? widget.versesRangeStr
        : "all_verses_in_section";
    String abbrevForFirestore = widget.bookAbbrev;
    if (widget.bookAbbrev.toLowerCase() == 'job') {
      abbrevForFirestore = 'jó';
    }
    return "${abbrevForFirestore}_c${widget.chapterNumber}_v$range";
  }

  Future<void> _showCommentary(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isLoadingCommentary = true);

    final commentaryData =
        await _firestoreService.getSectionCommentary(_commentaryDocId);

    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap = await BiblePageHelper.loadBooksMap();
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {
      print("Erro ao carregar nome do livro: $e");
    }

    if (mounted) {
      setState(() => _isLoadingCommentary = false);
      final List<Map<String, dynamic>> commentaryItems =
          (commentaryData != null && commentaryData['commentary'] is List)
              ? List<Map<String, dynamic>>.from(commentaryData['commentary'])
              : const [];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SectionCommentaryModal(
          sectionTitle: commentaryData?['title'] ?? widget.sectionTitle,
          commentaryItems: commentaryItems,
          bookAbbrev: widget.bookAbbrev,
          bookSlug: widget.bookSlug,
          bookName: bookFullName,
          chapterNumber: widget.chapterNumber,
          versesRangeStr: widget.versesRangeStr,
          initialFontSizeMultiplier: widget.fontSizeMultiplier,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final bool currentIsRead = widget.isRead;

    // --- Lógica para determinar o estado dos botões desta seção ---
    final bool isThisSectionTheCurrentOne =
        widget.currentlyPlayingSectionId == _sectionIdForTracking;
    final TtsPlayerState playerState = widget.currentPlayerState;
    final TtsContentType? playingType = widget.currentlyPlayingContentType;

    final Color defaultIconColor =
        theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey;
    final Color activeIconColor =
        theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey;

    // --- Lógica para o botão de OUVIR VERSÍCULOS ---
    IconData versesIcon = Icons.play_circle_outline;
    Color versesIconColor = defaultIconColor;
    String versesTooltip = "Ouvir Versículos";

    if (isThisSectionTheCurrentOne &&
        playingType == TtsContentType.versesOnly) {
      if (playerState == TtsPlayerState.playing) {
        versesIcon = Icons.pause_circle_outline;
        versesIconColor = activeIconColor;
        versesTooltip = "Pausar Leitura";
      } else if (playerState == TtsPlayerState.paused) {
        versesIcon = Icons
            .play_circle_outline; // Ícone de "Play" para indicar "Continuar"
        versesIconColor = activeIconColor;
        versesTooltip = "Continuar Leitura";
      }
    }

    // --- Lógica para o botão de OUVIR ESTUDO ---
    IconData studyIcon = Icons.play_circle_outline;
    Color studyIconColor = Color.fromRGBO(205, 231, 190, 1);
    String studyTooltip = "Ouvir Estudo (Versículos e Comentários)";

    if (isThisSectionTheCurrentOne &&
        playingType == TtsContentType.versesAndCommentary) {
      if (playerState == TtsPlayerState.playing) {
        studyIcon = Icons.pause_circle_outline;
        studyIconColor = const Color.fromRGBO(205, 231, 190, 1);
        studyTooltip = "Pausar Leitura";
      } else if (playerState == TtsPlayerState.paused) {
        studyIcon = Icons.play_circle_outline;
        studyIconColor = activeIconColor;
        studyTooltip = "Continuar Leitura";
      }
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: currentIsRead
          ? theme.primaryColor.withOpacity(0.10)
          : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: currentIsRead
            ? BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      widget.sectionTitle,
                      style: TextStyle(
                          color: currentIsRead
                              ? theme.primaryColor
                              : theme.colorScheme.primary,
                          fontSize: 18 * widget.fontSizeMultiplier,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Botão "Ouvir Versículos" com a nova lógica de UI
                IconButton(
                  icon: Icon(versesIcon, color: versesIconColor, size: 26),
                  tooltip: versesTooltip,
                  onPressed: () =>
                      _handlePlayRequest(TtsContentType.versesOnly),
                ),

                // Botão "Ouvir Estudo" com a nova lógica de UI
                IconButton(
                  icon: Icon(studyIcon, color: studyIconColor, size: 24),
                  tooltip: studyTooltip,
                  onPressed: () =>
                      _handlePlayRequest(TtsContentType.versesAndCommentary),
                ),

                // Botão "Ver Comentário"
                if (_isLoadingCommentary)
                  const SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.all(10.0),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))))
                else
                  IconButton(
                    icon: Icon(Icons.comment_outlined,
                        color: defaultIconColor, size: 22),
                    tooltip: "Ver Comentário da Seção",
                    onPressed: () => _showCommentary(context),
                  ),
              ],
            ),
            Divider(color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.verseNumbersInSection.length,
              itemBuilder: (context, indexInSecao) {
                final verseNumber = widget.verseNumbersInSection[indexInSecao];
                dynamic mainTranslationVerseDataItem;
                List<Map<String, String>>? hebrewDataForThisVerse;
                List<Map<String, String>>? greekDataForThisVerse;

                if (widget.isGreekInterlinear) {
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else if (widget.isHebrew) {
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else {
                  if (widget.allVerseDataInChapter is List<String> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<String>)[verseNumber - 1];
                  }
                }

                if (widget.showHebrewInterlinear &&
                    !widget.isHebrew &&
                    widget.hebrewInterlinearSectionData != null &&
                    indexInSecao <
                        widget.hebrewInterlinearSectionData!.length) {
                  hebrewDataForThisVerse =
                      widget.hebrewInterlinearSectionData![indexInSecao];
                }

                if (widget.showGreekInterlinear &&
                    !widget.isGreekInterlinear &&
                    widget.greekInterlinearSectionData != null &&
                    indexInSecao < widget.greekInterlinearSectionData!.length) {
                  greekDataForThisVerse =
                      widget.greekInterlinearSectionData![indexInSecao];
                }

                String verseKeySuffix = widget.isHebrew
                    ? "hebrew"
                    : (widget.isGreekInterlinear ? "greek" : "other");
                if (widget.showHebrewInterlinear &&
                    hebrewDataForThisVerse != null) {
                  verseKeySuffix += "_heb_interlinear";
                }
                if (widget.showGreekInterlinear &&
                    greekDataForThisVerse != null) {
                  verseKeySuffix += "_grk_interlinear";
                }

                if (mainTranslationVerseDataItem != null) {
                  return BiblePageWidgets.buildVerseItem(
                    key: ValueKey<String>(
                        '${widget.bookAbbrev}_${widget.chapterNumber}_${verseNumber}_$verseKeySuffix'),
                    verseNumber: verseNumber,
                    verseData: mainTranslationVerseDataItem,
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
                    isHebrew: widget.isHebrew,
                    isGreekInterlinear: widget.isGreekInterlinear,
                    showHebrewInterlinear:
                        widget.showHebrewInterlinear && !widget.isHebrew,
                    showGreekInterlinear: widget.showGreekInterlinear &&
                        !widget.isGreekInterlinear,
                    hebrewVerseData: hebrewDataForThisVerse,
                    greekVerseData: greekDataForThisVerse,
                    fontSizeMultiplier: widget.fontSizeMultiplier,
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Erro: Verso $verseNumber não encontrado.',
                        style: TextStyle(color: theme.colorScheme.error)),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ToggleSectionReadStatusAction(
                          bookAbbrev: widget.bookAbbrev,
                          sectionId: _sectionIdForTracking,
                          markAsRead: !currentIsRead),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: theme.primaryColor.withOpacity(0.3),
                  highlightColor: theme.primaryColor.withOpacity(0.15),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            currentIsRead
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            color: currentIsRead
                                ? theme.primaryColor
                                : theme.iconTheme.color?.withOpacity(0.8),
                            size: 20),
                        const SizedBox(width: 6),
                        Text(currentIsRead ? "Lido" : "Marcar como Lido",
                            style: TextStyle(
                                color: currentIsRead
                                    ? theme.primaryColor
                                    : theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: currentIsRead
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
