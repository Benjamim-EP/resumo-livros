// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Para acessar o store nos modais
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart'; // Para salvar versículo
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/highlight_color_picker_modal.dart'; // Modal de cores
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/note_editor_modal.dart'; // Modal de notas

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
      // Adiciona padding entre os botões
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isSelected ? const Color(0xFFCDE7BE) : const Color(0xFF272828),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10), // Ajuste no padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(80, 40), // Garante um tamanho mínimo
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
                // Usa Wrap para melhor layout se houver muitas traduções
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
                  // Adicione mais botões para outras traduções aqui
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Formata o texto do versículo, aplicando negrito aos marcadores "n."/(n.).
  /// Não aplica mais cor de fundo diretamente aos TextSpans.
  static List<TextSpan> _formatVerseText(String verseText) {
    final List<TextSpan> spans = [];
    // Regex ajustada para ser menos restritiva no início e garantir que captura o marcador completo.
    final RegExp regex =
        RegExp(r'(?<![\w])((\d+\.)|(\(\d+\)))(?!\w)\s*', multiLine: true);
    int currentPosition = 0;

    // Estilo base para o texto do versículo (sem background)
    const TextStyle baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      height: 1.5,
    );
    // Estilo para os números formatados (sem background)
    const TextStyle numberStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Color(0xFFEAEAEA), // Cor um pouco mais clara para destaque
      fontSize: 16, // Mesmo tamanho da fonte base
      height: 1.5, // Mesma altura da linha base
    );

    for (final Match match in regex.allMatches(verseText)) {
      // Adiciona texto antes do marcador
      if (match.start > currentPosition) {
        spans.add(TextSpan(
            text: verseText.substring(currentPosition, match.start),
            style: baseStyle));
      }
      // Adiciona o marcador em negrito
      spans.add(TextSpan(
        text: match.group(1)!, // O número com ponto ou parênteses
        style: numberStyle,
      ));
      // Adiciona um espaço APÓS o marcador, se houver espaço capturado
      if (match.group(0)!.endsWith(' ')) {
        spans.add(TextSpan(text: ' ', style: baseStyle));
      }

      currentPosition = match.end;
    }

    // Adiciona o restante do texto
    if (currentPosition < verseText.length) {
      spans.add(TextSpan(
          text: verseText.substring(currentPosition), style: baseStyle));
    }

    // Retorna o texto original se nenhuma formatação foi aplicada
    if (spans.isEmpty) {
      return [TextSpan(text: verseText, style: baseStyle)];
    }

    return spans;
  }

  /// Constrói o widget para exibir um único versículo, com interações e destaque de fundo.
  static Widget buildVerseItem({
    required int verseNumber,
    required String verseText,
    required String? selectedBook, // abbrev
    required int? selectedChapter,
    required BuildContext context,
    required Map<String, String> userHighlights, // Vem do Redux
    required Map<String, String> userNotes, // Vem do Redux
  }) {
    // Cria um ID único e consistente para o versículo
    final verseId = "${selectedBook}_${selectedChapter}_$verseNumber";
    final String? currentHighlightColorHex = userHighlights[verseId];
    final bool hasNote = userNotes.containsKey(verseId);

    // Define a cor de fundo para o Container com base no destaque
    final backgroundColor = currentHighlightColorHex != null
        ? Color(int.parse(currentHighlightColorHex.replaceFirst('#', '0xff')))
            .withOpacity(
                0.30) // Ajuste a opacidade para o sombreamento desejado
        : Colors.transparent;

    return GestureDetector(
      // Permite interações no versículo inteiro
      onLongPress: () {
        // Mostra o modal de opções ao pressionar longamente
        _showVerseOptionsModal(
          context,
          verseId,
          currentHighlightColorHex, // Passa o Hex original
          userNotes[verseId], // Passa o texto da nota atual
          selectedBook!,
          selectedChapter!,
          verseNumber,
          verseText, // Passa o texto original para o modal
        );
      },
      child: Container(
        // Aplica a cor de fundo (sombreamento) aqui
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número do Versículo (sem fundo próprio)
            Text(
              '$verseNumber ',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB0B0B0),
                fontWeight: FontWeight.bold,
              ),
            ),
            // Texto do Versículo (Formatado, sem fundo nos TextSpans)
            Expanded(
              child: RichText(
                text: TextSpan(
                  // Chama _formatVerseText sem a cor de destaque
                  children: _formatVerseText(verseText),
                ),
              ),
            ),
            // Ícone de Nota (se houver)
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

  /// Exibe um modal (BottomSheet) com opções para o versículo selecionado.
  static void _showVerseOptionsModal(
      BuildContext context,
      String verseId,
      String? currentHighlightColor, // Recebe Hex
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
        final store = StoreProvider.of<AppState>(context); // Acesso ao store

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho com referência e preview
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

              // Opção de Destaque
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
                          store.dispatch(ToggleHighlightAction(
                              verseId)); // colorHex null remove
                        }),
                  );
                },
              ),

              // Opção de Nota
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

              // Opção de Remover Nota (Condicional)
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

              // Opção de Salvar em Coleção (Bookmark)
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
              const SizedBox(height: 10), // Espaço no final
            ],
          ),
        );
      },
    );
  }
}
