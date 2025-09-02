// lib/pages/biblie_page/section_item_widget.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/pages/bible_chat/section_chat_page.dart';
import 'package:septima_biblia/pages/biblie_page/cross_references_row.dart';
import 'package:septima_biblia/pages/biblie_page/recommended_resources_row.dart';
import 'package:septima_biblia/pages/biblie_page/summary_display_modal.dart';
import 'package:septima_biblia/pages/components/mind_map_view.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/reducers/library_reference_reducer.dart'; // <<< NOVO IMPORT
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_commentary_modal.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ViewModel (sem alterações)
class _SectionItemViewModel {
  final List<String> allUserTags;
  final bool isPremium;
  // <<< NOVO CAMPO NO VIEWMODEL >>>
  final List<LibraryReference> libraryReferences;

  _SectionItemViewModel({
    required this.allUserTags,
    required this.isPremium,
    required this.libraryReferences,
  });

  static _SectionItemViewModel fromStore(
      Store<AppState> store, String sectionId) {
    bool premiumStatus = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    return _SectionItemViewModel(
      allUserTags: store.state.userState.allUserTags,
      isPremium: premiumStatus,
      // <<< BUSCA AS REFERÊNCIAS ESPECÍFICAS PARA ESTA SEÇÃO >>>
      libraryReferences:
          store.state.libraryReferenceState.referencesBySection[sectionId] ??
              [],
    );
  }
}

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int> verseNumbersInSection;
  final dynamic allVerseDataInChapter;
  final String bookSlug;
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final Map<String, Map<String, dynamic>> userHighlights;
  final List<Map<String, dynamic>> userNotes;
  final bool isHebrew;
  final bool isGreekInterlinear;
  final bool isRead;
  final bool showHebrewInterlinear;
  final bool showGreekInterlinear;
  final List<List<Map<String, String>>>? hebrewInterlinearSectionData;
  final List<List<Map<String, String>>>? greekInterlinearSectionData;
  final double fontSizeMultiplier;
  final Function(String, TtsContentType) onPlayRequest;
  final TtsPlayerState currentPlayerState;
  final String? currentlyPlayingSectionId;
  final TtsContentType? currentlyPlayingContentType;
  final List<String> allUserTags;
  final Future<void> Function(String, String) onShowSummaryRequest;
  final bool showMindMap;

  const SectionItemWidget(
      {super.key,
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
      required this.allUserTags,
      required this.onShowSummaryRequest,
      required this.showMindMap});

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;
  bool _isGeneratingSummary = false;
  bool _isSummaryUnlocked = false;
  bool _showResources = false;
  static const String _unlockedSummariesPrefsKey = 'unlocked_bible_summaries';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkSummaryStatus();
  }

  // --- SUAS FUNÇÕES EXISTENTES (SEM ALTERAÇÕES) ---
  // A lógica delas está correta e não precisa mudar.
  Future<void> _checkSummaryStatus() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (isPremium) {
      if (mounted) setState(() => _isSummaryUnlocked = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final unlockedSummaries =
        prefs.getStringList(_unlockedSummariesPrefsKey) ?? [];
    if (unlockedSummaries.contains(_commentaryDocId)) {
      if (mounted) setState(() => _isSummaryUnlocked = true);
    }
  }

  String get _sectionIdForTracking {
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v$range";
  }

  void _handlePlayRequest(TtsContentType contentType) {
    widget.onPlayRequest(_sectionIdForTracking, contentType);
  }

  String get _commentaryDocId {
    final range = widget.versesRangeStr.isNotEmpty
        ? widget.versesRangeStr
        : "all_verses_in_section";
    String abbrevForFirestore =
        widget.bookAbbrev.toLowerCase() == 'job' ? 'jó' : widget.bookAbbrev;
    return "${abbrevForFirestore}_c${widget.chapterNumber}_v$range";
  }

  Future<void> _showCommentary(BuildContext context) async {
    if (!mounted) return;
    AnalyticsService.instance.logEvent(
      name: 'commentary_opened',
      parameters: {
        'book_abbrev': widget.bookAbbrev,
        'chapter_number': widget.chapterNumber,
        'verses_range': widget.versesRangeStr,
      },
    );
    TtsManager().stop();
    setState(() => _isLoadingCommentary = true);
    final commentaryData =
        await _firestoreService.getSectionCommentary(_commentaryDocId);
    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap = await BiblePageHelper.loadBooksMap();
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {/* ignored */}
    if (mounted) {
      setState(() => _isLoadingCommentary = false);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SectionCommentaryModal(
          sectionTitle: commentaryData?['title'] ?? widget.sectionTitle,
          commentaryItems: (commentaryData?['commentary'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              [],
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

  Future<void> _loadAndShowSummary(
      String sectionId, String sectionTitle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final summaryContent = prefs.getString(sectionId);
      if (summaryContent == null) {
        CustomNotificationService.showError(
            context, 'Resumo não encontrado. Tente gerar novamente.');
        return;
      }
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SummaryDisplayModal(
            title: sectionTitle,
            summaryContent: summaryContent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.showError(
            context, 'Não foi possível exibir o resumo.');
      }
    }
  }

  Future<void> _handleShowSummary(String sectionId, String sectionTitle) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (_isSummaryUnlocked) {
      await _loadAndShowSummary(sectionId, sectionTitle);
      return;
    }
    const int summaryCost = 3;
    final currentUserCoins = store.state.userState.userCoins;
    if (currentUserCoins < summaryCost) {
      CustomNotificationService.showWarningWithAction(
        context: context,
        message: 'Você precisa de $summaryCost moedas para gerar um resumo.',
        buttonText: 'Ganhar Moedas',
        onButtonPressed: () => store.dispatch(RequestRewardedAdAction()),
      );
      return;
    }
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gerar Resumo com IA'),
        content: Text('Isso custará $summaryCost moedas. Deseja continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (shouldProceed != true) return;
    store.dispatch(UpdateUserCoinsAction(currentUserCoins - summaryCost));
    if (mounted) setState(() => _isGeneratingSummary = true);
    try {
      final commentaryData =
          await _firestoreService.getSectionCommentary(_commentaryDocId);
      final commentaryItems = (commentaryData?['commentary'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      if (commentaryItems.isEmpty)
        throw Exception("Comentário não encontrado.");
      final contextText = commentaryItems
          .map((item) => (item['traducao'] as String? ?? "").trim())
          .where((text) => text.isNotEmpty)
          .join("\n\n");
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('generateCommentarySummary');
      final result = await callable
          .call<Map<String, dynamic>>({'context_text': contextText});
      final summary = result.data['summary'] as String?;
      if (summary == null || summary.isEmpty)
        throw Exception("A IA não retornou um resumo válido.");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sectionId, summary);
      final unlockedSummaries =
          prefs.getStringList(_unlockedSummariesPrefsKey) ?? [];
      unlockedSummaries.add(sectionId);
      await prefs.setStringList(_unlockedSummariesPrefsKey, unlockedSummaries);
      if (mounted) setState(() => _isSummaryUnlocked = true);
      await _loadAndShowSummary(sectionId, sectionTitle);
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, "Falha ao gerar o resumo. Tente novamente.");
      store
          .dispatch(UpdateUserCoinsAction(store.state.userState.userCoins + 3));
      if (mounted)
        CustomNotificationService.showSuccess(
            context, "Suas moedas foram devolvidas.");
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  Widget _buildSummaryButton(ThemeData theme) {
    if (_isGeneratingSummary) {
      return TextButton(
        onPressed: null,
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
          disabledBackgroundColor: theme.colorScheme.surface.withOpacity(0.5),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_isSummaryUnlocked) {
      return TextButton.icon(
        onPressed: () =>
            _handleShowSummary(_commentaryDocId, widget.sectionTitle),
        icon: const Icon(Icons.article_outlined, size: 20),
        label: const Text(
          "Resumo",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return TextButton.icon(
      onPressed: () =>
          _handleShowSummary(_commentaryDocId, widget.sectionTitle),
      icon: const Icon(Icons.bolt_outlined, size: 20),
      label: const Text(
        "Resumo",
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
  // --- FIM DAS FUNÇÕES EXISTENTES ---

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final bool currentIsRead = widget.isRead;
    final bool isThisSectionTheCurrentOne =
        widget.currentlyPlayingSectionId == _sectionIdForTracking;
    final TtsPlayerState playerState = widget.currentPlayerState;
    final TtsContentType? playingType = widget.currentlyPlayingContentType;
    final Color defaultIconColor =
        theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey;
    final Color activeIconColor = theme.colorScheme.primary.withOpacity(0.8);

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
        versesIcon = Icons.play_circle_outline;
        versesIconColor = activeIconColor;
        versesTooltip = "Continuar Leitura";
      }
    }

    return StoreConnector<AppState, _SectionItemViewModel>(
      converter: (store) =>
          _SectionItemViewModel.fromStore(store, _sectionIdForTracking),
      builder: (context, viewModel) {
        final allUserTags = viewModel.allUserTags;

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
                // --- TÍTULO E BOTÕES DE AÇÃO SUPERIORES ---
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8.0, top: 4.0, right: 8.0),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(versesIcon, color: versesIconColor, size: 26),
                      tooltip: versesTooltip,
                      onPressed: () =>
                          _handlePlayRequest(TtsContentType.versesOnly),
                      splashRadius: 24,
                    ),
                    _buildSummaryButton(theme),
                    const SizedBox(width: 8),
                    if (_isLoadingCommentary)
                      const SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(10.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _showCommentary(context),
                        icon: const Icon(Icons.school_outlined, size: 20),
                        label: const Text(
                          "Estudo",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const Divider(color: Colors.transparent, height: 4),

                // --- LISTA DE VERSÍCULOS ---
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
                    if (widget.allVerseDataInChapter is List &&
                        verseNumber > 0 &&
                        verseNumber <=
                            (widget.allVerseDataInChapter as List).length) {
                      mainTranslationVerseDataItem = (widget
                          .allVerseDataInChapter as List)[verseNumber - 1];
                    }
                    if (widget.showHebrewInterlinear &&
                        widget.hebrewInterlinearSectionData != null &&
                        indexInSecao <
                            widget.hebrewInterlinearSectionData!.length) {
                      hebrewDataForThisVerse =
                          widget.hebrewInterlinearSectionData![indexInSecao];
                    }
                    if (widget.showGreekInterlinear &&
                        widget.greekInterlinearSectionData != null &&
                        indexInSecao <
                            widget.greekInterlinearSectionData!.length) {
                      greekDataForThisVerse =
                          widget.greekInterlinearSectionData![indexInSecao];
                    }
                    if (mainTranslationVerseDataItem != null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BiblePageWidgets.buildVerseItem(
                            key: ValueKey<String>(
                                '${widget.bookAbbrev}_${widget.chapterNumber}_${verseNumber}'),
                            verseNumber: verseNumber,
                            verseData: mainTranslationVerseDataItem,
                            selectedBook: widget.bookAbbrev,
                            selectedChapter: widget.chapterNumber,
                            context: context,
                            userHighlights: widget.userHighlights,
                            userNotes: widget.userNotes,
                            allUserTags: allUserTags,
                            isHebrew: widget.isHebrew,
                            isGreekInterlinear: widget.isGreekInterlinear,
                            showHebrewInterlinear:
                                widget.showHebrewInterlinear &&
                                    !widget.isHebrew,
                            showGreekInterlinear: widget.showGreekInterlinear &&
                                !widget.isGreekInterlinear,
                            hebrewVerseData: hebrewDataForThisVerse,
                            greekVerseData: greekDataForThisVerse,
                            fontSizeMultiplier: widget.fontSizeMultiplier,
                          ),
                          CrossReferencesRow(
                            bookAbbrev: widget.bookAbbrev,
                            chapter: widget.chapterNumber,
                            verse: verseNumber,
                          ),
                          if (widget.showMindMap)
                            FutureBuilder<Map<String, dynamic>?>(
                              future: _firestoreService
                                  .getMindMap(_sectionIdForTracking),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 8.0),
                                    child: Center(
                                        child: LinearProgressIndicator()),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data == null) {
                                  return const SizedBox
                                      .shrink(); // Não mostra nada se não houver mapa
                                }

                                final mapData = snapshot.data!;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(height: 24),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Text(
                                        mapData['title'] ?? 'Mapa Mental',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height:
                                          400, // Aumente a altura para dar mais espaço ao mapa
                                      child: MindMapView(mapData: mapData),
                                    ),
                                  ],
                                );
                              },
                            ),
                          const Divider(height: 20),
                        ],
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'Erro: Verso $verseNumber não encontrado.',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      );
                    }
                  },
                ),

                // <<< INÍCIO DA NOVA SEÇÃO DE RECURSOS >>>
                // Este widget cuidará da animação e do conteúdo.
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showResources
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 16),
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Text(
                                "Recursos de Estudo",
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            RecommendedResourcesRow(
                                sectionId: _sectionIdForTracking),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const Divider(height: 20),
                // <<< FIM DA NOVA SEÇÃO DE RECURSOS >>>

                // --- RODAPÉ COM BOTÕES DE CHAT E MARCAR COMO LIDO ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // <<< INÍCIO DA CORREÇÃO >>>
                    // Substituímos o IconButton por um TextButton estilizado
                    TextButton.icon(
                      icon: AnimatedRotation(
                        turns: _showResources ? 0.5 : 0.0, // Gira 180 graus
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.expand_more, size: 20),
                      ),
                      label: const Text("Mais Estudos"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.textTheme.bodySmall?.color,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () =>
                          setState(() => _showResources = !_showResources),
                    ),
                    Row(
                      children: [
                        // Material(
                        //   color: Colors.transparent,
                        //   child: InkWell(
                        //     onTap: () {
                        //       final store = StoreProvider.of<AppState>(context,
                        //           listen: false);
                        //       if (store.state.userState.isGuestUser) {
                        //         showLoginRequiredDialog(context,
                        //             featureName: "o chat com a IA");
                        //       } else {
                        //         final List<String> verseTexts =
                        //             widget.verseNumbersInSection.map((vNum) {
                        //           if (widget.allVerseDataInChapter is List &&
                        //               vNum > 0 &&
                        //               vNum <=
                        //                   (widget.allVerseDataInChapter as List)
                        //                       .length) {
                        //             return (widget.allVerseDataInChapter
                        //                     as List)[vNum - 1]
                        //                 .toString();
                        //           }
                        //           return "[Texto do versículo $vNum indisponível]";
                        //         }).toList();
                        //         Navigator.push(
                        //           context,
                        //           MaterialPageRoute(
                        //             builder: (context) => SectionChatPage(
                        //               bookAbbrev: widget.bookAbbrev,
                        //               chapterNumber: widget.chapterNumber,
                        //               versesRangeStr: widget.versesRangeStr,
                        //               sectionTitle: widget.sectionTitle,
                        //               sectionVerseTexts: verseTexts,
                        //             ),
                        //           ),
                        //         );
                        //       }
                        //     },
                        //     borderRadius: BorderRadius.circular(20),
                        //     splashColor:
                        //         theme.colorScheme.primary.withOpacity(0.2),
                        //     highlightColor:
                        //         theme.colorScheme.primary.withOpacity(0.1),
                        //     child: Container(
                        //       padding: const EdgeInsets.symmetric(
                        //           horizontal: 12, vertical: 6),
                        //       decoration: BoxDecoration(
                        //         borderRadius: BorderRadius.circular(20),
                        //         border: Border.all(
                        //           color: theme.colorScheme.primary,
                        //           width: 1.0,
                        //         ),
                        //       ),
                        //       child: Row(
                        //         mainAxisSize: MainAxisSize.min,
                        //         children: [
                        //           Icon(Icons.chat_bubble_outline_rounded,
                        //               size: 18,
                        //               color: theme.colorScheme.primary),
                        //           const SizedBox(width: 6),
                        //           Text(
                        //             "Chat",
                        //             style: TextStyle(
                        //               color: theme.colorScheme.primary,
                        //               fontSize: 13,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              StoreProvider.of<AppState>(context, listen: false)
                                  .dispatch(
                                ToggleSectionReadStatusAction(
                                  bookAbbrev: widget.bookAbbrev,
                                  sectionId: _sectionIdForTracking,
                                  markAsRead: !currentIsRead,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
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
                                        : theme.iconTheme.color
                                            ?.withOpacity(0.8),
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
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
