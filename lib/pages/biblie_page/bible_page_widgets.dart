// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/highlight_color_picker_modal.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/note_editor_modal.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class BiblePageWidgets {
  static Widget buildTranslationButton({
    required String translationKey,
    required String translationLabel,
    required String selectedTranslation,
    required VoidCallback onPressed,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedTranslation == translationKey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.cardColor.withOpacity(0.7),
          foregroundColor: isSelected
              ? theme.colorScheme.onPrimary
              : theme.textTheme.bodyLarge?.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(80, 40), // Ajuste conforme necessário
        ),
        child: Text(
          translationLabel,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // MODIFICAÇÃO AQUI: Adicionar os parâmetros que faltavam
  static void showTranslationSelection({
    required BuildContext context,
    required String selectedTranslation,
    required Function(String) onTranslationSelected,
    required String? currentSelectedBookAbbrev, // PARÂMETRO ADICIONADO
    required Map<String, dynamic>? booksMap, // PARÂMETRO ADICIONADO
  }) {
    final theme = Theme.of(context);
    bool showHebrewOption = false;

    if (currentSelectedBookAbbrev != null &&
        booksMap != null &&
        booksMap.containsKey(currentSelectedBookAbbrev)) {
      final bookData =
          booksMap[currentSelectedBookAbbrev] as Map<String, dynamic>?;
      // Certifique-se que seu abbrev_map.json tem a chave 'testament'
      if (bookData != null && bookData['testament'] == 'Antigo') {
        showHebrewOption = true;
      }
    }

    List<Widget> translationButtons = [
      buildTranslationButton(
        context: context,
        translationKey: 'nvi',
        translationLabel: 'NVI',
        selectedTranslation: selectedTranslation,
        onPressed: () {
          onTranslationSelected('nvi');
          Navigator.pop(context);
        },
      ),
      buildTranslationButton(
        context: context,
        translationKey: 'aa',
        translationLabel: 'AA',
        selectedTranslation: selectedTranslation,
        onPressed: () {
          onTranslationSelected('aa');
          Navigator.pop(context);
        },
      ),
      buildTranslationButton(
        context: context,
        translationKey: 'acf',
        translationLabel: 'ACF',
        selectedTranslation: selectedTranslation,
        onPressed: () {
          onTranslationSelected('acf');
          Navigator.pop(context);
        },
      ),
    ];

    if (showHebrewOption) {
      translationButtons.add(
        buildTranslationButton(
          context: context,
          translationKey: 'hebrew_original',
          translationLabel: 'Hebraico (Orig.)',
          selectedTranslation: selectedTranslation,
          onPressed: () {
            onTranslationSelected('hebrew_original');
            Navigator.pop(context);
          },
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Escolha a Tradução",
                style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: translationButtons,
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  static List<TextSpan> _formatRegularVerseText(
      String verseText, ThemeData theme) {
    final List<TextSpan> spans = [];
    final RegExp regex =
        RegExp(r'(?<![\w])((\d+\.)|(\(\d+\)))(?!\w)\s*', multiLine: true);
    int currentPosition = 0;
    final baseStyle = TextStyle(
        color: theme.textTheme.bodyLarge?.color, fontSize: 16, height: 1.5);
    final numberStyle = TextStyle(
        fontWeight: FontWeight.bold,
        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
        fontSize: 16,
        height: 1.5);

    for (final Match match in regex.allMatches(verseText)) {
      if (match.start > currentPosition) {
        spans.add(TextSpan(
            text: verseText.substring(currentPosition, match.start),
            style: baseStyle));
      }
      spans.add(TextSpan(text: match.group(1)!, style: numberStyle));
      if (match.group(0)!.endsWith(' ')) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }
      currentPosition = match.end;
    }
    if (currentPosition < verseText.length) {
      spans.add(TextSpan(
          text: verseText.substring(currentPosition), style: baseStyle));
    }
    if (spans.isEmpty) return [TextSpan(text: verseText, style: baseStyle)];
    return spans;
  }

  static Widget buildVerseItem({
    required int verseNumber,
    required dynamic verseData,
    required String? selectedBook,
    required int? selectedChapter,
    required BuildContext context,
    required Map<String, String> userHighlights,
    required Map<String, String> userNotes,
    bool isHebrew = false,
  }) {
    final theme = Theme.of(context);
    final verseId = "${selectedBook}_${selectedChapter}_$verseNumber";
    final String? currentHighlightColorHex = userHighlights[verseId];
    final bool hasNote = userNotes.containsKey(verseId);
    final backgroundColor = currentHighlightColorHex != null
        ? Color(int.parse(currentHighlightColorHex.replaceFirst('#', '0xff')))
            .withOpacity(0.30)
        : Colors.transparent;

    Widget verseContentWidget;
    String verseTextForModal = "";
    List<Map<String, String>> hebrewWordsDataForLexicon = [];

    if (isHebrew && verseData is List<Map<String, String>>) {
      hebrewWordsDataForLexicon = verseData;
      List<TextSpan> hebrewSpans = [];
      for (var wordData in verseData) {
        final text = wordData['text'] ?? '';
        final cleanText = text.replaceAll(RegExp(r'[/\\]'), '');
        verseTextForModal += "$cleanText ";
        hebrewSpans.add(
          TextSpan(
            text: '$text ',
            style: TextStyle(
              fontSize: 20,
              color: theme.textTheme.bodyLarge?.color,
              fontFamily: 'NotoSansHebrew',
            ),
          ),
        );
      }
      verseContentWidget = RichText(
        text: TextSpan(children: hebrewSpans),
        textDirection: TextDirection.rtl,
      );
    } else if (verseData is String) {
      verseTextForModal = verseData;
      verseContentWidget = RichText(
        text: TextSpan(
          children: _formatRegularVerseText(verseData, theme),
        ),
      );
    } else {
      verseTextForModal = "[Formato de verso inválido]";
      verseContentWidget = Text(verseTextForModal,
          style: TextStyle(color: theme.colorScheme.error));
    }

    return GestureDetector(
      onLongPress: () {
        _showVerseOptionsModal(
          context,
          verseId,
          currentHighlightColorHex,
          userNotes[verseId],
          selectedBook!,
          selectedChapter!,
          verseNumber,
          verseTextForModal.trim(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$verseNumber ',
              style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color,
                  fontWeight: FontWeight.bold),
            ),
            Expanded(child: verseContentWidget),
            if (hasNote)
              Padding(
                padding: const EdgeInsets.only(left: 5.0, right: 2.0, top: 2.0),
                child: Icon(Icons.note_alt_rounded,
                    color: theme.colorScheme.secondary.withOpacity(0.7),
                    size: 16),
              ),
            if (isHebrew && hebrewWordsDataForLexicon.isNotEmpty)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
                icon: Icon(Icons.translate_outlined,
                    color: theme.colorScheme.tertiary),
                tooltip: "Léxico do Versículo",
                onPressed: () {
                  _showVerseLexiconModal(context, selectedBook!,
                      selectedChapter!, verseNumber, hebrewWordsDataForLexicon);
                },
              ),
          ],
        ),
      ),
    );
  }

  static void _showVerseOptionsModal(
      BuildContext context,
      String verseId,
      String? currentHighlightColor,
      String? currentNote,
      String bookAbbrev,
      int chapter,
      int verseNum,
      String verseText) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        final store = StoreProvider.of<AppState>(modalContext);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Opções para: $bookAbbrev $chapter:$verseNum",
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      verseText,
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                          fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Divider(color: theme.dividerColor, height: 25),
              ListTile(
                leading: Icon(Icons.format_paint_outlined,
                    color: currentHighlightColor != null
                        ? Color(int.parse(
                            currentHighlightColor.replaceFirst('#', '0xff')))
                        : theme.iconTheme.color?.withOpacity(0.7)),
                title: Text(
                    currentHighlightColor != null
                        ? "Mudar/Remover Destaque"
                        : "Destacar Versículo",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    builder: (_) => HighlightColorPickerModal(
                        initialColor: currentHighlightColor,
                        onColorSelected: (selectedColor) {
                          store.dispatch(ToggleHighlightAction(verseId,
                              colorHex: selectedColor));
                        },
                        onRemoveHighlight: () {
                          store.dispatch(ToggleHighlightAction(verseId));
                        }),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                    currentNote != null
                        ? Icons.edit_note_outlined
                        : Icons.note_add_outlined,
                    color: theme.iconTheme.color?.withOpacity(0.7)),
                title: Text(
                    currentNote != null ? "Editar Nota" : "Adicionar Nota",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    builder: (_) => NoteEditorModal(
                      verseId: verseId,
                      initialText: currentNote,
                      bookReference: "$bookAbbrev $chapter:$verseNum",
                      verseTextSample: verseText,
                    ),
                  );
                },
              ),
              if (currentNote != null)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.7)),
                  title: Text("Remover Nota",
                      style: TextStyle(color: theme.colorScheme.error)),
                  onTap: () {
                    store.dispatch(DeleteNoteAction(verseId));
                    Navigator.pop(modalContext);
                    if (context.mounted) {
                      // Adicionado context.mounted
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Nota removida.'),
                            duration: Duration(seconds: 2)),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(Icons.bookmark_add_outlined,
                    color: theme.iconTheme.color?.withOpacity(0.7)),
                title: Text("Salvar em Coleção",
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                onTap: () {
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    builder: (dContext) => SaveVerseDialog(
                      // dContext é o BuildContext do showDialog
                      bookAbbrev: bookAbbrev,
                      chapter: chapter,
                      verseNumber: verseNum,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  static void _showVerseLexiconModal(
    BuildContext context,
    String bookAbbrev,
    int chapter,
    int verseNum,
    List<Map<String, String>> hebrewWords,
  ) async {
    final theme = Theme.of(context);
    final lexicon = await BiblePageHelper.getStrongsLexicon();
    if (lexicon == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Léxico de Strong não carregado.")));
      return;
    }
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.dialogBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Léxico para: $bookAbbrev $chapter:$verseNum",
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Divider(color: theme.dividerColor, height: 1),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: hebrewWords.length,
                        padding: const EdgeInsets.all(16.0),
                        separatorBuilder: (context, index) => Divider(
                            color: theme.dividerColor.withOpacity(0.3),
                            height: 20),
                        itemBuilder: (context, index) {
                          final wordData = hebrewWords[index];
                          final hebrewText = wordData['text'] ?? '';
                          final strongNumberWithPrefix =
                              wordData['strong'] ?? '';
                          final morph = wordData['morph'] ?? 'N/A';
                          final String strongNumber = strongNumberWithPrefix
                              .replaceAll(RegExp(r'^[Hc]/'), '');
                          final lexiconEntry =
                              lexicon?[strongNumber] as Map<String, dynamic>?;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hebrewText,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                    fontFamily: 'NotoSansHebrew',
                                    fontSize: 22,
                                    color: theme.colorScheme.secondary),
                              ),
                              if (lexiconEntry != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                    "Strong: H$strongNumber (${lexiconEntry['transliteration'] ?? 'N/A'})",
                                    style: TextStyle(
                                        color: theme.colorScheme.tertiary,
                                        fontSize: 14)),
                                Text("Morfologia: $morph",
                                    style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 13)),
                                const SizedBox(height: 6),
                                Text("Definições (PT):",
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                ...((lexiconEntry['definitions_pt']
                                                as List<dynamic>?)
                                            ?.cast<String>() ??
                                        ['N/A'])
                                    .map((def) => Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, top: 2.0),
                                          child: Text("• $def",
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodyMedium?.color,
                                                  fontSize: 13)),
                                        )),
                              ] else if (strongNumber.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text("Strong: $strongNumberWithPrefix",
                                    style: TextStyle(
                                        color: theme.colorScheme.tertiary,
                                        fontSize: 14)),
                                Text("Morfologia: $morph",
                                    style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 13)),
                                Text("Definição de Strong não encontrada.",
                                    style: TextStyle(
                                        color: theme.colorScheme.error
                                            .withOpacity(0.8),
                                        fontSize: 13)),
                              ] else if (morph != 'N/A' &&
                                  morph.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text("Morfologia: $morph",
                                    style: TextStyle(
                                        color: theme.textTheme.bodySmall?.color,
                                        fontSize: 13)),
                              ]
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            });
      },
    );
  }
}
