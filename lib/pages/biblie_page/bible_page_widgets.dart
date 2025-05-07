// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart';

class BiblePageWidgets {
  // ... (buildTranslationButton e showTranslationSelection permanecem iguais) ...
  static Widget buildTranslationButton({
    required String translationKey,
    required String translationLabel,
    required String selectedTranslation,
    required VoidCallback onPressed,
  }) {
    final isSelected = selectedTranslation == translationKey;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFCDE7BE) : const Color(0xFF272828),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        translationLabel,
        style: TextStyle(
          color: isSelected ? const Color(0xFF181A1A) : Colors.white,
        ),
      ),
    );
  }

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
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
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
            ],
          ),
        );
      },
    );
  }

  // <<< NOVO: Função para formatar o texto do versículo >>>
  static List<TextSpan> _formatVerseText(String verseText) {
    final List<TextSpan> spans = [];
    // Regex para encontrar "n." ou "(n.)" no início de uma "linha" ou após certos caracteres.
    // Esta regex pode precisar de ajustes dependendo da consistência da sua fonte de texto.
    // A ideia é capturar o número e o ponto, e o texto seguinte.
    // \b(\d+\.)\s* -> Captura "1. ", "2. ", etc. no início de uma palavra/linha.
    // \b(\(\d+\))\s* -> Captura "(1)", "(2)", etc. no início de uma palavra/linha.
    // (?<!\S) -> Negative lookbehind para garantir que não há caractere não-espaço antes (início de linha/parágrafo)
    final RegExp regex =
        RegExp(r'(?<!\S)((\d+\.)|(\(\d+\)))\s*', multiLine: true);

    int currentPosition = 0;
    for (final Match match in regex.allMatches(verseText)) {
      // Adiciona o texto antes do marcador
      if (match.start > currentPosition) {
        spans.add(
            TextSpan(text: verseText.substring(currentPosition, match.start)));
      }
      // Adiciona o marcador em negrito
      spans.add(TextSpan(
        text: match.group(1)!, // O número com ponto ou parênteses
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE0E0E0)), // Cor um pouco mais clara para o número
      ));
      // Adiciona um espaço após o marcador, se não estiver já incluído no match.group(0)
      // e prepara para um novo parágrafo (na verdade, o RichText já lida com isso se houver \n)
      // Se você quiser forçar uma nova linha visual após cada marcador,
      // você pode adicionar um TextSpan(text: '\n') aqui, mas isso pode não ser o ideal
      // para a leitura fluida. O RichText naturalmente quebra linhas.
      // Se o seu texto original já tem quebras de linha, elas serão respeitadas.
      // Se o texto é uma string contínua e você quer quebrar APÓS o "n.",
      // a regex precisaria ser ajustada ou o processamento seria mais complexo.

      // Para o efeito de "iniciar novo parágrafo", o mais simples é garantir que
      // seu texto original tenha quebras de linha (\n) onde você quer os parágrafos.
      // Se não tiver, a regex sozinha não cria parágrafos, apenas estiliza o número.

      // Se o texto fonte não tiver \n e você quer que "n." inicie visualmente um novo bloco:
      // Aqui, vamos assumir que o RichText com TextSpans já lida bem com a quebra de linha natural.
      // Se você precisar FORÇAR uma quebra visual, pode adicionar \n ao texto antes do marcador.
      // Por exemplo, processar o `verseText` para substituir " 1." por "\n1. " antes desta função.
      // Ou, se a intenção é apenas que o texto após "1." continue normalmente:
      spans.add(const TextSpan(
          text: ' ')); // Adiciona um espaço após o número em negrito

      currentPosition = match.end;
    }

    // Adiciona o restante do texto
    if (currentPosition < verseText.length) {
      spans.add(TextSpan(text: verseText.substring(currentPosition)));
    }

    // Se spans estiver vazio (texto original não tinha marcadores), retorna o texto original simples
    if (spans.isEmpty) {
      return [TextSpan(text: verseText)];
    }

    return spans;
  }
  // <<< FIM NOVO >>>

  static Widget buildVerseItem({
    required int verseNumber,
    required String verseText,
    required String? selectedBook,
    required int? selectedChapter,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 6.0), // Aumentado o padding vertical
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$verseNumber ',
            style: const TextStyle(
              fontSize: 12,
              color: Color(
                  0xFFB0B0B0), // Cor mais suave para o número do versículo
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            // <<< MODIFICAÇÃO MVP: Usa RichText para formatar o texto >>>
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5), // Estilo padrão
                children: _formatVerseText(verseText),
              ),
            ),
            // <<< FIM MODIFICAÇÃO MVP >>>
          ),
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: Colors.white70,
              size: 20, // Tamanho ligeiramente aumentado
            ),
            onPressed: () {
              if (selectedBook != null && selectedChapter != null) {
                showDialog(
                  context: context,
                  builder: (context) => SaveVerseDialog(
                    bookAbbrev: selectedBook,
                    chapter: selectedChapter,
                    verseNumber: verseNumber,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Selecione livro e capítulo para salvar.")));
              }
            },
            padding: const EdgeInsets.all(4), // Padding menor para o ícone
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
