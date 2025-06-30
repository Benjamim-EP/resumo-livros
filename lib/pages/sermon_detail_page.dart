// lib/pages/sermon_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:septima_biblia/services/tts_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:redux/redux.dart';

// Modelo de dados para o sermão
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
  final String? snippetToScrollTo; // <<< NOVO PARÂMETRO OPCIONAL

  const SermonDetailPage({
    super.key,
    required this.sermonGeneratedId,
    required this.sermonTitle,
    this.snippetToScrollTo, // <<< ADICIONADO AO CONSTRUTOR
  });

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
}

class _SermonViewModel {
  final List<Map<String, dynamic>> highlights;
  _SermonViewModel({required this.highlights});

  static _SermonViewModel fromStore(Store<AppState> store, String sermonId) {
    // Filtra apenas os destaques que pertencem a este sermão específico
    final sermonHighlights = store.state.userState.userCommentHighlights
        .where((h) => h['sourceId'] == sermonId)
        .toList();
    return _SermonViewModel(highlights: sermonHighlights);
  }
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

  // O controller foi REMOVIDO pois não é necessário.
  void _scrollToSnippet() {
    if (widget.snippetToScrollTo == null) return;

    // Procura a chave do parágrafo que contém o snippet
    final keyEntry = _paragraphKeys.entries.firstWhere(
      (entry) => entry.key.contains(widget.snippetToScrollTo!),
      orElse: () => MapEntry('', GlobalKey()),
    );

    if (keyEntry.value.currentContext != null) {
      // Espera um pouco para a UI renderizar antes de rolar
      Future.delayed(const Duration(milliseconds: 300), () {
        Scrollable.ensureVisible(
          keyEntry.value.currentContext!,
          duration: const Duration(milliseconds: 500),
          alignment: 0.3, // Centraliza o destaque a 30% do topo da tela
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSermonDataFromFirestore().then((_) {
      // Chama a função de scroll DEPOIS que os dados do sermão forem carregados
      if (mounted) {
        _scrollToSnippet();
      }
    });
    _ttsManager.playerState.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    interstitialManager.tryShowInterstitial(
        fromScreen: "SermonDetailPage_Dispose");
    super.dispose();
  }

  void _onTtsStateChanged() {
    if (mounted) {
      if (_sermonPlayerState != _ttsManager.playerState.value) {
        setState(() => _sermonPlayerState = _ttsManager.playerState.value);
      }
    }
  }

  void _handleHighlight(BuildContext context, String fullParagraph,
      EditableTextState editableTextState) {
    final TextSelection selection =
        editableTextState.textEditingValue.selection;
    if (selection.isCollapsed) return;

    final selectedSnippet =
        fullParagraph.substring(selection.start, selection.end);
    _showHighlightEditor(context, selectedSnippet, fullParagraph);
  }

  Future<void> _showHighlightEditor(
      BuildContext context, String snippet, String fullParagraph) async {
    final store = StoreProvider.of<AppState>(context, listen: false);

    final result = await showDialog<HighlightResult?>(
      context: context,
      builder: (_) => const HighlightEditorDialog(
        initialColor: "#FFA07A", // Cor padrão para destaques de literatura
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

  // >>> NOVA FUNÇÃO HELPER PARA CONSTRUIR O TEXTO COM DESTAQUES <<<
  List<TextSpan> _buildHighlightedParagraph(String paragraph,
      List<Map<String, dynamic>> highlights, ThemeData theme) {
    List<TextSpan> spans = [];
    int lastEnd = 0;

    // Encontra todos os trechos de destaque que estão neste parágrafo
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

    // Ordena os trechos para evitar sobreposição incorreta
    snippetsInParagraph.sort((a, b) => a['start'].compareTo(b['start']));

    // Constrói os TextSpans
    for (var snippetInfo in snippetsInParagraph) {
      // Adiciona o texto normal antes do destaque
      if (snippetInfo['start'] > lastEnd) {
        spans.add(
            TextSpan(text: paragraph.substring(lastEnd, snippetInfo['start'])));
      }

      // Adiciona o texto destacado com cor de fundo
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

    // Adiciona o resto do texto após o último destaque
    if (lastEnd < paragraph.length) {
      spans.add(TextSpan(text: paragraph.substring(lastEnd)));
    }

    // Se nenhum destaque foi encontrado, retorna o parágrafo inteiro como um único TextSpan
    return spans.isEmpty ? [TextSpan(text: paragraph)] : spans;
  }

  /// Lida com os cliques no botão de áudio (play, pause, resume).
  void _handleAudioControl() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.stopped:
        // Se está parado, inicia uma nova leitura do começo.
        _startSermonPlayback();
        break;
      case TtsPlayerState.playing:
        // Se está tocando, pausa.
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        // Se está pausado, REINICIA a fala do item atual.
        _ttsManager.restartCurrentItem();
        break;
    }
  }

  /// Constrói a fila de áudio e inicia a reprodução do sermão.
  void _startSermonPlayback() async {
    if (_sermonDataFromFirestore == null) return;

    final sermon = _sermonDataFromFirestore!;
    List<TtsQueueItem> queue = [];
    final sermonId =
        sermon.generatedSermonId ?? "sermon_${sermon.translatedTitle.hashCode}";

    // 1. Título
    queue.add(TtsQueueItem(
        sectionId: sermonId,
        textToSpeak: "Sermão: ${sermon.translatedTitle}."));

    // 2. Passagem Principal
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

    // 3. Texto dos Versículos (CORRIGIDO)
    if (_loadedMainScriptureVerses != null &&
        _loadedMainScriptureVerses!.isNotEmpty) {
      // >>> INÍCIO DA CORREÇÃO <<<
      final versesTextOnly = _loadedMainScriptureVerses!.map((verseWithNumber) {
        // Lógica robusta para remover o número inicial.
        // Encontra o primeiro espaço. Todo o resto é o texto do versículo.
        final firstSpaceIndex = verseWithNumber.indexOf(' ');
        if (firstSpaceIndex != -1) {
          return verseWithNumber.substring(firstSpaceIndex + 1);
        }
        // Se não houver espaço (improvável, mas seguro), retorna a string original.
        return verseWithNumber;
      }).join(
          " "); // Junta todos os versículos com um espaço para uma leitura fluida.
      // >>> FIM DA CORREÇÃO <<<

      if (versesTextOnly.trim().isNotEmpty) {
        queue.add(
            TtsQueueItem(sectionId: sermonId, textToSpeak: versesTextOnly));
      }
    }

    // 4. Parágrafos do Sermão
    for (var paragraph in sermon.paragraphsToDisplay) {
      if (paragraph.trim().isNotEmpty) {
        queue.add(TtsQueueItem(sectionId: sermonId, textToSpeak: paragraph));
      }
    }

    // A leitura do sermão é sempre contínua.
    //_ttsManager.isContinuousPlayEnabled = true; // Removido, pois é o padrão agora.
    _ttsManager.speak(queue, sermonId);
  }

  // O ícone para "paused" agora será um ícone de "restart" ou "replay" para ser mais claro.
  IconData _getAudioIcon() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.playing:
        return Icons.pause_circle_outline;
      case TtsPlayerState.paused:
        return Icons.play_circle_outline; // Ícone de Replay
      case TtsPlayerState.stopped:
        return Icons.play_circle_outline;
    }
  }

  String _getAudioTooltip() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar do Início do Parágrafo"; // Tooltip mais claro
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
        setState(() => _sermonDataFromFirestore = sermonData);
        if (sermonData.mainScripturePassageAbbreviated != null &&
            sermonData.mainScripturePassageAbbreviated!.isNotEmpty) {
          await _loadMainScripture(sermonData.mainScripturePassageAbbreviated!);
        }
      } else if (mounted) {
        setState(() => _error =
            "Sermão não encontrado (ID: ${widget.sermonGeneratedId}).");
      }
    } catch (e, s) {
      print("Erro ao carregar dados do sermão: $e\n$s");
      if (mounted) setState(() => _error = "Falha ao carregar o sermão.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMainScripture(String reference) async {
    if (!mounted) return;
    setState(() => _isLoadingMainScripture = true);
    try {
      final verses =
          await BiblePageHelper.loadVersesFromReference(reference, "nvi");
      if (mounted) setState(() => _loadedMainScriptureVerses = verses);
    } catch (e) {
      print("Erro ao carregar escritura principal: $e");
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
            _sermonDataFromFirestore?.translatedTitle ?? widget.sermonTitle,
            overflow: TextOverflow.ellipsis),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
                icon: Icon(_getAudioIcon(),
                    size: 26,
                    color: _sermonPlayerState == TtsPlayerState.playing
                        ? theme.colorScheme.primary
                        : theme.appBarTheme.actionsIconTheme?.color),
                tooltip: _getAudioTooltip(),
                onPressed: _handleAudioControl),
          if (_sermonDataFromFirestore != null)
            IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: "Compartilhar Sermão",
                onPressed: _shareSermon),
          PopupMenuButton<String>(
            icon: const Icon(Icons.format_size_outlined),
            tooltip: "Tamanho da Fonte",
            onSelected: (value) {
              if (value == 'increase')
                _increaseFontSize();
              else if (value == 'decrease') _decreaseFontSize();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                  value: 'increase',
                  child: ListTile(
                      leading: Icon(Icons.text_increase),
                      title: Text('Aumentar Fonte'))),
              const PopupMenuItem<String>(
                  value: 'decrease',
                  child: ListTile(
                      leading: Icon(Icons.text_decrease),
                      title: Text('Diminuir Fonte'))),
            ],
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _sermonDataFromFirestore == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error ?? "Sermão não pôde ser carregado.",
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
              textAlign: TextAlign.center),
        ),
      );
    }

    final sermon = _sermonDataFromFirestore!;
    final details = sermon.sermonDetails;
    final preacherName =
        sermon.preacher ?? details?['preacher'] as String? ?? 'C.H. Spurgeon';
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSnippet());
    // O corpo agora é envolvido por um StoreConnector para obter os destaques
    return StoreConnector<AppState, _SermonViewModel>(
      converter: (store) =>
          _SermonViewModel.fromStore(store, widget.sermonGeneratedId),
      builder: (context, viewModel) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seção de Detalhes do Sermão (Número, Pregador, Data)
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

              // Seção da Passagem Bíblica Principal
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
                          strokeWidth: 2.5,
                          color: theme.colorScheme.secondary)),
                )
              else if (_loadedMainScriptureVerses != null &&
                  _loadedMainScriptureVerses!.isNotEmpty)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.7),
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
                        if (parts.isNotEmpty &&
                            int.tryParse(parts.first) != null) {
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
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.7),
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

              // Seção dos Parágrafos do Sermão com Destaques Visuais
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sermon.paragraphsToDisplay.map((paragraph) {
                  final key = GlobalKey();
                  _paragraphKeys[paragraph] = key;
                  return Padding(
                    key: key,
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SelectableText.rich(
                      // Usando .rich para aceitar TextSpan
                      TextSpan(
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: _currentFontSize,
                          height: 1.6,
                        ),
                        // A função helper constrói os spans com os destaques
                        children: _buildHighlightedParagraph(
                            paragraph, viewModel.highlights, theme),
                      ),
                      contextMenuBuilder: (context, editableTextState) {
                        final List<ContextMenuButtonItem> buttonItems =
                            editableTextState.contextMenuButtonItems;

                        if (!editableTextState
                            .textEditingValue.selection.isCollapsed) {
                          buttonItems.insert(
                            0,
                            ContextMenuButtonItem(
                              label: 'Destacar',
                              onPressed: () {
                                _handleHighlight(
                                    context, paragraph, editableTextState);
                                editableTextState.hideToolbar();
                              },
                            ),
                          );
                        }

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

              // Seção de Outras Referências
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
                      labelStyle: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
