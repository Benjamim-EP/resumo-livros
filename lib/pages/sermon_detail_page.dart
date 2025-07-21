// lib/pages/sermon_detail_page.dart
import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // Importar para listEquals e setEquals
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:septima_biblia/consts.dart';
import 'package:septima_biblia/consts/consts.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/biblie_page/summary_display_modal.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart'; // Importar SermonState
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/pdf_generation_service.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Modelo de dados para o sermão (sem alterações)
class Sermon {
  final String? generatedSermonId;
  final String? idOriginalProblematico;
  final String titleOriginal;
  final String translatedTitle;
  final String? mainScripturePassageOriginal;
  final String? mainScripturePassageAbbreviated;
  final Map<String, dynamic>? sermonDetails;
  final String? mainVerseQuoted;
  final List<String> paragraphsOriginal;
  final List<String> paragraphsPt;
  final List<String>? embeddedScripturesOriginal;
  final List<String>? embeddedScripturesAbbreviated;
  final String? preacher;

  Sermon({
    this.generatedSermonId,
    this.idOriginalProblematico,
    required this.titleOriginal,
    required this.translatedTitle,
    this.mainScripturePassageOriginal,
    this.mainScripturePassageAbbreviated,
    this.sermonDetails,
    this.mainVerseQuoted,
    required this.paragraphsOriginal,
    required this.paragraphsPt,
    this.embeddedScripturesOriginal,
    this.embeddedScripturesAbbreviated,
    this.preacher,
  });

  factory Sermon.fromJson(Map<String, dynamic> json, String generatedId) {
    return Sermon(
      generatedSermonId: generatedId,
      idOriginalProblematico: json['id_original_problematico'] as String?,
      titleOriginal: json['title_original'] as String? ??
          json['title'] as String? ??
          'Título Original Indisponível',
      translatedTitle:
          json['translated_title'] as String? ?? 'Título Indisponível',
      mainScripturePassageOriginal:
          json['main_scripture_passage_original'] as String?,
      mainScripturePassageAbbreviated:
          json['main_scripture_passage_abbreviated'] as String?,
      sermonDetails: json['sermon_details'] != null
          ? Map<String, dynamic>.from(json['sermon_details'])
          : null,
      mainVerseQuoted: json['main_verse_quoted'] as String?,
      paragraphsOriginal: List<String>.from(
          (json['paragraphs'] as List<dynamic>?)?.map((e) => e.toString()) ??
              []),
      paragraphsPt: List<String>.from(
          (json['paragraphs_pt'] as List<dynamic>?)?.map((e) => e.toString()) ??
              []),
      embeddedScripturesOriginal:
          (json['embedded_scriptures_original'] as List<dynamic>?)
              ?.cast<String>(),
      embeddedScripturesAbbreviated:
          (json['embedded_scriptures_abbreviated'] as List<dynamic>?)
              ?.cast<String>(),
      preacher: json['preacher'] as String? ??
          json['sermon_details']?['preacher'] as String?,
    );
  }

  List<String> get paragraphsToDisplay {
    if (paragraphsPt.isNotEmpty &&
        paragraphsPt.any((p) => p.trim().isNotEmpty)) {
      return paragraphsPt;
    }
    return paragraphsOriginal;
  }
}

class SermonDetailPage extends StatefulWidget {
  final String sermonGeneratedId;
  final String sermonTitle;
  final String? snippetToScrollTo;

  const SermonDetailPage({
    super.key,
    required this.sermonGeneratedId,
    required this.sermonTitle,
    this.snippetToScrollTo,
  });

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
}

// NOVO/CORRIGIDO: ViewModel para a SermonDetailPage
class _SermonDetailViewModel {
  final List<Map<String, dynamic>> highlights;
  final bool isPremium;
  final Set<String> favoritedSermonIds; // Adicionado para os favoritos

  _SermonDetailViewModel({
    required this.highlights,
    required this.isPremium,
    required this.favoritedSermonIds,
  });

  static _SermonDetailViewModel fromStore(
      Store<AppState> store, String sermonId) {
    final sermonHighlights = store.state.userState.userCommentHighlights
        .where((h) => h['sourceId'] == sermonId)
        .toList();

    bool premiumStatus = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    final favoritedSermonIds =
        store.state.sermonState.favoritedSermonIds; // Pega do SermonState

    return _SermonDetailViewModel(
      highlights: sermonHighlights,
      isPremium: premiumStatus,
      favoritedSermonIds: favoritedSermonIds, // Passa para o ViewModel
    );
  }

  // Métodos de igualdade para otimização do StoreConnector (distinct: true)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SermonDetailViewModel &&
          runtimeType == other.runtimeType &&
          listEquals(highlights, other.highlights) &&
          isPremium == other.isPremium &&
          setEquals(favoritedSermonIds, other.favoritedSermonIds);

  @override
  int get hashCode =>
      highlights.hashCode ^ isPremium.hashCode ^ favoritedSermonIds.hashCode;
}

class _SermonDetailPageState extends State<SermonDetailPage> {
  Sermon? _sermonDataFromFirestore;
  bool _isLoading = true;
  String? _error;
  double _currentFontSize = 16.0;

  List<String>? _loadedMainScriptureVerses;
  bool _isLoadingMainScripture = false;

  static const double MIN_FONT_SIZE = 12.0;
  static const double MAX_FONT_SIZE = 28.0;
  static const double FONT_STEP = 1.0;

  final FirestoreService _firestoreService = FirestoreService();
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _sermonPlayerState = TtsPlayerState.stopped;
  final Map<String, GlobalKey> _paragraphKeys = {};

  final PdfGenerationService _pdfService = PdfGenerationService();
  bool _isGeneratingPdf = false;
  String? _existingPdfPath;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  bool _isGeneratingSummary = false;
  static const String _unlockedSermonSummariesKey = 'unlocked_sermon_summaries';

  String _getSermonTextForSummary() {
    if (_sermonDataFromFirestore == null) return "";
    return _sermonDataFromFirestore!.paragraphsToDisplay.join("\n\n");
  }

  Future<void> _loadAndShowSummary(String sermonId, String sermonTitle) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final summaryContent = prefs.getString(sermonId);

      if (summaryContent == null) {
        if (mounted)
          CustomNotificationService.showError(
              context, 'Resumo não encontrado no cache.');
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SummaryDisplayModal(
            title: sermonTitle,
            summaryContent: summaryContent,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        CustomNotificationService.showError(
            context, 'Não foi possível exibir o resumo.');
    }
  }

  Future<void> _handleShowSummary(String sermonId, String sermonTitle) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;

    final prefs = await SharedPreferences.getInstance();
    final unlockedSummaries =
        prefs.getStringList(_unlockedSermonSummariesKey) ?? [];

    bool isUnlocked = isPremium || unlockedSummaries.contains(sermonId);

    if (isUnlocked) {
      final cachedSummary = prefs.getString(sermonId);
      if (cachedSummary != null) {
        await _loadAndShowSummary(sermonId, sermonTitle);
        return;
      }
    } else {
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
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirmar')),
          ],
        ),
      );

      if (shouldProceed != true) return;

      store.dispatch(UpdateUserCoinsAction(currentUserCoins - summaryCost));
    }

    setState(() => _isGeneratingSummary = true);
    CustomNotificationService.showSuccess(
        context, "Gerando resumo, aguarde...");

    try {
      final sermonText = _getSermonTextForSummary();
      if (sermonText.isEmpty) throw Exception("O texto do sermão está vazio.");

      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('generateSermonSummary');
      final result = await callable
          .call<Map<String, dynamic>>({'sermon_text': sermonText});

      final summary = result.data['summary'] as String?;
      if (summary == null || summary.isEmpty)
        throw Exception("A IA não retornou um resumo válido.");

      await prefs.setString(sermonId, summary);

      if (!isPremium) {
        unlockedSummaries.add(sermonId);
        await prefs.setStringList(
            _unlockedSermonSummariesKey, unlockedSummaries);
      }

      await _loadAndShowSummary(sermonId, sermonTitle);
    } catch (e) {
      print("Erro ao gerar resumo do sermão: $e");
      if (mounted)
        CustomNotificationService.showError(
            context, "Falha ao gerar o resumo. Tente novamente.");
      if (!isPremium) {
        store.dispatch(
            UpdateUserCoinsAction(store.state.userState.userCoins + 3));
        if (mounted)
          CustomNotificationService.showSuccess(
              context, "Suas moedas foram devolvidas.");
      }
    } finally {
      if (mounted) setState(() => _isGeneratingSummary = false);
    }
  }

  // >>> MUDANÇA: Diálogo de acesso premium <<<
  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'A marcação de trechos em sermões, livros e outros recursos da biblioteca é exclusiva para assinantes Premium.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi')),
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

  // >>> MUDANÇA: A função de highlight agora recebe o status premium <<<
  void _handleHighlight(BuildContext context, String fullParagraph,
      EditableTextState editableTextState, bool isPremium) {
    // Esconde o menu de contexto padrão
    editableTextState.hideToolbar();

    // Verifica se é premium
    if (!isPremium) {
      _showPremiumRequiredDialog(context);
      return;
    }

    final TextSelection selection =
        editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;

    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);
    _showHighlightEditor(context, selectedSnippet, fullParagraph);
  }

  // (O resto das suas funções permanece aqui: _scrollToSnippet, initState, dispose, _onTtsStateChanged, etc.)
  // ... (cole suas funções existentes aqui)
  // =======================================================================
  // >>>>>>>>>>>> NOVOS MÉTODOS PARA GERENCIAR PDF <<<<<<<<<<<<<<<
  // =======================================================================

  // Gera o nome de arquivo único para o PDF do sermão
  String _getSermonPdfFilename() {
    // Usar o ID gerado garante um nome de arquivo único e seguro
    return 'sermon_${widget.sermonGeneratedId}.pdf';
  }

  // Verifica se um PDF já existe localmente
  Future<void> _checkIfSermonPdfExists() async {
    if (_sermonDataFromFirestore == null) return;

    final fileName = _getSermonPdfFilename();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');

      if (await file.exists()) {
        if (mounted) setState(() => _existingPdfPath = file.path);
      } else {
        if (mounted) setState(() => _existingPdfPath = null);
      }
    } catch (e) {
      if (mounted) setState(() => _existingPdfPath = null);
    }
  }

  // Função principal que é chamada pelo botão para gerar o PDF
  Future<void> _handleGenerateSermonPdf() async {
    if (_isGeneratingPdf || _sermonDataFromFirestore == null) return;

    // 1. Obter estado do Redux
    final store = StoreProvider.of<AppState>(context, listen: false);
    final isPremium = store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive;
    final currentUserCoins = store.state.userState.userCoins;
    final userId = store.state.userState.userId;
    final isGuest = store.state.userState.isGuestUser;

    // 2. Acesso direto para Premium
    if (isPremium) {
      _generateSermonPdfAndShow(); // Chama a função real
      return;
    }

    // 3. Verificação de moedas para não-Premium
    if (currentUserCoins < PDF_GENERATION_COST) {
      CustomNotificationService.showWarningWithAction(
        context: context,
        message:
            'Você precisa de $PDF_GENERATION_COST moedas para gerar o PDF.',
        buttonText: 'Ganhar Moedas',
        onButtonPressed: () => store.dispatch(RequestRewardedAdAction()),
      );
      return;
    }

    // 4. Diálogo de confirmação
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Ação'),
        content:
            Text('Isso custará $PDF_GENERATION_COST moedas. Deseja continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar')),
        ],
      ),
    );

    // 5. Dedução de moedas e geração do PDF
    if (shouldProceed == true) {
      final newCoinTotal = currentUserCoins - PDF_GENERATION_COST;
      store.dispatch(UpdateUserCoinsAction(newCoinTotal));

      // Persistência da dedução
      try {
        final firestoreService =
            FirestoreService(); // Crie uma instância se não tiver uma global na classe
        if (userId != null) {
          await firestoreService.updateUserField(
              userId, 'userCoins', newCoinTotal);
        } else if (isGuest) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(guestUserCoinsPrefsKey, newCoinTotal);
        }
        _generateSermonPdfAndShow();
      } catch (e) {
        print("Erro ao deduzir moedas para gerar PDF de sermão: $e");
        store.dispatch(UpdateUserCoinsAction(currentUserCoins)); // Reembolso
        CustomNotificationService.showError(
            context, 'Ocorreu um erro. Suas moedas foram devolvidas.');
      }
    }
  }

  // NOVO MÉTODO PRIVADO para encapsular a lógica de geração (reutilização)
  Future<void> _generateSermonPdfAndShow() async {
    if (mounted) {
      setState(() => _isGeneratingPdf = true);
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(
      //       content: Text('Gerando PDF do sermão...'),
      //       duration: Duration(seconds: 10)),
      // );
    }

    try {
      final filePath = await _pdfService.generateSermonPdf(
        sermon: _sermonDataFromFirestore!,
      );

      if (mounted) {
        setState(() {
          _existingPdfPath = filePath;
          _isGeneratingPdf = false;
        });
        CustomNotificationService.showSuccess(
            context, 'PDF do sermão gerado com sucesso!');
        OpenFile.open(filePath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        CustomNotificationService.showError(
            context, 'Erro ao gerar PDF do sermão: $e');
      }
    }
  }

  void _scrollToSnippet() {
    if (widget.snippetToScrollTo == null) return;
    final keyEntry = _paragraphKeys.entries.firstWhere(
      (entry) => entry.key.contains(widget.snippetToScrollTo!),
      orElse: () => MapEntry('', GlobalKey()),
    );

    if (keyEntry.value.currentContext != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        Scrollable.ensureVisible(
          keyEntry.value.currentContext!,
          duration: const Duration(milliseconds: 500),
          alignment: 0.3,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSermonDataFromFirestore().then((_) {
      if (mounted) {
        _scrollToSnippet();
        _checkIfSermonPdfExists();
      }
    });
    _ttsManager.playerState.addListener(_onTtsStateChanged);
    _scrollController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (!_scrollController.hasClients) return;
        double progress = _scrollController.position.pixels /
            _scrollController.position.maxScrollExtent;
        if (progress.isNaN || progress.isInfinite) progress = 0.0;

        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(UpdateSermonProgressAction(
          sermonId: widget.sermonGeneratedId,
          progressPercentage: progress.clamp(0.0, 1.0),
        ));
      });
    });
  }

  @override
  void dispose() {
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    interstitialManager.tryShowInterstitial(
        fromScreen: "SermonDetailPage_Dispose");
    _scrollController.dispose(); // <<< NOVO
    _debounce?.cancel();
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (mounted) {
      if (_sermonPlayerState != _ttsManager.playerState.value) {
        setState(() => _sermonPlayerState = _ttsManager.playerState.value);
      }
    }
  }

  Future<void> _showHighlightEditor(
      BuildContext context, String snippet, String fullParagraph) async {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final List<String> allUserTags = store.state.userState.allUserTags;

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => HighlightEditorDialog(
        initialColor: "#FFA07A",
        initialTags: const [],
        allUserTags: allUserTags,
      ),
    );

    if (result == null || result.colorHex == null) return;

    final highlightData = {
      'selectedSnippet': snippet,
      'fullContext': fullParagraph,
      'sourceType': 'sermon',
      'sourceTitle': widget.sermonTitle,
      'sourceParentTitle':
          _sermonDataFromFirestore?.mainScripturePassageAbbreviated ??
              'Sermões de Spurgeon',
      'sourceId': widget.sermonGeneratedId,
      'color': result.colorHex,
      'tags': result.tags,
    };

    store.dispatch(AddCommentHighlightAction(highlightData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Destaque salvo!")),
    );
  }

  List<TextSpan> _buildHighlightedParagraph(String paragraph,
      List<Map<String, dynamic>> highlights, ThemeData theme) {
    List<TextSpan> spans = [];
    int lastEnd = 0;
    List<Map<String, dynamic>> snippetsInParagraph = [];
    for (var highlight in highlights) {
      String snippet = highlight['selectedSnippet'] ?? '';
      int startIndex = paragraph.indexOf(snippet);
      if (startIndex != -1) {
        snippetsInParagraph.add({
          'start': startIndex,
          'end': startIndex + snippet.length,
          'color': highlight['color'] as String? ?? '#FFA07A',
        });
      }
    }
    snippetsInParagraph.sort((a, b) => a['start'].compareTo(b['start']));
    for (var snippetInfo in snippetsInParagraph) {
      if (snippetInfo['start'] > lastEnd) {
        spans.add(
            TextSpan(text: paragraph.substring(lastEnd, snippetInfo['start'])));
      }
      spans.add(TextSpan(
        text: paragraph.substring(snippetInfo['start'], snippetInfo['end']),
        style: TextStyle(
          backgroundColor: Color(int.parse(
                  (snippetInfo['color'] as String).replaceFirst('#', '0xff')))
              .withOpacity(0.35),
        ),
      ));
      lastEnd = snippetInfo['end'];
    }
    if (lastEnd < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(lastEnd)));
    }
    return spans.isEmpty ? [TextSpan(text: paragraph)] : spans;
  }

  void _handleAudioControl() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.stopped:
        _startSermonPlayback();
        break;
      case TtsPlayerState.playing:
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        _ttsManager.restartCurrentItem();
        break;
    }
  }

  void _startSermonPlayback() async {
    if (_sermonDataFromFirestore == null) return;
    final sermon = _sermonDataFromFirestore!;
    List<TtsQueueItem> queue = [];
    final sermonId =
        sermon.generatedSermonId ?? "sermon_${sermon.translatedTitle.hashCode}";
    queue.add(TtsQueueItem(
        sectionId: sermonId,
        textToSpeak: "Sermão: ${sermon.translatedTitle}."));
    if (sermon.mainScripturePassageAbbreviated != null &&
        sermon.mainScripturePassageAbbreviated!.isNotEmpty) {
      final fullReferenceName = await BiblePageHelper.getFullReferenceName(
          sermon.mainScripturePassageAbbreviated!);
      final ttsFriendlyReference =
          BiblePageHelper.formatReferenceForTts(fullReferenceName);
      queue.add(TtsQueueItem(
          sectionId: sermonId,
          textToSpeak: "Passagem principal: $ttsFriendlyReference."));
    }
    if (_loadedMainScriptureVerses != null &&
        _loadedMainScriptureVerses!.isNotEmpty) {
      final versesTextOnly = _loadedMainScriptureVerses!.map((verseWithNumber) {
        final firstSpaceIndex = verseWithNumber.indexOf(' ');
        if (firstSpaceIndex != -1) {
          return verseWithNumber.substring(firstSpaceIndex + 1);
        }
        return verseWithNumber;
      }).join(" ");
      if (versesTextOnly.trim().isNotEmpty) {
        queue.add(
            TtsQueueItem(sectionId: sermonId, textToSpeak: versesTextOnly));
      }
    }
    for (var paragraph in sermon.paragraphsToDisplay) {
      if (paragraph.trim().isNotEmpty) {
        queue.add(TtsQueueItem(sectionId: sermonId, textToSpeak: paragraph));
      }
    }
    _ttsManager.speak(queue, sermonId);
  }

  IconData _getAudioIcon() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.playing:
        return Icons.pause_circle_outline;
      case TtsPlayerState.paused:
        return Icons.play_circle_outline;
      case TtsPlayerState.stopped:
        return Icons.play_circle_outline;
    }
  }

  String _getAudioTooltip() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar do Início do Parágrafo";
      case TtsPlayerState.stopped:
        return "Ouvir Sermão";
    }
  }

  Future<void> _loadSermonDataFromFirestore() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final sermonMap = await _firestoreService
          .getSermonDetailsFromFirestore(widget.sermonGeneratedId);
      if (mounted && sermonMap != null) {
        final sermonData = Sermon.fromJson(sermonMap, widget.sermonGeneratedId);
        setState(() {
          _sermonDataFromFirestore = sermonData;
          _error = null; // ✅ Limpa qualquer erro anterior em caso de sucesso
        });
        if (sermonData.mainScripturePassageAbbreviated != null &&
            sermonData.mainScripturePassageAbbreviated!.isNotEmpty) {
          await _loadMainScripture(sermonData.mainScripturePassageAbbreviated!);
        }
        _scrollToSavedPosition();
      } else if (mounted) {
        // ✅ Mensagem de erro mais específica se o sermão não for encontrado
        setState(() => _error = "Sermão não foi encontrado.");
      }
    } catch (e) {
      if (mounted) {
        print("Erro ao carregar sermão: $e"); // Log para você
        // ✅ Mensagem de erro genérica e amigável para o usuário
        setState(() => _error =
            "Falha na conexão. Verifique sua internet e tente novamente.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToSavedPosition() {
    // Garante que a função só execute após a UI estar completamente construída.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Verifica se o widget ainda está na tela

      // Pega o progresso salvo do estado Redux
      final SermonProgressData? progress =
          StoreProvider.of<AppState>(context, listen: false)
              .state
              .sermonState
              .sermonProgress[widget.sermonGeneratedId];

      // Verifica se existe progresso salvo e se o ScrollController está pronto para ser usado
      if (progress != null &&
          progress.progressPercent > 0 &&
          _scrollController.hasClients) {
        // Calcula a posição em pixels para onde devemos rolar
        final scrollPosition = _scrollController.position.maxScrollExtent *
            progress.progressPercent;

        // Pula para a posição salva sem animação
        _scrollController.jumpTo(scrollPosition);

        print(
            "SermonDetail: Pulando para a posição de leitura salva: ${(progress.progressPercent * 100).toStringAsFixed(1)}%");
      }
    });
  }

  Future<void> _loadMainScripture(String reference) async {
    if (!mounted) return;
    setState(() => _isLoadingMainScripture = true);
    try {
      final verses =
          await BiblePageHelper.loadVersesFromReference(reference, "nvi");
      if (mounted) setState(() => _loadedMainScriptureVerses = verses);
    } catch (e) {
      if (mounted)
        setState(() =>
            _loadedMainScriptureVerses = ["Erro ao carregar: $reference"]);
    } finally {
      if (mounted) setState(() => _isLoadingMainScripture = false);
    }
  }

  void _increaseFontSize() {
    if (_currentFontSize < MAX_FONT_SIZE) {
      setState(() => _currentFontSize =
          (_currentFontSize + FONT_STEP).clamp(MIN_FONT_SIZE, MAX_FONT_SIZE));
    }
  }

  void _decreaseFontSize() {
    if (_currentFontSize > MIN_FONT_SIZE) {
      setState(() => _currentFontSize =
          (_currentFontSize - FONT_STEP).clamp(MIN_FONT_SIZE, MAX_FONT_SIZE));
    }
  }

  void _shareSermon() {
    if (_sermonDataFromFirestore != null) {
      final sermon = _sermonDataFromFirestore!;
      final String shareText =
          "Confira este sermão de ${sermon.preacher ?? 'C.H. Spurgeon'}: ${sermon.translatedTitle}\n"
          "Referência Principal: ${sermon.mainScripturePassageAbbreviated ?? 'N/A'}\n"
          "\nLeia no app Septima!";
      Share.share(shareText, subject: "Sermão: ${sermon.translatedTitle}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // O StoreConnector agora envolve todo o Scaffold para que a AppBar também possa reagir às mudanças de estado (ex: favoritos)
    return StoreConnector<AppState, _SermonDetailViewModel>(
      converter: (store) =>
          _SermonDetailViewModel.fromStore(store, widget.sermonGeneratedId),
      distinct: true, // Importante para otimização
      builder: (context, viewModel) {
        // Determina se este sermão específico está favoritado
        final isFavorited =
            viewModel.favoritedSermonIds.contains(widget.sermonGeneratedId);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _sermonDataFromFirestore?.translatedTitle ?? widget.sermonTitle,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            actions: [
              // Botão de Favorito
              IconButton(
                icon: Icon(
                  isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorited
                      ? Colors.amber.shade600
                      : theme.appBarTheme.actionsIconTheme?.color,
                  size: 26,
                ),
                tooltip: isFavorited
                    ? "Remover dos Favoritos"
                    : "Adicionar aos Favoritos",
                onPressed: () {
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                    ToggleSermonFavoriteAction(
                      sermonId: widget.sermonGeneratedId,
                      isFavorite: !isFavorited, // Ação de alternância
                    ),
                  );
                },
              ),

              // Seção de Ações do Sermão (só aparece se os dados estiverem carregados)
              if (_sermonDataFromFirestore != null) ...[
                if (_isGeneratingSummary)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.bolt_outlined),
                    tooltip: "Gerar Resumo com IA",
                    onPressed: () => _handleShowSummary(
                      widget.sermonGeneratedId,
                      _sermonDataFromFirestore!.translatedTitle,
                    ),
                  ),
                // Botão de PDF
                if (_isGeneratingPdf)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                  )
                else if (_existingPdfPath != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.picture_as_pdf,
                        color: theme.colorScheme.primary),
                    tooltip: "Opções do PDF do Sermão",
                    onSelected: (value) {
                      if (value == 'view')
                        OpenFile.open(_existingPdfPath!);
                      else if (value == 'regenerate')
                        _handleGenerateSermonPdf();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'view', child: Text('Ver PDF Salvo')),
                      const PopupMenuItem(
                          value: 'regenerate', child: Text('Gerar Novamente')),
                    ],
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: "Gerar PDF do Sermão",
                    onPressed: _handleGenerateSermonPdf,
                  ),

                // Botão de Áudio
                IconButton(
                    icon: Icon(_getAudioIcon(),
                        size: 28,
                        color: _sermonPlayerState == TtsPlayerState.playing
                            ? theme.colorScheme.primary
                            : theme.appBarTheme.actionsIconTheme?.color),
                    tooltip: _getAudioTooltip(),
                    onPressed: _handleAudioControl),

                // Botão de Compartilhar
                IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: "Compartilhar Sermão",
                    onPressed: _shareSermon),

                // Botão de Fonte
                PopupMenuButton<String>(
                  icon: const Icon(Icons.format_size_outlined),
                  tooltip: "Tamanho da Fonte",
                  onSelected: (value) {
                    if (value == 'increase')
                      _increaseFontSize();
                    else if (value == 'decrease') _decreaseFontSize();
                  },
                  itemBuilder: (context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                        value: 'increase',
                        child: ListTile(
                            leading: Icon(Icons.text_increase),
                            title: Text('Aumentar Fonte'))),
                    const PopupMenuItem(
                        value: 'decrease',
                        child: ListTile(
                            leading: Icon(Icons.text_decrease),
                            title: Text('Diminuir Fonte'))),
                  ],
                ),
              ],
            ],
          ),
          body: _buildBody(theme, viewModel),
        );
      },
    );
  }

  // O método _buildBody agora recebe o ViewModel para passar os dados necessários
  Widget _buildBody(ThemeData theme, _SermonDetailViewModel viewModel) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _sermonDataFromFirestore == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error ?? "Sermão não pôde ser carregado.",
            style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final sermon = _sermonDataFromFirestore!;
    final details = sermon.sermonDetails;
    final preacherName =
        sermon.preacher ?? details?['preacher'] as String? ?? 'C.H. Spurgeon';
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSnippet());

    return SingleChildScrollView(
      controller: _scrollController, // Added controller here
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details != null) ...[
            if (details['number_text'] != null &&
                (details['number_text'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(details['number_text'],
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: _currentFontSize * 0.8)),
              ),
            if (preacherName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text("Pregador: $preacherName",
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: _currentFontSize * 0.9)),
              ),
            if (details['delivery_info'] != null &&
                (details['delivery_info'] as String).isNotEmpty)
              Text(details['delivery_info'],
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: _currentFontSize * 0.8)),
            const SizedBox(height: 12),
          ],
          if (sermon.mainScripturePassageAbbreviated != null &&
              sermon.mainScripturePassageAbbreviated!.isNotEmpty) ...[
            Text(
                "Passagem Principal: ${sermon.mainScripturePassageAbbreviated}",
                style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: _currentFontSize * 0.9)),
            const SizedBox(height: 4),
          ],
          if (_isLoadingMainScripture)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: theme.colorScheme.secondary)),
            )
          else if (_loadedMainScriptureVerses != null &&
              _loadedMainScriptureVerses!.isNotEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _loadedMainScriptureVerses!.map((verseText) {
                    final parts = verseText.split(RegExp(r'\s+'));
                    String verseNumDisplay = "";
                    String textDisplay = verseText;
                    if (parts.isNotEmpty && int.tryParse(parts.first) != null) {
                      verseNumDisplay = "${parts.first} ";
                      textDisplay = parts.sublist(1).join(" ");
                    }
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                height: 1.45,
                                fontSize: _currentFontSize * 0.95),
                            children: <TextSpan>[
                              TextSpan(
                                  text: verseNumDisplay,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              TextSpan(text: textDisplay),
                            ],
                          ),
                        ));
                  }).toList(),
                ),
              ),
            )
          else if (sermon.mainVerseQuoted != null &&
              sermon.mainVerseQuoted!.isNotEmpty)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(sermon.mainVerseQuoted!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                        fontSize: _currentFontSize * 0.95)),
              ),
            ),
          const SizedBox(height: 16),
          Text("Sermão:",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  fontSize: _currentFontSize * 1.1)),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sermon.paragraphsToDisplay.map((paragraph) {
              final key = GlobalKey();
              _paragraphKeys[paragraph] = key;
              return Padding(
                key: key,
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SelectableText.rich(
                  TextSpan(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: _currentFontSize,
                      height: 1.6,
                    ),
                    children: _buildHighlightedParagraph(
                        paragraph, viewModel.highlights, theme),
                  ),
                  contextMenuBuilder: (context, editableTextState) {
                    final List<ContextMenuButtonItem> buttonItems =
                        editableTextState.contextMenuButtonItems;

                    // Adiciona o botão de destacar no início
                    buttonItems.insert(
                      0,
                      ContextMenuButtonItem(
                        label: 'Destacar',
                        onPressed: () {
                          _handleHighlight(context, paragraph,
                              editableTextState, viewModel.isPremium);
                        },
                      ),
                    );

                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: buttonItems,
                    );
                  },
                  textAlign: TextAlign.justify,
                ),
              );
            }).toList(),
          ),
          if (sermon.embeddedScripturesAbbreviated != null &&
              sermon.embeddedScripturesAbbreviated!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text("Outras Referências Citadas:",
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: _currentFontSize * 0.9)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: sermon.embeddedScripturesAbbreviated!.map((ref) {
                return Chip(
                  label: Text(ref,
                      style: TextStyle(fontSize: _currentFontSize * 0.75)),
                  backgroundColor:
                      theme.colorScheme.secondaryContainer.withOpacity(0.7),
                  labelStyle:
                      TextStyle(color: theme.colorScheme.onSecondaryContainer),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
