// lib/pages/bible_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/consts/consts.dart';
import 'package:septima_biblia/pages/biblie_page/bible_navigation_controls.dart';
import 'package:septima_biblia/pages/biblie_page/bible_options_bar.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/bible_reader_view.dart';
import 'package:septima_biblia/pages/biblie_page/bible_semantic_search_view.dart';
import 'package:septima_biblia/pages/biblie_page/bible_search_filter_bar.dart';
import 'package:septima_biblia/pages/biblie_page/font_size_slider_dialog.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/pdf_generation_service.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class _BiblePageViewModel {
  final String? initialBook;
  final int? initialBibleChapter;

  _BiblePageViewModel({
    this.initialBook,
    this.initialBibleChapter,
  });

  static _BiblePageViewModel fromStore(Store<AppState> store) {
    return _BiblePageViewModel(
      initialBook: store.state.userState.initialBibleBook,
      initialBibleChapter: store.state.userState.initialBibleChapter,
    );
  }
}

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  _BiblePageState createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  Map<String, dynamic>? booksMap;
  String? selectedBook;
  int? selectedChapter;

  String? _filterSelectedTestament;
  String? _filterSelectedBookAbbrev;
  String? _filterSelectedContentType;

  bool _isSemanticSearchActive = false;

  String selectedTranslation1 = 'nvi';
  String? selectedTranslation2 = 'acf';
  bool _isCompareModeActive = false;
  bool _isFocusModeActive = false;
  final FirestoreService _firestoreService = FirestoreService();

  String? _expandedItemId;
  String? _loadedExpandedContent;
  bool _isLoadingExpandedContent = false;

  bool _showHebrewInterlinear = false;
  Map<String, dynamic>? _currentChapterHebrewData;
  bool _showGreekInterlinear = false;
  Map<String, dynamic>? _currentChapterGreekData;

  String? _lastRecordedHistoryRef;
  String? _selectedBookSlug;
  Map<String, String> _bookVariationsMap = {};

  bool _hasProcessedInitialNavigation = false;

  final TextEditingController _semanticQueryController =
      TextEditingController();
  bool _showExtraOptions = false;

  final ScrollController _scrollController1 = ScrollController();
  final ScrollController _scrollController2 = ScrollController();
  bool _isSyncingScroll = false;

  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  Store<AppState>? _store;

  double _currentFontSizeMultiplier = 1.0;
  static const double MIN_FONT_MULTIPLIER = 0.8;
  static const double MAX_FONT_MULTIPLIER = 1.6;
  static const double FONT_STEP = 0.1;
  static const String FONT_SIZE_PREF_KEY = 'bible_font_size_multiplier';

  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _currentPlayerState = TtsPlayerState.stopped;
  String? _currentlyPlayingSectionId;
  TtsContentType? _currentlyPlayingContentType;

  final PdfGenerationService _pdfService = PdfGenerationService();
  bool _isGeneratingPdf = false;
  String? _existingPdfPath;

  @override
  void initState() {
    _loadFontSizePreference();
    super.initState();
    _loadInitialData();
    _scrollController1.addListener(_syncScrollFrom1To2);
    _scrollController2.addListener(_syncScrollFrom2To1);
    _ttsManager.playerState.addListener(_onTtsStateChanged);

    // Bloco de código com logs adicionados
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);

        // VERIFICAÇÃO E LOG
        if (store.state.userState.allUserTags.isEmpty) {
          print("--- [BiblePage LOG] ---");
          print("-> A lista 'allUserTags' no estado está VAZIA.");
          print("-> Despachando a ação LoadUserTagsAction().");
          print("------------------------");
          store.dispatch(LoadUserTagsAction());
        } else {
          print("--- [BiblePage LOG] ---");
          print(
              "-> A lista 'allUserTags' no estado JÁ ESTÁ CARREGADA com ${store.state.userState.allUserTags.length} tags.");
          print("------------------------");
        }
        _checkIfPdfExists();
      }
    });
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'O estudo com Hebraico e Grego Interlinear é exclusivo para assinantes Premium. Desbloqueie este e outros recursos!'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // É preciso usar um StatefulBuilder para que o slider atualize
        // a UI do diálogo em tempo real sem reconstruir a página inteira.
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return FontSizeSliderDialog(
              initialSize: _currentFontSizeMultiplier * 16.0,
              minSize: MIN_FONT_MULTIPLIER * 16.0,
              maxSize: MAX_FONT_MULTIPLIER * 16.0,
              onSizeChanged: (newAbsoluteSize) {
                final newMultiplier = newAbsoluteSize / 16.0;
                // Chama o setState da BiblePage para atualizar a fonte na tela principal
                setState(() {
                  _currentFontSizeMultiplier = newMultiplier.clamp(
                      MIN_FONT_MULTIPLIER, MAX_FONT_MULTIPLIER);
                });
                // Também atualiza o estado do diálogo para o texto de exemplo
                stfSetState(() {});
              },
            );
          },
        );
      },
    ).then((_) {
      // Salva a preferência de fonte quando o diálogo for fechado
      _saveFontSizePreference(_currentFontSizeMultiplier);
    });
  }

  // NOVO MÉTODO: Verifica se o PDF já existe para o capítulo atual
  Future<void> _checkIfPdfExists() async {
    if (selectedBook == null || selectedChapter == null) return;

    final bookName = booksMap?[selectedBook]?['nome'] ?? selectedBook!;
    final fileName =
        'septima_biblia_${bookName.replaceAll(' ', '_')}_${selectedChapter!}.pdf';

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _existingPdfPath = file.path;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _existingPdfPath = null;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _existingPdfPath = null);
    }
  }

  @override
  void dispose() {
    _semanticQueryController.dispose();
    _scrollController1.removeListener(_syncScrollFrom1To2);
    _scrollController2.removeListener(_syncScrollFrom2To1);
    _scrollController1.dispose();
    _scrollController2.dispose();
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) {
      _store = StoreProvider.of<AppState>(context);
      final initialFilters = _store!.state.bibleSearchState.activeFilters;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _filterSelectedTestament = initialFilters['testamento'] as String?;
            _filterSelectedBookAbbrev =
                initialFilters['livro_curto'] as String?;
            _filterSelectedContentType = initialFilters['tipo'] as String?;
          });
        }
      });
    }
  }

  // --- Funções de Lógica ---
  Future<void> _loadFontSizePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentFontSizeMultiplier = prefs.getDouble(FONT_SIZE_PREF_KEY) ?? 1.0;
      });
    }
  }

  Future<void> _saveFontSizePreference(double multiplier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(FONT_SIZE_PREF_KEY, multiplier);
  }

  void _updateFontSize(double newMultiplier) {
    if (mounted) {
      setState(() {
        _currentFontSizeMultiplier =
            newMultiplier.clamp(MIN_FONT_MULTIPLIER, MAX_FONT_MULTIPLIER);
        _saveFontSizePreference(_currentFontSizeMultiplier);
      });
    }
  }

  void _onTtsStateChanged() {
    // >>> INÍCIO DA MODIFICAÇÃO <<<
    // Verifica se o widget ainda está montado ANTES de qualquer coisa.
    if (!mounted) return;

    // A condição crucial: só chama setState se o valor realmente mudou.
    // Sua implementação já faz isso, o que é ótimo. Vamos mantê-la.
    if (_currentPlayerState != _ttsManager.playerState.value) {
      setState(() {
        _currentPlayerState = _ttsManager.playerState.value;
        if (_currentPlayerState == TtsPlayerState.stopped) {
          _currentlyPlayingSectionId = null;
          _currentlyPlayingContentType = null;
        }
      });
    }
    // >>> FIM DA MODIFICAÇÃO <<<
  }

  void _handlePlayRequest(String sectionId, TtsContentType contentType) {
    if (mounted) {
      final isPlayingThisExactItem = _currentlyPlayingSectionId == sectionId &&
          _currentlyPlayingContentType == contentType;
      switch (_currentPlayerState) {
        case TtsPlayerState.stopped:
          _startNewPlayback(sectionId, contentType);
          break;
        case TtsPlayerState.playing:
          if (isPlayingThisExactItem)
            _ttsManager.pause();
          else
            _startNewPlayback(sectionId, contentType);
          break;
        case TtsPlayerState.paused:
          if (isPlayingThisExactItem)
            _ttsManager.restartCurrentItem();
          else
            _startNewPlayback(sectionId, contentType);
          break;
      }
    }
  }

  void _startNewPlayback(
      String startSectionId, TtsContentType contentType) async {
    await _ttsManager.stop();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Preparando áudio..."), duration: Duration(seconds: 15)));

    try {
      final chapterData = await BiblePageHelper.loadChapterDataComparison(
          selectedBook!, selectedChapter!, selectedTranslation1, null);
      final List<Map<String, dynamic>> sections =
          List.from(chapterData['sectionStructure'] ?? []);
      final dynamic verseData = chapterData['verseData']?[selectedTranslation1];

      if (sections.isEmpty || verseData == null || verseData is! List<String>) {
        throw Exception("Dados do capítulo inválidos.");
      }

      List<TtsQueueItem> fullChapterQueue = [];
      List<String> splitTextIntoSentences(String text) {
        String sanitizedText = text
            .replaceAll(RegExp(r'\s{2,}', multiLine: true), ' ')
            .replaceAll(RegExp(r'\n'), ' ')
            .trim();
        if (sanitizedText.isEmpty) return [];
        List<String> sentences = sanitizedText.split(RegExp(r'(?<=[.?!])\s*'));
        final List<String> finalChunks = [];
        const int maxLength = 3500;
        for (var sentence in sentences) {
          if (sentence.length > maxLength) {
            for (var i = 0; i < sentence.length; i += maxLength) {
              final end = (i + maxLength > sentence.length)
                  ? sentence.length
                  : i + maxLength;
              finalChunks.add(sentence.substring(i, end));
            }
          } else if (sentence.trim().isNotEmpty) {
            finalChunks.add(sentence);
          }
        }
        return finalChunks;
      }

      for (var section in sections) {
        final List<int> verseNumbers =
            (section['verses'] as List?)?.cast<int>() ?? [];
        final String versesRangeForId = verseNumbers.isNotEmpty
            ? (verseNumbers.length == 1
                ? verseNumbers.first.toString()
                : "${verseNumbers.first}-${verseNumbers.last}")
            : "all";
        final String currentSectionId =
            "${selectedBook}_c${selectedChapter}_v$versesRangeForId";
        final String sectionTitle = section['title'] ?? '';

        if (sectionTitle.isNotEmpty) {
          fullChapterQueue.add(TtsQueueItem(
              sectionId: currentSectionId, textToSpeak: sectionTitle));
        }

        for (int i = 0; i < verseNumbers.length; i++) {
          int verseNum = verseNumbers[i];
          if (verseNum > 0 && verseNum <= verseData.length) {
            final verseText = verseData[verseNum - 1];
            String textToSpeak = (i == 0)
                ? "Versículo $verseNum. $verseText"
                : "$verseNum. $verseText";
            fullChapterQueue.add(TtsQueueItem(
                sectionId: currentSectionId, textToSpeak: textToSpeak));
          }
        }

        if (contentType == TtsContentType.versesAndCommentary) {
          final String versesRangeStr = verseNumbers.isNotEmpty
              ? (verseNumbers.length == 1
                  ? verseNumbers.first.toString()
                  : "${verseNumbers.first}-${verseNumbers.last}")
              : "all_verses_in_section";
          String abbrevForFirestore =
              selectedBook!.toLowerCase() == 'job' ? 'jó' : selectedBook!;
          final commentaryDocId =
              "${abbrevForFirestore}_c${selectedChapter}_v$versesRangeStr";
          final commentaryData =
              await _firestoreService.getSectionCommentary(commentaryDocId);

          if (commentaryData != null && commentaryData['commentary'] is List) {
            final commentaryList = commentaryData['commentary'] as List;
            if (commentaryList.isNotEmpty) {
              fullChapterQueue.add(TtsQueueItem(
                  sectionId: currentSectionId,
                  textToSpeak: "Comentário da seção."));
              for (var item in commentaryList) {
                final text = (item as Map)['traducao']?.trim() ??
                    (item)['original']?.trim() ??
                    '';
                if (text.isNotEmpty) {
                  final textSentences = splitTextIntoSentences(text);
                  for (var sentence in textSentences) {
                    String trimmedSentence = sentence.trim();
                    final RegExp listMarkerRegex =
                        RegExp(r'^(?:\d+|[IVXLCDM]+)\.$');
                    final RegExp bibleRefRegex = RegExp(r'[A-Za-z]+\s*\d+:\d+');
                    if (listMarkerRegex.hasMatch(trimmedSentence) &&
                        !bibleRefRegex.hasMatch(trimmedSentence)) {
                      continue;
                    }
                    fullChapterQueue.add(TtsQueueItem(
                        sectionId: currentSectionId, textToSpeak: sentence));
                  }
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentlyPlayingSectionId = startSectionId;
          _currentlyPlayingContentType = contentType;
        });
        _ttsManager.speak(fullChapterQueue, startSectionId);
      }
    } catch (e) {
      print("Erro em _startNewPlayback: $e");
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    }
  }

  Future<void> _loadCurrentChapterHebrewDataIfNeeded() async {
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!isPremium) {
      // Se não for premium, zera os dados e não faz nada.
      if (mounted) setState(() => _currentChapterHebrewData = null);
      return;
    }
    if (selectedBook != null &&
        selectedChapter != null &&
        _showHebrewInterlinear &&
        (booksMap?[selectedBook]?['testament'] == 'Antigo')) {
      if (_currentChapterHebrewData != null &&
          _currentChapterHebrewData!['book'] == selectedBook &&
          _currentChapterHebrewData!['chapter'] == selectedChapter) return;
      try {
        final hebrewData = await BiblePageHelper.loadChapterDataComparison(
            selectedBook!, selectedChapter!, 'hebrew_original', null);
        if (mounted)
          setState(() => _currentChapterHebrewData = {
                'book': selectedBook,
                'chapter': selectedChapter,
                'data': hebrewData['verseData']?['hebrew_original']
              });
      } catch (e) {
        if (mounted) setState(() => _currentChapterHebrewData = null);
      }
    } else if (!_showHebrewInterlinear && _currentChapterHebrewData != null) {
      if (mounted) setState(() => _currentChapterHebrewData = null);
    }
  }

  Future<void> _loadCurrentChapterGreekDataIfNeeded() async {
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    if (!isPremium) {
      if (mounted) setState(() => _currentChapterGreekData = null);
      return;
    }
    if (selectedBook != null &&
        selectedChapter != null &&
        _showGreekInterlinear &&
        (booksMap?[selectedBook]?['testament'] == 'Novo')) {
      if (_currentChapterGreekData != null &&
          _currentChapterGreekData!['book'] == selectedBook &&
          _currentChapterGreekData!['chapter'] == selectedChapter) return;
      try {
        final greekData = await BiblePageHelper.loadChapterDataComparison(
            selectedBook!, selectedChapter!, 'greek_interlinear', null);
        if (mounted)
          setState(() => _currentChapterGreekData = {
                'book': selectedBook,
                'chapter': selectedChapter,
                'data': greekData['verseData']?['greek_interlinear']
              });
      } catch (e) {
        if (mounted) setState(() => _currentChapterGreekData = null);
      }
    } else if (!_showGreekInterlinear && _currentChapterGreekData != null) {
      if (mounted) setState(() => _currentChapterGreekData = null);
    }
  }

  void _syncScrollFrom1To2() {
    if (_isSyncingScroll ||
        !_scrollController1.hasClients ||
        !_scrollController2.hasClients) return;
    _isSyncingScroll = true;
    if (_scrollController2.offset != _scrollController1.offset) {
      _scrollController2.jumpTo(_scrollController1.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  void _syncScrollFrom2To1() {
    if (_isSyncingScroll ||
        !_scrollController1.hasClients ||
        !_scrollController2.hasClients) return;
    _isSyncingScroll = true;
    if (_scrollController1.offset != _scrollController2.offset) {
      _scrollController1.jumpTo(_scrollController2.offset);
    }
    Future.microtask(() => _isSyncingScroll = false);
  }

  Future<void> _loadInitialData() async {
    booksMap = await BiblePageHelper.loadBooksMap();
    _bookVariationsMap = await BiblePageHelper.loadBookVariationsMapForGoTo();
    await BiblePageHelper.loadAndCacheHebrewStrongsLexicon();
    await BiblePageHelper.loadAndCacheGreekStrongsLexicon();
    if (mounted) setState(() {});
  }

  void _applyNavigationState(String book, int chapter,
      {bool forceKeyUpdate = false}) {
    if (!mounted) return;
    bool bookOrChapterChanged =
        selectedBook != book || selectedChapter != chapter;
    if (!bookOrChapterChanged && !forceKeyUpdate) return;
    if (bookOrChapterChanged) {
      final newBookData = booksMap?[book] as Map<String, dynamic>?;
      if (newBookData?['testament'] != 'Antigo') {
        if (selectedTranslation1 == 'hebrew_original')
          selectedTranslation1 = 'nvi';
        if (_isCompareModeActive && selectedTranslation2 == 'hebrew_original')
          selectedTranslation2 = 'acf';
        _showHebrewInterlinear = false;
      }
      if (newBookData?['testament'] != 'Novo') {
        if (selectedTranslation1 == 'greek_interlinear')
          selectedTranslation1 = 'nvi';
        if (_isCompareModeActive && selectedTranslation2 == 'greek_interlinear')
          selectedTranslation2 = 'acf';
        _showGreekInterlinear = false;
      }
    }

    if (mounted) {
      setState(() {
        if (bookOrChapterChanged) {
          selectedBook = book;
          selectedChapter = chapter;
          _currentChapterHebrewData = null;
          _currentChapterGreekData = null;
          _updateSelectedBookSlug();
          if (_showHebrewInterlinear) _loadCurrentChapterHebrewDataIfNeeded();
          if (_showGreekInterlinear) _loadCurrentChapterGreekDataIfNeeded();
        }
      });
      _checkIfPdfExists();
    }

    if (bookOrChapterChanged || forceKeyUpdate) {
      _recordHistory(book, chapter);
    }
  }

  Future<void> _handleGeneratePdf() async {
    if (_isGeneratingPdf ||
        selectedBook == null ||
        selectedChapter == null ||
        booksMap == null) return;

    // 1. Obter o estado atual do usuário e da assinatura do Redux
    final store = StoreProvider.of<AppState>(context, listen: false);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    final currentUserCoins = store.state.userState.userCoins;
    final userId = store.state.userState.userId;
    final isGuest = store.state.userState.isGuestUser;

    // 2. Se for Premium, gera o PDF diretamente
    if (isPremium) {
      _generatePdfAndShow(); // Chama a função que realmente faz o trabalho
      return;
    }

    // 3. Se não for Premium, verifica se tem moedas suficientes
    if (currentUserCoins < PDF_GENERATION_COST) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Moedas insuficientes. Você precisa de $PDF_GENERATION_COST moedas.'),
          action: SnackBarAction(
            label: 'Ganhar Moedas',
            onPressed: () => store.dispatch(RequestRewardedAdAction()),
          ),
        ),
      );
      return;
    }

    // 4. Se tiver moedas, mostra um diálogo de confirmação
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Ação'),
        content:
            Text('Isso custará $PDF_GENERATION_COST moedas. Deseja continuar?'),
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

    // 5. Se o usuário confirmou, deduz as moedas e gera o PDF
    if (shouldProceed == true) {
      // Deduz as moedas
      final newCoinTotal = currentUserCoins - PDF_GENERATION_COST;
      store.dispatch(UpdateUserCoinsAction(newCoinTotal));

      // Persiste a mudança no backend
      try {
        if (userId != null) {
          await _firestoreService.updateUserField(
              userId, 'userCoins', newCoinTotal);
        } else if (isGuest) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(guestUserCoinsPrefsKey, newCoinTotal);
        }

        // Finalmente, gera o PDF
        _generatePdfAndShow();
      } catch (e) {
        // Em caso de erro ao salvar as moedas, reverte a mudança e notifica o usuário
        print("Erro ao deduzir moedas para gerar PDF: $e");
        store.dispatch(UpdateUserCoinsAction(currentUserCoins)); // Reembolsa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ocorreu um erro. Suas moedas foram devolvidas.')),
        );
      }
    }
  }

// NOVO MÉTODO PRIVADO para encapsular a lógica de geração (reutilização)
  Future<void> _generatePdfAndShow() async {
    if (mounted) {
      setState(() => _isGeneratingPdf = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Gerando PDF, por favor aguarde...'),
            duration: Duration(seconds: 10)),
      );
    }

    try {
      final chapterData = await BiblePageHelper.loadChapterDataComparison(
        selectedBook!,
        selectedChapter!,
        'nvi',
        null,
      );
      final List<Map<String, dynamic>> sections =
          List.from(chapterData['sectionStructure'] ?? []);
      final Map<String, List<Map<String, dynamic>>> commentaries =
          await _firestoreService.fetchAllCommentariesForChapter(
        selectedBook!,
        selectedChapter!,
        sections,
      );

      final String filePath = await _pdfService.generateBibleChapterPdf(
        bookName: booksMap![selectedBook]!['nome'],
        chapterNumber: selectedChapter!,
        sections: sections,
        verseData: chapterData['verseData'],
        commentaries: commentaries,
      );

      if (mounted) {
        setState(() {
          _existingPdfPath = filePath;
          _isGeneratingPdf = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF gerado com sucesso!')),
        );
        OpenFile.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    }
  }

  void _processIntentOrInitialLoad(_BiblePageViewModel vm) {
    if (!mounted || booksMap == null) return;
    String targetBook;
    int targetChapter;
    bool isFromIntent =
        vm.initialBook != null && vm.initialBibleChapter != null;
    if (isFromIntent) {
      targetBook = vm.initialBook!;
      targetChapter = vm.initialBibleChapter!;
    } else {
      final store = StoreProvider.of<AppState>(context, listen: false);
      targetBook =
          store.state.userState.lastReadBookAbbrev ?? selectedBook ?? 'gn';
      targetChapter =
          store.state.userState.lastReadChapter ?? selectedChapter ?? 1;
    }
    if (booksMap!.containsKey(targetBook)) {
      final bookData = booksMap![targetBook];
      final int totalChaptersInBook = (bookData['capitulos'] as int?) ?? 0;
      if (targetChapter < 1 ||
          (totalChaptersInBook > 0 && targetChapter > totalChaptersInBook)) {
        targetChapter = 1;
      }
    } else {
      targetBook = 'gn';
      targetChapter = 1;
    }
    _applyNavigationState(targetBook, targetChapter,
        forceKeyUpdate: isFromIntent);
    if (!_hasProcessedInitialNavigation &&
        selectedBook != null &&
        selectedChapter != null) {
      _hasProcessedInitialNavigation = true;
      _loadUserDataIfNeeded(context);
    }
  }

  void _loadUserDataIfNeeded(BuildContext context) {
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    if (store.state.userState.userId != null &&
        store.state.userState.readSectionsByBook.isEmpty) {
      store.dispatch(LoadAllBibleProgressAction());
    }
  }

  void _updateSelectedBookSlug() {
    if (selectedBook != null &&
        booksMap != null &&
        booksMap![selectedBook] != null) {
      _selectedBookSlug = booksMap![selectedBook]?['slug'] as String?;
    } else {
      _selectedBookSlug = null;
    }
  }

  void _recordHistory(String bookAbbrev, int chapter) {
    if (_lastRecordedHistoryRef == "${bookAbbrev}_$chapter") return;
    _lastRecordedHistoryRef = "${bookAbbrev}_$chapter";
    if (mounted) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(RecordReadingHistoryAction(bookAbbrev, chapter));
    }
  }

  void _navigateToChapter(String bookAbbrev, int chapter) {
    _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
  }

  void _previousChapter() {
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    int newChapter = selectedChapter! - 1;
    if (newChapter > 0) {
      _applyNavigationState(selectedBook!, newChapter, forceKeyUpdate: true);
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex > 0) {
        String newBookAbbrev = bookKeys[currentBookIndex - 1];
        int lastChapterOfNewBook = booksMap![newBookAbbrev]['capitulos'] as int;
        _applyNavigationState(newBookAbbrev, lastChapterOfNewBook,
            forceKeyUpdate: true);
      }
    }
  }

  void _nextChapter() {
    if (selectedBook == null || selectedChapter == null || booksMap == null)
      return;
    int totalChaptersInCurrentBook =
        booksMap![selectedBook!]['capitulos'] as int;
    int newChapter = selectedChapter! + 1;
    if (newChapter <= totalChaptersInCurrentBook) {
      _applyNavigationState(selectedBook!, newChapter, forceKeyUpdate: true);
    } else {
      List<String> bookKeys = booksMap!.keys.toList();
      int currentBookIndex = bookKeys.indexOf(selectedBook!);
      if (currentBookIndex < bookKeys.length - 1) {
        String newBookAbbrev = bookKeys[currentBookIndex + 1];
        _applyNavigationState(newBookAbbrev, 1, forceKeyUpdate: true);
      }
    }
  }

  void _toggleItemExpansionInBiblePage(
      Map<String, dynamic> metadata, String itemId) async {
    if (!mounted) return;
    if (_expandedItemId == itemId) {
      setState(() {
        _expandedItemId = null;
        _loadedExpandedContent = null;
        _isLoadingExpandedContent = false;
      });
    } else {
      setState(() {
        _expandedItemId = itemId;
        _isLoadingExpandedContent = true;
        _loadedExpandedContent = null;
      });
      final content = await _fetchDetailedContentForBiblePage(metadata, itemId);
      if (mounted && _expandedItemId == itemId) {
        setState(() {
          _loadedExpandedContent = content;
          _isLoadingExpandedContent = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingExpandedContent = false);
      }
    }
  }

  Future<String> _fetchDetailedContentForBiblePage(
      Map<String, dynamic> metadata, String itemIdFromSearch) async {
    final tipo = metadata['tipo'] as String?;
    String? bookAbbrevFromMeta = metadata['livro_curto'] as String?;
    final chapterStr = metadata['capitulo']?.toString();
    final versesRange = metadata['versiculos'] as String?;

    print(
        "Fetching detailed content for BiblePage - itemIdFromSearch: $itemIdFromSearch, tipo: $tipo, bookFromMeta: $bookAbbrevFromMeta, chapter: $chapterStr, verses: $versesRange");

    if (tipo == 'biblia_versiculos' &&
        bookAbbrevFromMeta != null &&
        chapterStr != null &&
        versesRange != null) {
      // Lógica para buscar versículos (permanece a mesma)
      try {
        // ... (código de busca de versículos como na versão anterior) ...
        final List<String> versesContent = [];
        final int? chapterInt = int.tryParse(chapterStr);
        if (chapterInt == null) return "Erro: Capítulo inválido.";

        final chapterDataMap = await BiblePageHelper.loadChapterDataComparison(
          bookAbbrevFromMeta,
          chapterInt,
          'nvi',
          null,
        );
        final dynamic nviVerseListData = chapterDataMap['verseData']?['nvi'];

        if (nviVerseListData != null && nviVerseListData is List) {
          final List<String> nviVerseList =
              nviVerseListData.map((e) => e.toString()).toList();
          List<int> verseNumbersToLoad = [];
          if (versesRange.contains('-')) {
            final parts = versesRange.split('-');
            if (parts.length == 2) {
              final start = int.tryParse(parts[0]);
              final end = int.tryParse(parts[1]);
              if (start != null && end != null && start <= end) {
                for (int i = start; i <= end; i++) verseNumbersToLoad.add(i);
              }
            }
          } else {
            final singleVerse = int.tryParse(versesRange);
            if (singleVerse != null) verseNumbersToLoad.add(singleVerse);
          }
          if (verseNumbersToLoad.isEmpty)
            return "Intervalo de versículos inválido: $versesRange";
          for (int vn in verseNumbersToLoad) {
            if (vn > 0 && vn <= nviVerseList.length) {
              versesContent.add("**$vn** ${nviVerseList[vn - 1]}");
            } else {
              versesContent.add("**$vn** [Texto não disponível na NVI]");
            }
          }
          return versesContent.isNotEmpty
              ? versesContent.join("\n\n")
              : "Texto dos versículos não encontrado.";
        } else {
          return "Dados dos versículos NVI não encontrados.";
        }
      } catch (e, s) {
        print(
            "Erro ao carregar versículos para $itemIdFromSearch: $e\nStack: $s");
        return "Erro ao carregar versículos.";
      }
    } else if (tipo == 'biblia_comentario_secao') {
      String docIdToFetch = itemIdFromSearch;

      // 1. Remove o sufixo '_bc' se ele existir no ID vindo da busca
      if (docIdToFetch.endsWith('_bc')) {
        docIdToFetch = docIdToFetch.substring(0, docIdToFetch.length - 3);
        print(
            "BiblePage _fetchDetailedContent: Sufixo '_bc' removido. ID agora: $docIdToFetch");
      }

      // 2. Corrige a abreviação de Jó se necessário (de 'job_' para 'jó_')
      //    Isso deve ser feito DEPOIS de remover o _bc, caso a busca retorne algo como 'job_c1_v1-5_bc'
      //    Especialmente se bookAbbrevFromMeta vier como 'job' e o itemIdFromSearch também.
      if (bookAbbrevFromMeta != null &&
          bookAbbrevFromMeta.toLowerCase() == 'job') {
        if (docIdToFetch.startsWith('job_')) {
          docIdToFetch = docIdToFetch.replaceFirst('job_', 'jó_');
          print(
              "BiblePage _fetchDetailedContent: ID de comentário para Jó ajustado para Firestore: $docIdToFetch (original da busca: $itemIdFromSearch)");
        }
      }

      print(
          "BiblePage _fetchDetailedContent: Tentando buscar comentário com Doc ID final: $docIdToFetch");

      try {
        final commentaryData =
            await _firestoreService.getSectionCommentary(docIdToFetch);

        if (commentaryData != null && commentaryData['commentary'] is List) {
          final List<dynamic> commentsRaw = commentaryData['commentary'];
          if (commentsRaw.isEmpty)
            return "Nenhum comentário disponível para esta seção.";
          final List<String> commentsText = commentsRaw
              .map((c) =>
                  (c is Map<String, dynamic>
                      ? (c['traducao'] as String?)?.trim() ??
                          (c['original'] as String?)?.trim()
                      : c.toString().trim()) ??
                  "")
              .where((text) => text.isNotEmpty)
              .toList();
          if (commentsText.isEmpty) return "Comentário com texto vazio.";
          return commentsText.join("\n\n---\n\n");
        }
        print(
            "Comentário não encontrado ou em formato inválido para a seção: $docIdToFetch");
        return "Comentário não encontrado para a seção.";
      } catch (e, s) {
        print(
            "Erro ao carregar comentário para $itemIdFromSearch (tentativa com docId: $docIdToFetch): $e\nStack: $s");
        return "Erro ao carregar comentário.";
      }
    }
    print("Tipo de conteúdo desconhecido ou dados insuficientes: $tipo");
    return "Detalhes não disponíveis para este tipo de conteúdo.";
  }

  void _applyFiltersToReduxAndSearch() {
    if (!mounted || _store == null) return;
    _store!.dispatch(
        SetBibleSearchFilterAction('testamento', _filterSelectedTestament));
    _store!.dispatch(
        SetBibleSearchFilterAction('livro_curto', _filterSelectedBookAbbrev));
    _store!.dispatch(
        SetBibleSearchFilterAction('tipo', _filterSelectedContentType));
    final queryToSearch = _semanticQueryController.text.trim();
    if (queryToSearch.isNotEmpty) {
      _store!.dispatch(SearchBibleSemanticAction(queryToSearch));
    } else {
      _store!.dispatch(SearchBibleSemanticSuccessAction([]));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Digite um termo para buscar ou selecione do histórico.')));
    }
  }

  void _clearFiltersInReduxAndResetLocal() {
    if (!mounted || _store == null) return;
    setState(() {
      _filterSelectedTestament = null;
      _filterSelectedBookAbbrev = null;
      _filterSelectedContentType = null;
    });
    _store!.dispatch(ClearBibleSearchFiltersAction());
  }

  void _handleGlobalAudioControl() {
    if (mounted) {
      if (_currentPlayerState == TtsPlayerState.playing)
        _ttsManager.pause();
      else if (_currentPlayerState == TtsPlayerState.paused)
        _ttsManager.restartCurrentItem();
    }
  }

  void _navigateToVerseFromSearch(String bookAbbrev, int chapter) {
    if (mounted) {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(RequestBottomNavChangeAction(1));
    }
  }

  String _normalizeSearchText(String text) {
    return unorm
        .nfd(text.toLowerCase().trim())
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }

  void _parseAndNavigateForGoTo(String input, BuildContext dialogContext,
      Function(String?) updateErrorText) {
    String userInput = input.trim();
    if (userInput.isEmpty) {
      updateErrorText("Digite uma referência.");
      return;
    }

    String normalizedUserInput = _normalizeSearchText(userInput);
    String? foundBookAbbrev;
    String remainingInputForChapterAndVerse = "";
    List<String> sortedVariationKeys = _bookVariationsMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (String normalizedVariationKeyInMap in sortedVariationKeys) {
      if (normalizedUserInput.startsWith(normalizedVariationKeyInMap)) {
        foundBookAbbrev = _bookVariationsMap[normalizedVariationKeyInMap];
        remainingInputForChapterAndVerse = normalizedUserInput
            .substring(normalizedVariationKeyInMap.length)
            .trim();
        break;
      }
    }

    if (foundBookAbbrev == null) {
      updateErrorText("Livro não reconhecido.");
      return;
    }

    final RegExp chapVerseRegex =
        RegExp(r"^\s*(\d+)\s*(?:[:\.]\s*(\d+)(?:\s*-\s*(\d+))?)?\s*$");
    final Match? cvMatch =
        chapVerseRegex.firstMatch(remainingInputForChapterAndVerse);

    if (cvMatch == null || cvMatch.group(1) == null) {
      updateErrorText("Formato de capítulo/versículo inválido.");
      return;
    }

    final int? chapter = int.tryParse(cvMatch.group(1)!);
    if (chapter == null) {
      updateErrorText("Número do capítulo inválido.");
      return;
    }

    _finalizeNavigation(
        foundBookAbbrev, chapter, dialogContext, updateErrorText);
  }

  void _finalizeNavigation(String bookAbbrev, int chapter,
      BuildContext dialogContext, Function(String?) updateErrorText) {
    if (booksMap != null && booksMap!.containsKey(bookAbbrev)) {
      final bookData = booksMap![bookAbbrev];
      if (chapter >= 1 && chapter <= (bookData['capitulos'] as int)) {
        _applyNavigationState(bookAbbrev, chapter, forceKeyUpdate: true);
        if (Navigator.canPop(dialogContext)) Navigator.of(dialogContext).pop();
        updateErrorText(null);
      } else {
        updateErrorText('Capítulo $chapter inválido para ${bookData['nome']}.');
      }
    } else {
      updateErrorText('Livro "$bookAbbrev" não encontrado.');
    }
  }

  Future<void> _showGoToDialog() async {
    final TextEditingController controller = TextEditingController();
    String? errorTextInDialog;
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (sfbContext, setDialogState) {
          final theme = Theme.of(sfbContext);
          return AlertDialog(
            backgroundColor: theme.dialogBackgroundColor,
            title: Text("Ir para Referência",
                style: TextStyle(color: theme.colorScheme.onSurface)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: controller,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                    hintText: "Ex: Gn 1 ou João 3:16",
                    errorText: errorTextInDialog),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) =>
                    _parseAndNavigateForGoTo(value, dialogContext, (newError) {
                  if (mounted)
                    setDialogState(() => errorTextInDialog = newError);
                }),
              ),
              const SizedBox(height: 8),
              Text("Formatos: Livro Cap ou Livro Cap:Ver",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12)),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text("Cancelar",
                      style: TextStyle(
                          color:
                              theme.colorScheme.onSurface.withOpacity(0.7)))),
              TextButton(
                  onPressed: () => _parseAndNavigateForGoTo(
                          controller.text, dialogContext, (newError) {
                        if (mounted)
                          setDialogState(() => errorTextInDialog = newError);
                      }),
                  child: Text("Ir",
                      style: TextStyle(color: theme.colorScheme.primary))),
            ],
          );
        });
      },
    );
  }

  Future<void> _showVoiceSelectionDialog() async {
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Usa um ValueNotifier para o estado de loading dentro do diálogo.
    // Isso evita qualquer chamada a setState na BiblePage.
    final ValueNotifier<bool> isLoadingVoices = ValueNotifier(true);

    // Carrega as vozes ANTES de abrir o diálogo principal
    List<Map<dynamic, dynamic>> availableVoices = [];
    String? loadingError;

    try {
      availableVoices = await _ttsManager.getAvailableVoices();
    } catch (e, s) {
      print("ERRO GRAVE ao obter vozes TTS: $e\n$s");
      loadingError =
          'Não foi possível carregar as vozes. O motor de voz deste dispositivo pode não ser compatível.';
    } finally {
      isLoadingVoices.value = false;
    }

    // Se o contexto foi descartado enquanto as vozes carregavam, não faz nada.
    if (!mounted) return;

    // Se houve um erro durante o carregamento, mostra o erro e não abre o diálogo.
    if (loadingError != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(loadingError),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Se não há vozes, informa o usuário e não abre o diálogo.
    if (availableVoices.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text(
              "Nenhuma das vozes padrão foi encontrada neste dispositivo.")));
      return;
    }

    // Mostra o diálogo de seleção de voz
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.dialogBackgroundColor,
          title: Text("Selecionar Voz",
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableVoices.length,
              itemBuilder: (context, index) {
                final voice = availableVoices[index];
                final String rawVoiceName = voice['name'] as String? ?? '';
                final String displayName =
                    _ttsManager.getVoiceDisplayName(rawVoiceName);

                return ListTile(
                  title: Text(displayName,
                      style: TextStyle(color: theme.colorScheme.onSurface)),
                  onTap: () {
                    // Simplesmente chama o método do TtsManager e fecha o diálogo.
                    // NENHUMA CHAMADA a setState aqui.
                    _ttsManager.setVoice(voice);
                    Navigator.of(dialogContext).pop();
                    scaffoldMessenger.showSnackBar(SnackBar(
                        content: Text("Voz alterada para: $displayName")));
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text("Cancelar",
                    style: TextStyle(color: theme.colorScheme.primary))),
          ],
        );
      },
    );
  }

  List<Widget> _buildAppBarActions() {
    // <<< OBTEMOS O TEMA E isPremium AQUI DENTRO >>>
    final theme = Theme.of(context);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    final Color defaultIconColor = theme.appBarTheme.actionsIconTheme?.color ??
        theme.colorScheme.onPrimary;

    // Caso 1: Modo Foco está ativo
    if (_isFocusModeActive) {
      return [
        IconButton(
          icon: Icon(Icons.fullscreen_exit, color: defaultIconColor),
          tooltip: "Sair do Modo Foco",
          onPressed: () => setState(() => _isFocusModeActive = false),
        ),
      ];
    }

    // Caso 2: Modo de Busca Semântica está ativo
    if (_isSemanticSearchActive) {
      return [
        IconButton(
          icon: Icon(Icons.search, color: theme.colorScheme.primary, size: 26),
          tooltip: "Buscar",
          onPressed: _applyFiltersToReduxAndSearch,
        ),
        IconButton(
          icon: Icon(Icons.close, color: defaultIconColor, size: 26),
          tooltip: "Fechar Busca",
          onPressed: () => setState(() {
            _isSemanticSearchActive = false;
            _semanticQueryController.clear();
          }),
        ),
      ];
    }

    // Caso 3: Modo de visualização normal
    return [
      // --- BOTÃO DE ÁUDIO ---
      if (_currentPlayerState != TtsPlayerState.stopped)
        IconButton(
          icon: Icon(
            _currentPlayerState == TtsPlayerState.playing
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          tooltip: _currentPlayerState == TtsPlayerState.playing
              ? "Pausar Leitura"
              : "Continuar Leitura",
          onPressed: _handleGlobalAudioControl,
        )
      else
        IconButton(
          icon: Icon(Icons.record_voice_over_outlined, color: defaultIconColor),
          tooltip: "Ouvir Capítulo / Alterar Voz",
          onPressed: _showVoiceSelectionDialog,
        ),

      // --- BOTÃO DE PDF ---
      if (_isGeneratingPdf)
        const Padding(
          padding: EdgeInsets.all(12.0),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        )
      else if (_existingPdfPath != null)
        PopupMenuButton<String>(
          icon: Icon(Icons.picture_as_pdf,
              color: theme.colorScheme.primary, size: 26),
          tooltip: "Opções do PDF",
          onSelected: (value) {
            if (value == 'view') {
              OpenFile.open(_existingPdfPath!);
            } else if (value == 'regenerate') {
              _handleGeneratePdf();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'view',
              child: ListTile(
                  leading: Icon(Icons.visibility),
                  title: Text('Ver PDF Salvo')),
            ),
            const PopupMenuItem<String>(
              value: 'regenerate',
              child: ListTile(
                  leading: Icon(Icons.refresh), title: Text('Gerar Novamente')),
            ),
          ],
        )
      else
        IconButton(
          icon: Icon(Icons.picture_as_pdf_outlined,
              color: defaultIconColor, size: 26),
          tooltip: "Gerar PDF do Capítulo",
          onPressed: _handleGeneratePdf,
        ),

      // --- MENU AGRUPADO DE BUSCA ---
      PopupMenuButton<String>(
        icon: Icon(Icons.search, color: defaultIconColor, size: 26),
        tooltip: "Opções de Busca",
        onSelected: (value) {
          if (value == 'reference') {
            _showGoToDialog();
          } else if (value == 'semantic') {
            setState(() => _isSemanticSearchActive = true);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'reference',
            child: ListTile(
              leading: Icon(Icons.manage_search_outlined),
              title: Text('Busca por Referência'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'semantic',
            child: ListTile(
              leading: SvgPicture.asset(
                'assets/icons/buscasemantica.svg',
                colorFilter:
                    ColorFilter.mode(theme.iconTheme.color!, BlendMode.srcIn),
                width: 24,
                height: 24,
              ),
              title: const Text('Busca Semântica'),
            ),
          ),
        ],
      ),

      // --- MENU AGRUPADO DE FERRAMENTAS DE VISUALIZAÇÃO ---
      PopupMenuButton<String>(
        icon: Icon(Icons.add, color: defaultIconColor, size: 30),
        tooltip: "Mais Opções",
        onSelected: (value) {
          switch (value) {
            case 'version':
              BiblePageWidgets.showTranslationSelection(
                context: context,
                selectedTranslation: selectedTranslation1,
                onTranslationSelected: (newVal) =>
                    setState(() => selectedTranslation1 = newVal),
                currentSelectedBookAbbrev: selectedBook,
                booksMap: booksMap,
                isPremium: isPremium,
              );
              break;
            case 'focus':
              setState(() => _isFocusModeActive = !_isFocusModeActive);
              break;
            case 'compare':
              setState(() => _isCompareModeActive = !_isCompareModeActive);
              break;
            case 'fontSize':
              _showFontSizeDialog(context);
              break;
            case 'hebrew':
              if (isPremium) {
                setState(() {
                  _showHebrewInterlinear = !_showHebrewInterlinear;
                  if (_showHebrewInterlinear) {
                    _showGreekInterlinear = false;
                    _loadCurrentChapterHebrewDataIfNeeded();
                  } else {
                    _currentChapterHebrewData = null;
                  }
                });
              } else {
                _showPremiumDialog(context);
              }
              break;
            case 'greek':
              if (isPremium) {
                setState(() {
                  _showGreekInterlinear = !_showGreekInterlinear;
                  if (_showGreekInterlinear) {
                    _showHebrewInterlinear = false;
                    _loadCurrentChapterGreekDataIfNeeded();
                  } else {
                    _currentChapterGreekData = null;
                  }
                });
              } else {
                _showPremiumDialog(context);
              }
              break;
          }
        },
        itemBuilder: (BuildContext context) {
          final premiumIconColor = Colors.amber.shade700;
          final bool canShowHebrew =
              booksMap?[selectedBook]?['testament'] == 'Antigo' &&
                  !_isCompareModeActive;
          final bool canShowGreek =
              booksMap?[selectedBook]?['testament'] == 'Novo' &&
                  !_isCompareModeActive;

          return <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'version',
              child: ListTile(
                leading: Icon(Icons.translate_outlined),
                title: Text('Alterar Versão'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'fontSize',
              child: ListTile(
                leading: Icon(Icons.format_size_outlined),
                title: Text('Ajustar Fonte'),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<String>(
              value: 'focus',
              child: ListTile(
                leading: Icon(_isFocusModeActive
                    ? Icons.lightbulb
                    : Icons.lightbulb_outline),
                title: Text(
                    _isFocusModeActive ? "Sair do Modo Foco" : "Modo Foco"),
              ),
            ),
            PopupMenuItem<String>(
              value: 'compare',
              child: ListTile(
                leading: Icon(_isCompareModeActive
                    ? Icons.swap_horiz
                    : Icons.swap_horizontal_circle_outlined),
                title: Text(_isCompareModeActive
                    ? "Ver Versão Única"
                    : "Comparar Versões"),
              ),
            ),
            if (canShowHebrew || canShowGreek) const PopupMenuDivider(),
            if (canShowHebrew)
              PopupMenuItem<String>(
                value: 'hebrew',
                child: ListTile(
                  leading: SvgPicture.asset(
                    // <<< MUDANÇA AQUI
                    'assets/icons/interlinear_icon.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isPremium
                          ? (_showHebrewInterlinear
                              ? premiumIconColor
                              : theme.iconTheme
                                  .color!) // Cor normal se não selecionado
                          : premiumIconColor, // Cor de destaque se não for premium
                      BlendMode.srcIn,
                    ),
                  ),
                  title: Text('Hebraico Interlinear',
                      style: TextStyle(
                          color: isPremium ? null : premiumIconColor)),
                ),
              ),
            if (canShowGreek)
              PopupMenuItem<String>(
                value: 'greek',
                child: ListTile(
                  leading: SvgPicture.asset(
                    // <<< MUDANÇA AQUI
                    'assets/icons/interlinear_icon.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isPremium
                          ? (_showGreekInterlinear
                              ? premiumIconColor
                              : theme.iconTheme
                                  .color!) // Cor normal se não selecionado
                          : premiumIconColor, // Cor de destaque se não for premium
                      BlendMode.srcIn,
                    ),
                  ),
                  title: Text('Grego Interlinear',
                      style: TextStyle(
                          color: isPremium ? null : premiumIconColor)),
                ),
              ),
          ];
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StoreConnector<AppState, _BiblePageViewModel>(
      converter: (store) => _BiblePageViewModel.fromStore(store),
      onInit: (store) {
        _store = store;
        if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasProcessedInitialNavigation) {
              _processIntentOrInitialLoad(_BiblePageViewModel.fromStore(store));
            }
          });
        }
        _loadUserDataIfNeeded(context);
      },
      builder: (context, viewModel) {
        final subscriptionState =
            StoreProvider.of<AppState>(context).state.subscriptionState;
        final bool isUserPremium =
            subscriptionState.status == SubscriptionStatus.premiumActive;
        if (booksMap == null || _bookVariationsMap.isEmpty) {
          return Scaffold(
              appBar: AppBar(title: const Text('Bíblia')),
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary)));
        }
        if (selectedBook == null || selectedChapter == null) {
          if (mounted && booksMap != null && !_hasProcessedInitialNavigation) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_hasProcessedInitialNavigation) {
                _processIntentOrInitialLoad(viewModel);
              }
            });
          }
          return Scaffold(
              appBar: AppBar(title: const Text('Bíblia')),
              body: Center(
                  child: Text("Carregando Bíblia...",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color))));
        }

        String appBarTitleText;
        if (_isSemanticSearchActive) {
          appBarTitleText = "Busca na Bíblia";
        } else if (_isCompareModeActive) {
          // <<< MUDANÇA AQUI
          appBarTitleText =
              '${selectedTranslation1.toUpperCase()} / ${selectedTranslation2?.toUpperCase() ?? "..."}';
        } else {
          appBarTitleText = (booksMap?[selectedBook]?['nome'] ?? 'Bíblia');
          if (_isFocusModeActive) {
            if (selectedChapter != null) appBarTitleText += ' $selectedChapter';
          } else {
            // Removido o `else if (!_showExtraOptions)` que não existe mais
            if (selectedChapter != null) appBarTitleText += ' $selectedChapter';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(appBarTitleText),
            leading: _isFocusModeActive ? const SizedBox.shrink() : null,
            actions: _buildAppBarActions(),
          ),
          body: PageStorage(
            bucket: _pageStorageBucket,
            child: Column(
              children: [
                if (_isSemanticSearchActive && !_isFocusModeActive)
                  _buildSemanticSearchTextField(theme),
                if (_isSemanticSearchActive && !_isFocusModeActive)
                  _buildSemanticSearchFilterWidgets(theme),
                Expanded(
                  child: (selectedBook == null ||
                          selectedChapter == null ||
                          _selectedBookSlug == null)
                      ? const SizedBox.shrink()
                      : (_isSemanticSearchActive && !_isFocusModeActive)
                          ? BibleSemanticSearchView(
                              onToggleItemExpansion:
                                  _toggleItemExpansionInBiblePage,
                              onNavigateToVerse: _navigateToVerseFromSearch,
                              expandedItemId: _expandedItemId,
                              isLoadingExpandedContent:
                                  _isLoadingExpandedContent,
                              loadedExpandedContent: _loadedExpandedContent,
                              fontSizeMultiplier: _currentFontSizeMultiplier,
                            )
                          : BibleReaderView(
                              key: ValueKey(
                                  '$selectedBook-$selectedChapter-$selectedTranslation1-$selectedTranslation2-$_isCompareModeActive-$_showHebrewInterlinear-$_showGreekInterlinear-$_currentFontSizeMultiplier'),
                              selectedBook: selectedBook!,
                              selectedChapter: selectedChapter!,
                              selectedTranslation1: selectedTranslation1,
                              selectedTranslation2: selectedTranslation2,
                              bookSlug: _selectedBookSlug,
                              isCompareMode: _isCompareModeActive,
                              isFocusMode: _isFocusModeActive,
                              showHebrewInterlinear: _showHebrewInterlinear,
                              showGreekInterlinear: _showGreekInterlinear,
                              fontSizeMultiplier: _currentFontSizeMultiplier,
                              onPlayRequest: _handlePlayRequest,
                              currentPlayerState: _currentPlayerState,
                              currentlyPlayingSectionId:
                                  _currentlyPlayingSectionId,
                              currentlyPlayingContentType:
                                  _currentlyPlayingContentType,
                              scrollController1: _scrollController1,
                              scrollController2: _scrollController2,
                              currentChapterHebrewData:
                                  _currentChapterHebrewData,
                              currentChapterGreekData: _currentChapterGreekData,
                            ),
                ),
                if (!_isFocusModeActive && !_isSemanticSearchActive)
                  // Se o modo de comparação estiver ativo, mostra o novo seletor
                  if (_isCompareModeActive)
                    _buildComparisonSelectorBar()
                  // Senão, mostra a navegação de capítulo normal
                  else
                    BibleNavigationControls(
                      selectedBook: selectedBook,
                      selectedChapter: selectedChapter,
                      booksMap: booksMap,
                      onPreviousChapter: _previousChapter,
                      onNextChapter: _nextChapter,
                      onBookChanged: (value) {
                        if (mounted && value != null)
                          _navigateToChapter(value, 1);
                      },
                      onChapterChanged: (value) {
                        if (mounted && value != null && selectedBook != null)
                          _navigateToChapter(selectedBook!, value);
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildComparisonSelectorBar() {
    final theme = Theme.of(context);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    // Função auxiliar para criar um botão de seletor
    Widget _buildSelectorButton(
        String currentTranslation, Function(String) onSelected) {
      return Expanded(
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            BiblePageWidgets.showTranslationSelection(
              context: context,
              selectedTranslation: currentTranslation,
              onTranslationSelected: onSelected,
              currentSelectedBookAbbrev: selectedBook,
              booksMap: booksMap,
              isPremium: isPremium,
            );
          },
          child: Text(
            currentTranslation.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          _buildSelectorButton(
            selectedTranslation1,
            (newVersion) {
              // Garante que a nova versão não seja igual à do outro lado
              if (newVersion != selectedTranslation2) {
                setState(() {
                  selectedTranslation1 = newVersion;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Selecione uma versão diferente da outra coluna.'),
                  duration: Duration(seconds: 2),
                ));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.compare_arrows_rounded,
                color: theme.iconTheme.color),
          ),
          _buildSelectorButton(
            selectedTranslation2 ?? '...',
            (newVersion) {
              if (newVersion != selectedTranslation1) {
                setState(() {
                  selectedTranslation2 = newVersion;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content:
                      Text('Selecione uma versão diferente da outra coluna.'),
                  duration: Duration(seconds: 2),
                ));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSemanticSearchTextField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: TextField(
        controller: _semanticQueryController,
        autofocus: _isSemanticSearchActive,
        style: TextStyle(
            color: theme.textTheme.bodyLarge?.color ?? Colors.white,
            fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Busca semântica na Bíblia...',
          hintStyle:
              TextStyle(color: theme.hintColor.withOpacity(0.8), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
                left: 14.0, right: 10.0, top: 10.0, bottom: 10.0),
            child: SvgPicture.asset('assets/icons/buscasemantica.svg',
                colorFilter: ColorFilter.mode(
                    theme.iconTheme.color?.withOpacity(0.7) ?? theme.hintColor,
                    BlendMode.srcIn),
                width: 20,
                height: 20),
          ),
          suffixIcon: _semanticQueryController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: theme.iconTheme.color?.withOpacity(0.7), size: 22),
                  tooltip: "Limpar busca",
                  onPressed: () => _semanticQueryController.clear())
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          filled: true,
          fillColor: theme.inputDecorationTheme.fillColor ??
              theme.cardColor.withOpacity(0.08),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3), width: 0.8)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.0),
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        ),
        onSubmitted: (query) => _applyFiltersToReduxAndSearch(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildSemanticSearchFilterWidgets(ThemeData theme) {
    return BibleSearchFilterBar(
      initialBooksMap: booksMap,
      initialActiveFilters: _store?.state.bibleSearchState.activeFilters ?? {},
      onFilterChanged: (
          {String? testament, String? bookAbbrev, String? contentType}) {
        setState(() {
          _filterSelectedTestament = testament;
          _filterSelectedBookAbbrev = bookAbbrev;
          _filterSelectedContentType = contentType;
        });
      },
      onClearFilters: _clearFiltersInReduxAndResetLocal,
    );
  }
}

class DelayedLoading extends StatefulWidget {
  final bool loading;
  final Widget Function() child;
  final Duration delay;
  final Widget loadingIndicator;
  const DelayedLoading(
      {super.key,
      required this.loading,
      required this.child,
      this.delay = const Duration(milliseconds: 300),
      required this.loadingIndicator});
  @override
  State<DelayedLoading> createState() => _DelayedLoadingState();
}

class _DelayedLoadingState extends State<DelayedLoading> {
  bool _showLoadingIndicator = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (widget.loading) _startTimer();
  }

  @override
  void didUpdateWidget(DelayedLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading && !oldWidget.loading) {
      _showLoadingIndicator = false;
      _startTimer();
    } else if (!widget.loading && oldWidget.loading) {
      _cancelTimer();
      if (mounted) setState(() => _showLoadingIndicator = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.delay, () {
      if (mounted && widget.loading)
        setState(() => _showLoadingIndicator = true);
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoadingIndicator && widget.loading) return widget.loadingIndicator;
    return widget.child();
  }
}
