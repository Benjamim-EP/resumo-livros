// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/actions/tts_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_commentary_modal.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';

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
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  static String? _currentlyReadingSectionId;

  @override
  bool get wantKeepAlive => true;

  String get _sectionIdForTracking {
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v$range";
  }

  String get _commentaryDocId {
    String abbrevForFirestore = widget.bookAbbrev;
    if (widget.bookAbbrev.toLowerCase() == 'job') {
      abbrevForFirestore =
          'jó'; // Use 'jó' para buscar comentários se o Firestore usa com acento
    } else if (widget.bookAbbrev.toLowerCase() == 'jo') {
      abbrevForFirestore = 'jo'; // Garante que João não seja confundido
    }
    // Para ser mais robusto, a melhor prática é ter um campo 'firestoreId' nos seus dados de livros
    // mas a verificação específica funciona para casos conhecidos.

    // Remove o sufixo _bc se ele vier dos metadados da busca, já que os IDs no Firestore não o têm.
    // Primeiro, vamos construir o ID esperado a partir dos dados do widget
    String constructedId =
        "${abbrevForFirestore}_c${widget.chapterNumber}_v${widget.versesRangeStr}";

    // A lógica anterior que fazia a conversão de "job" para "jó" foi movida para
    // as funções de fetch que usam o ID. Aqui, apenas construímos com a abreviação recebida.
    // Isso pode ser simplificado se a abreviação do widget for sempre a correta.
    return constructedId;
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
      print("Erro ao carregar nome do livro em SectionItemWidget: $e");
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

  Future<void> _prepareAndReadSection(BuildContext context) async {
    final store = StoreProvider.of<AppState>(context, listen: false);

    String versesText = "";
    if (widget.allVerseDataInChapter is List<String>) {
      for (int verseNum in widget.verseNumbersInSection) {
        if (verseNum > 0 && verseNum <= widget.allVerseDataInChapter.length) {
          versesText +=
              "Versículo $verseNum: ${widget.allVerseDataInChapter[verseNum - 1]}. ";
        }
      }
    } else {
      versesText =
          "A leitura de áudio para traduções interlineares não está disponível. ";
    }

    String commentaryText = "";
    try {
      final commentaryData =
          await _firestoreService.getSectionCommentary(_commentaryDocId);
      if (commentaryData != null && commentaryData['commentary'] is List) {
        final List<dynamic> commentsRaw = commentaryData['commentary'];
        commentaryText = commentsRaw
            .map((c) =>
                (c is Map<String, dynamic>
                    ? (c['traducao'] as String?)?.trim() ?? ""
                    : c.toString().trim()) ??
                "")
            .where((text) => text.isNotEmpty)
            .join(" ");
      }
    } catch (e) {
      print("Erro ao carregar comentário para TTS: $e");
      commentaryText = "Não foi possível carregar o comentário desta seção.";
    }

    String finalTextToSpeak = versesText;
    if (commentaryText.isNotEmpty) {
      finalTextToSpeak += "\n\nComentário bíblico da seção.\n\n$commentaryText";
    }

    if (mounted) {
      setState(() {
        _currentlyReadingSectionId = _sectionIdForTracking;
      });
      store.dispatch(TtsRequestSpeakAction(text: finalTextToSpeak));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final sectionId = _sectionIdForTracking;
    final bool currentIsRead = widget.isRead;

    return StoreConnector<AppState, bool>(
      converter: (store) =>
          store.state.ttsState.isPlaying &&
          _currentlyReadingSectionId == sectionId,
      distinct: true,
      builder: (context, isCurrentlyReadingThisSection) {
        if (!StoreProvider.of<AppState>(context, listen: false)
                .state
                .ttsState
                .isPlaying &&
            _currentlyReadingSectionId == sectionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentlyReadingSectionId = null;
              });
            }
          });
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
                ? BorderSide(
                    color: theme.primaryColor.withOpacity(0.4), width: 1)
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isCurrentlyReadingThisSection
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        color: isCurrentlyReadingThisSection
                            ? theme.colorScheme.error
                            : theme.iconTheme.color?.withOpacity(0.7),
                        size: 24,
                      ),
                      tooltip: isCurrentlyReadingThisSection
                          ? "Parar Leitura"
                          : "Ler Seção em Voz Alta",
                      onPressed: () {
                        final store =
                            StoreProvider.of<AppState>(context, listen: false);
                        if (isCurrentlyReadingThisSection) {
                          store.dispatch(TtsRequestStopAction());
                        } else {
                          store.dispatch(TtsRequestStopAction());
                          _prepareAndReadSection(context);
                        }
                      },
                      splashRadius: 22,
                      padding: const EdgeInsets.all(8),
                    ),
                    _isLoadingCommentary
                        ? Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                          )
                        : IconButton(
                            icon: Icon(Icons.comment_outlined,
                                color: theme.iconTheme.color?.withOpacity(0.7),
                                size: 22),
                            tooltip: "Ver Comentário da Seção",
                            onPressed: () => _showCommentary(context),
                            splashRadius: 20,
                            padding: const EdgeInsets.all(8),
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
                    final verseNumber =
                        widget.verseNumbersInSection[indexInSecao];
                    dynamic mainTranslationVerseDataItem;
                    List<Map<String, String>>? hebrewDataForThisVerse;
                    List<Map<String, String>>? greekDataForThisVerse;

                    if (widget.isGreekInterlinear) {
                      if (widget.allVerseDataInChapter
                              is List<List<Map<String, String>>> &&
                          verseNumber > 0 &&
                          verseNumber <=
                              (widget.allVerseDataInChapter as List).length) {
                        mainTranslationVerseDataItem =
                            (widget.allVerseDataInChapter as List<
                                List<Map<String, String>>>)[verseNumber - 1];
                      }
                    } else if (widget.isHebrew) {
                      if (widget.allVerseDataInChapter
                              is List<List<Map<String, String>>> &&
                          verseNumber > 0 &&
                          verseNumber <=
                              (widget.allVerseDataInChapter as List).length) {
                        mainTranslationVerseDataItem =
                            (widget.allVerseDataInChapter as List<
                                List<Map<String, String>>>)[verseNumber - 1];
                      }
                    } else {
                      if (widget.allVerseDataInChapter is List<String> &&
                          verseNumber > 0 &&
                          verseNumber <=
                              (widget.allVerseDataInChapter as List).length) {
                        mainTranslationVerseDataItem =
                            (widget.allVerseDataInChapter
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
                        indexInSecao <
                            widget.greekInterlinearSectionData!.length) {
                      greekDataForThisVerse =
                          widget.greekInterlinearSectionData![indexInSecao];
                    }

                    String verseKeySuffix = widget.isHebrew
                        ? "hebrew"
                        : (widget.isGreekInterlinear ? "greek" : "other");
                    if (widget.showHebrewInterlinear &&
                        hebrewDataForThisVerse != null)
                      verseKeySuffix += "_heb_interlinear";
                    if (widget.showGreekInterlinear &&
                        greekDataForThisVerse != null)
                      verseKeySuffix += "_grk_interlinear";

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
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                          ToggleSectionReadStatusAction(
                            bookAbbrev: widget.bookAbbrev,
                            sectionId: sectionId,
                            markAsRead: !currentIsRead,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: theme.primaryColor.withOpacity(0.3),
                      highlightColor: theme.primaryColor.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
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
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentIsRead ? "Lido" : "Marcar como Lido",
                              style: TextStyle(
                                color: currentIsRead
                                    ? theme.primaryColor
                                    : theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: currentIsRead
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
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
      },
    );
  }
}
