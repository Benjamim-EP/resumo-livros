// lib/pages/library_page/study_guide_page.dart

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/utils/text_span_utils.dart';

class MarkdownSection {
  final String title;
  final String content;
  MarkdownSection({required this.title, required this.content});
}

class StudyGuidePage extends StatefulWidget {
  final String title;
  final String contentPath;
  final String guideId;

  const StudyGuidePage({
    super.key,
    required this.title,
    required this.contentPath,
    required this.guideId,
  });

  @override
  State<StudyGuidePage> createState() => _StudyGuidePageState();
}

class _StudyGuidePageState extends State<StudyGuidePage> {
  late Future<List<MarkdownSection>> _sectionsFuture;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _sectionsFuture = _loadAndParseMarkdown();
    _scrollController.addListener(_onScroll);
  }

  Future<List<MarkdownSection>> _loadAndParseMarkdown() async {
    final markdownData = await rootBundle.loadString(widget.contentPath);
    final List<MarkdownSection> sections = [];
    final RegExp titleRegex = RegExp(r'^##\s+(.*)', multiLine: true);
    final matches = titleRegex.allMatches(markdownData);

    if (matches.isEmpty) {
      return [
        MarkdownSection(
            title: "Conteúdo Principal", content: markdownData.trim())
      ];
    }

    int startIndex = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final title = match.group(1)!.trim();
      final contentStart = match.end;
      final contentEnd = (i + 1 < matches.length)
          ? matches.elementAt(i + 1).start
          : markdownData.length;
      final content = markdownData.substring(contentStart, contentEnd).trim();
      sections.add(MarkdownSection(title: title, content: content));
    }
    return sections;
  }

  void _onScroll() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), _saveProgress);
  }

  void _saveProgress() {
    if (!mounted ||
        !_scrollController.hasClients ||
        _scrollController.position.maxScrollExtent <= 0) return;
    final double progress = (_scrollController.position.pixels /
            _scrollController.position.maxScrollExtent)
        .clamp(0.0, 1.0);
    StoreProvider.of<AppState>(context, listen: false).dispatch(
      UpdateSermonProgressAction(
          sermonId: widget.guideId, progressPercentage: progress),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Widget> _buildWidgetsFromMarkdown(
      String markdown, ThemeData theme, BuildContext context) {
    final List<Widget> widgets = [];
    final lines = markdown.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8.0));
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                children: _buildTextSpansForLine(line, theme, context),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // >>> INÍCIO DA CORREÇÃO PRINCIPAL (AGORA COM NEGIRTO) <<<
  List<TextSpan> _buildTextSpansForLine(
      String line, ThemeData theme, BuildContext context) {
    final List<TextSpan> spans = [];
    // Regex que captura EITHER um link customizado (grupo 1) OU um texto em negrito (grupo 2, com o conteúdo no grupo 3)
    final RegExp combinedRegex = RegExp(
        r'(\b[a-z1-3]+_c\d+_v\d+(?:-\d+)?\b)|(\*\*(.*?)\*\*)',
        caseSensitive: false);

    int currentPosition = 0;

    for (final Match match in combinedRegex.allMatches(line)) {
      // Adiciona o texto normal que vem ANTES do padrão encontrado
      if (match.start > currentPosition) {
        spans.add(TextSpan(text: line.substring(currentPosition, match.start)));
      }

      final String? verseLinkMatch = match.group(1);
      final String? boldContentMatch = match.group(3); // Conteúdo dentro dos **

      if (verseLinkMatch != null) {
        // Se encontrou um link de versículo
        final String customId = verseLinkMatch;
        final parts = customId.split('_');
        final bookAbbrev = parts.length > 0 ? parts[0] : '';
        final chapter = parts.length > 1 ? parts[1].replaceAll('c', '') : '';
        final verses = parts.length > 2
            ? parts[2].replaceAll('v', '').replaceAll('-', '-')
            : '';
        final bookName = TextSpanUtils.booksMap?[bookAbbrev]?['nome'] ??
            bookAbbrev.toUpperCase();
        final displayReference = "$bookName $chapter:$verses";

        spans.add(
          TextSpan(
            text: displayReference,
            style: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                TextSpanUtils.showVersePopup(context, displayReference);
              },
          ),
        );
      } else if (boldContentMatch != null) {
        // Se encontrou um texto em negrito
        spans.add(
          TextSpan(
            text: boldContentMatch,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }

      currentPosition = match.end;
    }

    // Adiciona o restante do texto da linha que não correspondeu a nenhum padrão
    if (currentPosition < line.length) {
      spans.add(TextSpan(text: line.substring(currentPosition)));
    }

    return spans.isEmpty ? [TextSpan(text: line)] : spans;
  }
  // >>> FIM DA CORREÇÃO PRINCIPAL <<<

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<MarkdownSection>>(
        future: _sectionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text("Não foi possível carregar o conteúdo."));
          }
          final sections = snapshot.data!;
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8.0),
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  key: PageStorageKey(section.title),
                  initiallyExpanded: index == 0,
                  title: Text(
                    section.title,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    ..._buildWidgetsFromMarkdown(
                        section.content, theme, context),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
