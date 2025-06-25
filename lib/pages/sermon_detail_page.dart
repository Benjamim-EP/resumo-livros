// lib/pages/sermon_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/services/tts_manager.dart';

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

  const SermonDetailPage({
    super.key,
    required this.sermonGeneratedId,
    required this.sermonTitle,
  });

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
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

  @override
  void initState() {
    super.initState();
    _loadSermonDataFromFirestore();
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
    if (!mounted) return;
    final newPlayerState = _ttsManager.playerState.value;
    if (_sermonPlayerState != newPlayerState) {
      setState(() {
        _sermonPlayerState = newPlayerState;
      });
    }
  }

  /// Lida com os cliques no botão de áudio (play, pause, resume).
  void _handleAudioControl() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.stopped:
        // Se está parado, inicia uma nova leitura.
        _startSermonPlayback();
        break;
      case TtsPlayerState.playing:
        // Se está tocando, pausa.
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        // Se está pausado, continua.
        _ttsManager.resume(); // <<< USA O MÉTODO RESUME CORRETO
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

  IconData _getAudioIcon() {
    // O ícone para pausado e parado agora é o mesmo (play).
    if (_sermonPlayerState == TtsPlayerState.playing) {
      return Icons.pause_circle_outline;
    }
    return Icons.play_circle_outline;
  }

  String _getAudioTooltip() {
    switch (_sermonPlayerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar Leitura"; // <<< CORRIGIDO
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
              icon: Icon(
                _getAudioIcon(),
                size: 26, // Tamanho um pouco maior para destaque
                color: _sermonPlayerState == TtsPlayerState.playing
                    ? theme.colorScheme.secondary
                    : theme.appBarTheme.actionsIconTheme?.color,
              ),
              tooltip: _getAudioTooltip(),
              onPressed: _handleAudioControl,
            ),
          if (_sermonDataFromFirestore != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: "Compartilhar Sermão",
              onPressed: _shareSermon,
            ),
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

    return SingleChildScrollView(
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
              final spacedParagraph = "$paragraph\n";
              return MarkdownBody(
                data: spacedParagraph,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge
                      ?.copyWith(fontSize: _currentFontSize, height: 1.5),
                  blockquoteDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                    border: Border(
                        left: BorderSide(
                            color: theme.colorScheme.secondary, width: 4)),
                  ),
                  blockquotePadding: const EdgeInsets.all(8),
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
