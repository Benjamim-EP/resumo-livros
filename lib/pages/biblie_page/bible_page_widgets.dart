// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Para acessar o store nos modais
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart'; // Para salvar versículo
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/highlight_color_picker_modal.dart'; // Modal de cores
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/note_editor_modal.dart'; // Modal de notas
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart'; // Para o Léxico

class BiblePageWidgets {
  /// Botão para selecionar uma tradução específica.
  static Widget buildTranslationButton({
    required String translationKey,
    required String translationLabel,
    required String selectedTranslation,
    required VoidCallback onPressed,
  }) {
    final isSelected = selectedTranslation == translationKey;
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 4.0, horizontal: 4.0), // Espaçamento horizontal também
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? const Color(0xFFCDE7BE) : const Color(0xFF272828),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(80, 40),
        ),
        child: Text(
          translationLabel,
          style: TextStyle(
            color: isSelected ? const Color(0xFF181A1A) : Colors.white,
          ),
        ),
      ),
    );
  }

  /// Exibe um modal para o usuário selecionar a tradução da Bíblia.
  static void showTranslationSelection({
    required BuildContext context,
    required String selectedTranslation,
    required Function(String) onTranslationSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Escolha a Tradução",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                alignment: WrapAlignment.center,
                children: [
                  buildTranslationButton(
                    translationKey: 'nvi',
                    translationLabel: 'NVI',
                    selectedTranslation: selectedTranslation,
                    onPressed: () {
                      onTranslationSelected('nvi');
                      Navigator.pop(context);
                    },
                  ),
                  buildTranslationButton(
                    translationKey: 'aa',
                    translationLabel: 'AA',
                    selectedTranslation: selectedTranslation,
                    onPressed: () {
                      onTranslationSelected('aa');
                      Navigator.pop(context);
                    },
                  ),
                  buildTranslationButton(
                    translationKey: 'acf',
                    translationLabel: 'ACF',
                    selectedTranslation: selectedTranslation,
                    onPressed: () {
                      onTranslationSelected('acf');
                      Navigator.pop(context);
                    },
                  ),
                  buildTranslationButton(
                    translationKey:
                        'hebrew_original', // Chave para sua tradução Hebraica
                    translationLabel: 'Hebraico (Orig.)',
                    selectedTranslation: selectedTranslation,
                    onPressed: () {
                      onTranslationSelected('hebrew_original');
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Função para formatar texto de traduções normais (não hebraico).
  static List<TextSpan> _formatRegularVerseText(String verseText) {
    final List<TextSpan> spans = [];
    final RegExp regex =
        RegExp(r'(?<![\w])((\d+\.)|(\(\d+\)))(?!\w)\s*', multiLine: true);
    int currentPosition = 0;
    const TextStyle baseStyle =
        TextStyle(color: Colors.white, fontSize: 16, height: 1.5);
    const TextStyle numberStyle = TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFFEAEAEA),
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

  /// Constrói o widget para exibir um único versículo.
  static Widget buildVerseItem({
    required int verseNumber,
    required dynamic verseData, // Pode ser String ou List<Map<String, String>>
    required String? selectedBook,
    required int? selectedChapter,
    required BuildContext context,
    required Map<String, String> userHighlights,
    required Map<String, String> userNotes,
    bool isHebrew = false,
  }) {
    final verseId = "${selectedBook}_${selectedChapter}_$verseNumber";
    final String? currentHighlightColorHex = userHighlights[verseId];
    final bool hasNote = userNotes.containsKey(verseId);
    final backgroundColor = currentHighlightColorHex != null
        ? Color(int.parse(currentHighlightColorHex.replaceFirst('#', '0xff')))
            .withOpacity(0.30)
        : Colors.transparent;

    Widget verseContentWidget;
    String verseTextForModal = "";

    if (isHebrew && verseData is List<Map<String, String>>) {
      List<TextSpan> hebrewSpans = [];
      for (var wordData in verseData) {
        final text = wordData['text'] ?? '';
        final strong = wordData['strong'] ?? '';
        final cleanText =
            text.replaceAll(RegExp(r'[/\\]'), ''); // Remove barras para o modal
        verseTextForModal += "$cleanText ";

        hebrewSpans.add(
          TextSpan(
            text: '$text ',
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontFamily: 'NotoSansHebrew', // Use a fonte Hebraica aqui
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (strong.isNotEmpty) {
                  _showStrongsInfoModal(context, strong, text);
                }
              },
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
          children: _formatRegularVerseText(verseData),
        ),
      );
    } else {
      verseTextForModal = "[Formato de verso inválido]";
      verseContentWidget = Text(verseTextForModal,
          style: const TextStyle(color: Colors.redAccent));
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
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB0B0B0),
                  fontWeight: FontWeight.bold),
            ),
            Expanded(child: verseContentWidget),
            if (hasNote)
              Padding(
                padding: const EdgeInsets.only(left: 5.0, right: 2.0, top: 2.0),
                child: Icon(Icons.note_alt_rounded,
                    color: Colors.blueAccent[100], size: 16),
              ),
          ],
        ),
      ),
    );
  }

  /// Mostra informações do Léxico de Strong em um modal.
  static void _showStrongsInfoModal(BuildContext context,
      String strongNumberWithPrefix, String hebrewWord) async {
    // Remove prefixos como "H" ou "c/" se existirem, para obter apenas o número
    final String strongNumber =
        strongNumberWithPrefix.replaceAll(RegExp(r'^[Hc]/'), '');

    final lexicon = await BiblePageHelper.getStrongsLexicon();
    if (lexicon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Léxico de Strong não carregado.")));
      return;
    }

    final entry = lexicon[strongNumber]
        as Map<String, dynamic>?; // Busca pelo número puro

    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Informações de Strong não encontradas para $strongNumber")));
      return;
    }
    final transliteration = entry['transliteration'] ?? 'N/A';
    final definitionsPt =
        (entry['definitions_pt'] as List<dynamic>?)?.cast<String>() ??
            ['Nenhuma definição em português.'];
    final originalLemma =
        entry['lemma_hebrew'] ?? hebrewWord; // Use hebrewWord como fallback

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2F33),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Informações de Strong: $strongNumber",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Palavra Hebraica: $hebrewWord (Lema: $originalLemma)",
                    style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 17,
                        fontFamily: 'NotoSansHebrew')), // Aumentado
                Text("Transliteração: $transliteration",
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic)), // Aumentado
                const SizedBox(height: 12),
                const Text("Definições em Português:",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500)), // Aumentado
                ...definitionsPt.map((def) => Padding(
                      padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                      child: Text("• $def",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15)), // Aumentado
                    )),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(modalContext),
                    child: const Text("Fechar",
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 15)), // Aumentado
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  /// Exibe um modal (BottomSheet) com opções para o versículo selecionado.
  static void _showVerseOptionsModal(
      BuildContext context,
      String verseId,
      String? currentHighlightColor,
      String? currentNote,
      String bookAbbrev,
      int chapter,
      int verseNum,
      String verseText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2F33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        final store = StoreProvider.of<AppState>(context);

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
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(
                      verseText,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white54, height: 25),
              ListTile(
                leading: Icon(Icons.format_paint_outlined,
                    color: currentHighlightColor != null
                        ? Color(int.parse(
                            currentHighlightColor.replaceFirst('#', '0xff')))
                        : Colors.white70),
                title: Text(
                    currentHighlightColor != null
                        ? "Mudar/Remover Destaque"
                        : "Destacar Versículo",
                    style: const TextStyle(color: Colors.white)),
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
                    color: Colors.white70),
                title: Text(
                    currentNote != null ? "Editar Nota" : "Adicionar Nota",
                    style: const TextStyle(color: Colors.white)),
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
                  leading:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text("Remover Nota",
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    store.dispatch(DeleteNoteAction(verseId));
                    Navigator.pop(modalContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Nota removida.'),
                          duration: Duration(seconds: 2)),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.bookmark_add_outlined,
                    color: Colors.white70),
                title: const Text("Salvar em Coleção",
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    builder: (dContext) => SaveVerseDialog(
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
}
