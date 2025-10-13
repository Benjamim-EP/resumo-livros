// lib/pages/biblie_page/section_item_widget.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/pages/biblie_page/cross_references_row.dart';
import 'package:septima_biblia/pages/biblie_page/recommended_resources_row.dart';
import 'package:septima_biblia/pages/biblie_page/study_card_widget.dart';
import 'package:septima_biblia/pages/biblie_page/summary_display_modal.dart';
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
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String bookName;
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
  final bool isStudyModeActive;

  const SectionItemWidget({
    super.key,
    required this.sectionTitle,
    required this.verseNumbersInSection,
    required this.allVerseDataInChapter,
    required this.bookSlug,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.bookName,
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
    required this.isStudyModeActive,
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionViewModel {
  final List<String> allUserTags;
  final Map<String, List<int>> recommendedVerses;
  final bool isPremium;
  final List<LibraryReference> libraryReferences;

  _SectionViewModel({
    required this.allUserTags,
    required this.recommendedVerses,
    required this.isPremium,
    required this.libraryReferences,
  });

  static _SectionViewModel fromStore(Store<AppState> store, String sectionId) {
    // Lógica robusta para status premium
    bool premiumStatus = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!premiumStatus) {
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final status = userDetails['subscriptionStatus'] as String?;
        final endDate =
            (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();
        if (status == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now())) {
          premiumStatus = true;
        }
      }
    }

    return _SectionViewModel(
      allUserTags: store.state.userState.allUserTags,
      recommendedVerses: store.state.userState.recommendedVerses,
      isPremium: premiumStatus,
      libraryReferences:
          store.state.libraryReferenceState.referencesBySection[sectionId] ??
              [],
    );
  }

  // Otimização para o StoreConnector
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SectionViewModel &&
          runtimeType == other.runtimeType &&
          listEquals(allUserTags, other.allUserTags) &&
          mapEquals(recommendedVerses, other.recommendedVerses) &&
          isPremium == other.isPremium &&
          listEquals(libraryReferences, other.libraryReferences);

  @override
  int get hashCode =>
      allUserTags.hashCode ^
      recommendedVerses.hashCode ^
      isPremium.hashCode ^
      libraryReferences.hashCode;
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

  // void _handlePlayRequest(TtsContentType contentType) {
  //   widget.onPlayRequest(_sectionIdForTracking, contentType);
  // }

  String get _commentaryDocId {
    final range = widget.versesRangeStr.isNotEmpty
        ? widget.versesRangeStr
        : "all_verses_in_section";
    String abbrevForFirestore =
        widget.bookAbbrev.toLowerCase() == 'job' ? 'jó' : widget.bookAbbrev;
    return "${abbrevForFirestore}_c${widget.chapterNumber}_v$range";
  }

  // Future<void> _showCommentary(BuildContext context) async {
  //   if (!mounted) return;
  //   AnalyticsService.instance.logEvent(
  //     name: 'commentary_opened',
  //     parameters: {
  //       'book_abbrev': widget.bookAbbrev,
  //       'chapter_number': widget.chapterNumber,
  //       'verses_range': widget.versesRangeStr,
  //     },
  //   );
  //   TtsManager().stop();
  //   setState(() => _isLoadingCommentary = true);
  //   final commentaryData =
  //       await _firestoreService.getSectionCommentary(_commentaryDocId);
  //   String bookFullName = widget.bookAbbrev.toUpperCase();
  //   try {
  //     final booksMap = await BiblePageHelper.loadBooksMap();
  //     if (booksMap.containsKey(widget.bookAbbrev)) {
  //       bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
  //     }
  //   } catch (e) {/* ignored */}
  //   if (mounted) {
  //     setState(() => _isLoadingCommentary = false);
  //     showModalBottomSheet(
  //       context: context,
  //       isScrollControlled: true,
  //       backgroundColor: Colors.transparent,
  //       builder: (_) => SectionCommentaryModal(
  //         sectionTitle: commentaryData?['title'] ?? widget.sectionTitle,
  //         commentaryItems: (commentaryData?['commentary'] as List?)
  //                 ?.map((e) => Map<String, dynamic>.from(e))
  //                 .toList() ??
  //             [],
  //         bookAbbrev: widget.bookAbbrev,
  //         bookSlug: widget.bookSlug,
  //         bookName: bookFullName,
  //         chapterNumber: widget.chapterNumber,
  //         versesRangeStr: widget.versesRangeStr,
  //         initialFontSizeMultiplier: widget.fontSizeMultiplier,
  //       ),
  //     );
  //   }
  // }

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

  Widget _buildStudyCard(ThemeData theme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _firestoreService.getSectionCommentary(_commentaryDocId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: LinearProgressIndicator(),
          );
        }
        // Não mostra nada se não houver comentário para esta seção
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final commentaryData = snapshot.data!;
        final commentaryItems = (commentaryData['commentary'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];

        if (commentaryItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(top: 20.0),
          elevation: 0,
          color: theme.colorScheme.surface.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do Card de Estudo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Estudo da Seção", style: theme.textTheme.titleMedium),
                    // O botão de Resumo agora fica aqui dentro
                    _buildSummaryButton(theme),
                  ],
                ),
                const Divider(height: 16),
                // Conteúdo do comentário
                ...commentaryItems.map((item) {
                  final text = (item['traducao'] as String?)?.trim() ?? '';
                  if (text.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(text,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        textAlign: TextAlign.justify),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final bool currentIsRead = widget.isRead;
    final bool isThisSectionTheCurrentOne =
        widget.currentlyPlayingSectionId == _sectionIdForTracking;
    final TtsPlayerState playerState = widget.currentPlayerState;

    // <<< LÓGICA DO ÍCONE ATUALIZADA >>>
    IconData audioIcon;
    Color audioIconColor =
        theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey;
    String audioTooltip;

    if (isThisSectionTheCurrentOne) {
      if (playerState == TtsPlayerState.playing) {
        audioIcon = Icons.pause_circle_outline;
        audioIconColor = theme.colorScheme.primary.withOpacity(0.8);
        audioTooltip = "Pausar Leitura";
      } else {
        // Paused or Stopped
        audioIcon = Icons.play_circle_outline;
        audioIconColor = theme.colorScheme.primary.withOpacity(0.8);
        audioTooltip = "Continuar Leitura";
      }
    } else {
      audioIcon = Icons.play_circle_outline;
      audioTooltip = "Ouvir Seção";
    }

    return StoreConnector<AppState, _SectionViewModel>(
      converter: (store) =>
          _SectionViewModel.fromStore(store, _sectionIdForTracking),
      distinct: true,
      builder: (context, viewModel) {
        // Acessamos os dados do ViewModel DENTRO do builder.
        final allUserTags = viewModel.allUserTags;
        final chapterId = "${widget.bookAbbrev}_${widget.chapterNumber}";
        final recommendedVersesForChapter =
            viewModel.recommendedVerses[chapterId];

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
                // --- TÍTULO E BOTÃO DE PLAY ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
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

                    // <<< INÍCIO DA GRANDE MUDANÇA: IconButton -> PopupMenuButton >>>
                    Tooltip(
                      message: audioTooltip,
                      child: PopupMenuButton<TtsContentType>(
                        // Quando um item do menu é selecionado
                        onSelected: (TtsContentType choice) {
                          // Se já estiver tocando esta seção, a ação é de pausar/continuar
                          if (isThisSectionTheCurrentOne) {
                            widget.onPlayRequest(_sectionIdForTracking,
                                choice); // A BiblePage vai lidar com o pause/resume
                          } else {
                            // Se não, inicia uma nova reprodução com a opção escolhida
                            widget.onPlayRequest(_sectionIdForTracking, choice);
                          }
                        },
                        // O ícone do botão é o que definimos na lógica acima
                        icon: Icon(audioIcon, color: audioIconColor, size: 26),
                        // Constrói os itens do menu
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<TtsContentType>>[
                          const PopupMenuItem<TtsContentType>(
                            value: TtsContentType.versesOnly,
                            child: ListTile(
                              leading: Icon(Icons.menu_book_outlined),
                              title: Text('Somente Versículos'),
                            ),
                          ),
                          const PopupMenuItem<TtsContentType>(
                            value: TtsContentType.versesAndCommentary,
                            child: ListTile(
                              leading: Icon(Icons.comment_bank_outlined),
                              title: Text('Versículos e Comentário'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // <<< FIM DA GRANDE MUDANÇA >>>
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

                    // Lógica de verificação continua aqui
                    final bool isRecommended =
                        recommendedVersesForChapter?.contains(verseNumber) ??
                            false;

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
                            isRecommended:
                                isRecommended, // <<< O parâmetro é passado aqui
                          ),
                          CrossReferencesRow(
                            bookAbbrev: widget.bookAbbrev,
                            chapter: widget.chapterNumber,
                            verse: verseNumber,
                          ),
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
                if (widget.isStudyModeActive)
                  StudyCardWidget(
                    commentaryDocId: _commentaryDocId,
                    onGenerateSummary: () {
                      widget.onShowSummaryRequest(
                          _commentaryDocId, widget.sectionTitle);
                    },
                    // <<< CORREÇÃO FINAL AQUI >>>
                    isPremium: viewModel.isPremium,
                    allUserTags: viewModel.allUserTags,
                    bookAbbrev: widget.bookAbbrev,
                    bookName: widget.bookName, // Agora deve funcionar
                    chapterNumber: widget.chapterNumber,
                    sectionIdForHighlights: _sectionIdForTracking,
                    sectionTitle: widget.sectionTitle,
                    versesRangeStr: widget.versesRangeStr,
                  ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: AnimatedRotation(
                        turns: _showResources ? 0.5 : 0.0,
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
                  ],
                ),
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
              ],
            ),
          ),
        );
      },
    );
    // ==========================================================
    // <<< FIM DA CORREÇÃO E OTIMIZAÇÃO >>>
    // ==========================================================
  }
}
