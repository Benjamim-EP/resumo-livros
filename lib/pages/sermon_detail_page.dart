// lib/pages/sermon_detail_page.dart
import 'dart:convert'; // Necessário se você for parsear JSON internamente (não é o caso aqui)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle, mas não usaremos para carregar sermão aqui
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart'; // Para funcionalidade de compartilhar
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // Importa o serviço

// Modelo de dados para o sermão (conforme definido anteriormente)
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
  // Adicione o campo preacher se ele estiver no nível raiz e não apenas em sermon_details
  final String? preacher; // Exemplo, ajuste conforme sua estrutura no Firestore

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
    this.preacher, // Exemplo
  });

  factory Sermon.fromJson(Map<String, dynamic> json, String generatedId) {
    // Adicionado generatedId
    return Sermon(
      generatedSermonId: generatedId, // Usa o ID passado
      idOriginalProblematico: json['id_original_problematico'] as String?,
      titleOriginal: json['title_original'] as String? ??
          json['title'] as String? ??
          'Título Original Indisponível',
      translatedTitle:
          json['translated_title'] as String? ?? 'Título Indisponível',
      mainScripturePassageOriginal: json['main_scripture_passage_original']
          as String?, // Corrigido de 'main_scripture_passage'
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
          json['sermon_details']?['preacher']
              as String?, // Prioriza campo raiz, depois details
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
  final String sermonTitle; // Título para exibir no AppBar enquanto carrega

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

  static const double MIN_FONT_SIZE = 12.0;
  static const double MAX_FONT_SIZE = 28.0; // Aumentado o máximo
  static const double FONT_STEP = 1.0;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadSermonDataFromFirestore();
  }

  Future<void> _loadSermonDataFromFirestore() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sermonMap = await _firestoreService
          .getSermonDetailsFromFirestore(widget.sermonGeneratedId);

      if (mounted) {
        if (sermonMap != null) {
          setState(() {
            _sermonDataFromFirestore =
                Sermon.fromJson(sermonMap, widget.sermonGeneratedId);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = "Sermão não encontrado (ID: ${widget.sermonGeneratedId}).";
            _isLoading = false;
          });
        }
      }
    } catch (e, s) {
      print("Erro ao carregar dados do sermão do Firestore: $e");
      print("Stack trace: $s");
      if (mounted) {
        setState(() {
          _error = "Falha ao carregar o sermão. Verifique sua conexão.";
          _isLoading = false;
        });
      }
    }
  }

  void _increaseFontSize() {
    if (_currentFontSize < MAX_FONT_SIZE) {
      setState(() {
        _currentFontSize =
            (_currentFontSize + FONT_STEP).clamp(MIN_FONT_SIZE, MAX_FONT_SIZE);
      });
    }
  }

  void _decreaseFontSize() {
    if (_currentFontSize > MIN_FONT_SIZE) {
      setState(() {
        _currentFontSize =
            (_currentFontSize - FONT_STEP).clamp(MIN_FONT_SIZE, MAX_FONT_SIZE);
      });
    }
  }

  void _shareSermon() {
    if (_sermonDataFromFirestore != null) {
      final sermon = _sermonDataFromFirestore!;
      final String shareText =
          "Confira este sermão de ${sermon.preacher ?? 'C.H. Spurgeon'}: ${sermon.translatedTitle}\n"
          "Referência Principal: ${sermon.mainScripturePassageAbbreviated ?? 'N/A'}\n"
          // Adicione um link para o app ou para o sermão online, se aplicável
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
              if (value == 'increase') {
                _increaseFontSize();
              } else if (value == 'decrease') {
                _decreaseFontSize();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'increase',
                child: ListTile(
                    leading: Icon(Icons.text_increase),
                    title: Text('Aumentar Fonte')),
              ),
              const PopupMenuItem<String>(
                value: 'decrease',
                child: ListTile(
                    leading: Icon(Icons.text_decrease),
                    title: Text('Diminuir Fonte')),
              ),
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
    final details = sermon
        .sermonDetails; // Ex: {'number_text': '(No. 1)', 'preacher': 'REV. C.H. SPURGEON', ...}
    final preacherName =
        sermon.preacher ?? details?['preacher'] as String? ?? 'C.H. Spurgeon';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título (opcional, já que está no AppBar)
          // Text(
          //   sermon.translatedTitle,
          //   style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: _currentFontSize * 1.3),
          // ),
          // const SizedBox(height: 8),

          if (details != null) ...[
            if (details['number_text'] != null &&
                (details['number_text'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  details['number_text'],
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: _currentFontSize * 0.8),
                ),
              ),
            // O nome do pregador agora pode vir do campo 'preacher' no nível raiz ou de 'sermon_details'
            if (preacherName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Text(
                  "Pregador: $preacherName",
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: _currentFontSize * 0.9),
                ),
              ),
            if (details['delivery_info'] != null &&
                (details['delivery_info'] as String).isNotEmpty)
              Text(
                details['delivery_info'],
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: _currentFontSize * 0.8),
              ),
            const SizedBox(height: 12),
          ],

          if (sermon.mainScripturePassageAbbreviated != null &&
              sermon.mainScripturePassageAbbreviated!.isNotEmpty) ...[
            Text(
              "Passagem Principal: ${sermon.mainScripturePassageAbbreviated}",
              style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.secondary, // Destaque
                  fontWeight: FontWeight.bold,
                  fontSize: _currentFontSize * 0.9),
            ),
            const SizedBox(height: 4),
          ],

          if (sermon.mainVerseQuoted != null &&
              sermon.mainVerseQuoted!.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withOpacity(0.7), // Cor sutil de fundo
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  sermon.mainVerseQuoted!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      fontSize: _currentFontSize *
                          0.95 // Um pouco menor que o texto principal
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text(
            "Sermão:", // Ou deixe vazio se o título no AppBar for suficiente
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                fontSize: _currentFontSize * 1.1 // Um pouco maior
                ),
          ),
          const SizedBox(height: 8),

          // Usando MarkdownBody para renderizar cada parágrafo
          // O MarkdownBody já é scrollable se seu conteúdo exceder, mas está dentro de um SingleChildScrollView
          Column(
            // Usando Column para evitar problemas de scroll aninhado se MarkdownBody tivesse seu próprio scroll
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sermon.paragraphsToDisplay.map((paragraph) {
              final spacedParagraph =
                  "$paragraph\n"; // Adiciona espaço extra entre parágrafos Markdown
              return MarkdownBody(
                data: spacedParagraph,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: _currentFontSize,
                    height: 1.5,
                  ),
                  // Customizar outros estilos do Markdown se necessário
                  // Ex: strong, em, blockquote, etc.
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
            Text(
              "Outras Referências Citadas:",
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: _currentFontSize * 0.9),
            ),
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
