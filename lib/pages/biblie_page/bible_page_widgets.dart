// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/biblie_page/tag_editor_dialog.dart';
import 'package:septima_biblia/pages/sharing/image_selection_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/saveVerseDialog.dart';
import 'package:septima_biblia/pages/biblie_page/note_editor_modal.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/services/analytics_service.dart';
import 'package:septima_biblia/services/bible_version_service.dart';

class BiblePageWidgets {
  // >>> INÍCIO DA CORREÇÃO 2/4: Adicionando os parâmetros que faltavam <<<
  static void _showPremiumDialog(BuildContext context) {
    // Fecha o modal de seleção de tradução que está aberto
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recurso Premium 👑'),
        content: const Text(
            'Acesso às línguas originais (Hebraico e Grego) é um recurso exclusivo para assinantes Premium.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Agora não')),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Fecha o diálogo
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SubscriptionSelectionPage()));
            },
            child: const Text('Ver Planos'),
          ),
        ],
      ),
    );
  }

  /// Limpa prefixos de numeração e letras como "1)", "2a.", "(b)", etc., do início de uma string.
  static String cleanLexiconEntry(String rawText) {
    // Regex final, focada nos casos de teste
    // (\s* ... \s*)+ -> Captura um ou mais prefixos com espaços ao redor
    // \(\S+?\)      -> Captura qualquer coisa dentro de parênteses: (c), (1d), (3)
    // \.?           -> Captura um ponto opcional DEPOIS dos parênteses: (3).
    // |             -> OU
    // \w+[\).]      -> Captura uma palavra ou número seguido por ')' ou '.': 1), 1a), b.
    final RegExp prefixRegex = RegExp(r'^(\s*(\(\S+?\)\.?|\w+[\).])\s*)+');
    return rawText.replaceFirst(prefixRegex, '').trim();
  }

  /// Limpa o prefixo "• - " das notas.
  static String cleanLexiconNote(String rawText) {
    final RegExp prefixRegex = RegExp(r'^\s*•\s*-\s*');
    return rawText.replaceFirst(prefixRegex, '').trim();
  }

  static Widget buildTranslationButton({
    required BuildContext context,
    required String translationKey,
    required String translationLabel,
    required String selectedTranslation,
    required VoidCallback onPressed,
    bool isPremiumFeature = false,
    bool isPremiumUser = false,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedTranslation == translationKey;

    Color buttonColor = isSelected
        ? theme.colorScheme.primary
        : theme.cardColor.withOpacity(0.7);
    Color textColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.textTheme.bodyLarge?.color ?? Colors.white;

    Widget buttonChild = Text(
      translationLabel,
      style: const TextStyle(fontSize: 12),
      textAlign: TextAlign.center,
    );

    if (isPremiumFeature && !isPremiumUser) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: 12, color: textColor.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(translationLabel, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: isPremiumFeature && !isSelected
                ? BorderSide(color: Colors.amber.shade600, width: 1.5)
                : BorderSide.none,
          ),
          minimumSize: const Size(80, 40),
        ),
        child: buttonChild,
      ),
    );
  }

  static void showTranslationSelection({
    required BuildContext context,
    required String selectedTranslation,
    required Function(String) onTranslationSelected,
    required String? currentSelectedBookAbbrev,
    required Map<String, dynamic>? booksMap,
    required bool isPremium,
    required VoidCallback onToggleCompareMode,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        // <<< O builder agora retorna nosso novo widget Stateful >>>
        return _TranslationSelectionModalContent(
          selectedTranslation: selectedTranslation,
          onTranslationSelected: onTranslationSelected,
          currentSelectedBookAbbrev: currentSelectedBookAbbrev,
          booksMap: booksMap,
          isPremium: isPremium,
          onToggleCompareMode: onToggleCompareMode,
        );
      },
    );
  }

  static List<TextSpan> _formatRegularVerseText(
      String verseText, ThemeData theme, double fontSizeMultiplier) {
    final List<TextSpan> spans = [];
    final RegExp regex =
        RegExp(r'(?<![\w])((\d+\.)|(\(\d+\)))(?!\w)\s*', multiLine: true);
    int currentPosition = 0;
    final double baseFontSize = 16.0;
    final baseStyle = TextStyle(
        color: theme.textTheme.bodyLarge?.color,
        fontSize: baseFontSize * fontSizeMultiplier,
        height: 1.5);
    final numberStyle = TextStyle(
        fontWeight: FontWeight.bold,
        color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
        fontSize: baseFontSize * fontSizeMultiplier,
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
    if (spans.isEmpty && verseText.isNotEmpty) {
      return [TextSpan(text: verseText, style: baseStyle)];
    }
    return spans;
  }

  static String _extractShortDefinition(List<dynamic>? definitions) {
    if (definitions == null || definitions.isEmpty) {
      return "N/A";
    }

    // Pega a primeira definição da lista
    String firstFullDefinition = definitions.first.toString().trim();

    // ✅ CORREÇÃO: Usa a regex mais poderosa para limpar todos os tipos de prefixo
    final RegExp prefixRegex =
        RegExp(r'^\s*(\(?\d+[a-z]?\)?\.?\s*|\([a-z]\)\s*)+');
    String cleanedDefinition =
        firstFullDefinition.replaceFirst(prefixRegex, '').trim();

    // O resto da lógica para encurtar a definição continua a mesma
    List<String> parts = [];
    if (cleanedDefinition.contains(',')) {
      parts = cleanedDefinition.split(',');
    } else if (cleanedDefinition.contains(';')) {
      parts = cleanedDefinition.split(';');
    } else {
      parts = [cleanedDefinition];
    }

    String shortDef = parts.first.trim();
    shortDef = shortDef
        .replaceFirst(RegExp(r'^\((TWOT|BDB|KJV|LXX|et al)\.?\)\s*'), '')
        .trim();

    // Adiciona a primeira letra maiúscula para um visual mais limpo
    if (shortDef.isNotEmpty) {
      shortDef = shortDef[0].toUpperCase() + shortDef.substring(1);
    }

    // Trunca a definição se for muito longa
    const maxLength = 25;
    if (shortDef.length > maxLength) {
      return "${shortDef.substring(0, maxLength)}...";
    }

    return shortDef.isNotEmpty ? shortDef : "N/A";
  }

  static Widget _buildHebrewInterlinearWord(
    BuildContext context,
    Map<String, String> wordData,
    String? selectedBook,
    int? selectedChapter,
    int verseNumber,
    Map<String, dynamic>? hebrewLexicon,
    double fontSizeMultiplier,
  ) {
    final theme = Theme.of(context);
    final hebrewText = wordData['text'] ?? '';
    final strongNumberWithPrefix = wordData['strong'] ?? '';
    final String strongNumberOnly =
        strongNumberWithPrefix.replaceAll(RegExp(r'^[Hc]/'), '');
    String transliteration = wordData['translit'] ?? "---";
    String shortDefinition = "N/A";

    if (strongNumberOnly.isNotEmpty && hebrewLexicon != null) {
      final lexiconEntry =
          hebrewLexicon[strongNumberOnly] as Map<String, dynamic>?;
      if (lexiconEntry != null) {
        if (transliteration == "---" &&
            lexiconEntry['transliteration'] != null) {
          transliteration = lexiconEntry['transliteration'];
        }
        List<dynamic>? definitionsPt =
            lexiconEntry['definitions_pt'] as List<dynamic>?;
        List<dynamic>? definitionsOrig =
            lexiconEntry['definitions'] as List<dynamic>?;

        if (definitionsPt != null &&
            definitionsPt.isNotEmpty &&
            !definitionsPt.every(
                (d) => d.toString().toUpperCase().startsWith("TRADUZIR:"))) {
          shortDefinition = _extractShortDefinition(definitionsPt);
        } else if (definitionsOrig != null && definitionsOrig.isNotEmpty) {
          shortDefinition = _extractShortDefinition(definitionsOrig);
        }
      }
    }

    final double baseHebrewFontSize = 20.0;
    final double baseTranslitFontSize = 10.0;
    final double baseDefinitionFontSize = 9.0;

    return GestureDetector(
      onTap: () {
        AnalyticsService.instance.logEvent(
          name: 'lexicon_word_lookup',
          parameters: {
            'language': 'hebrew',
            'strong_number': strongNumberWithPrefix,
            'word_translit': transliteration,
          },
        );
        if (strongNumberOnly.isNotEmpty && strongNumberOnly != "N/A") {
          _showVerseLexiconModalHebrew(context, selectedBook!, selectedChapter!,
              verseNumber, strongNumberWithPrefix, hebrewLexicon);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              hebrewText,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: baseHebrewFontSize * fontSizeMultiplier,
                color: theme.textTheme.bodyLarge?.color,
                fontFamily: 'NotoSansHebrew',
              ),
            ),
            Text(
              transliteration,
              style: TextStyle(
                fontSize: baseTranslitFontSize * fontSizeMultiplier,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            if (shortDefinition.isNotEmpty && shortDefinition != "N/A")
              Padding(
                padding: const EdgeInsets.only(top: 1.0), // Pequeno espaço
                child: Text(
                  shortDefinition,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: baseDefinitionFontSize * fontSizeMultiplier,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _buildGreekInterlinearWord(
    BuildContext context,
    Map<String, String> wordData,
    String? selectedBook,
    int? selectedChapter,
    int verseNumber,
    Map<String, dynamic>? greekLexicon,
    double fontSizeMultiplier,
  ) {
    final theme = Theme.of(context);
    final greekText = wordData['text'] ?? '';
    final strongNumber = wordData['strong'] ?? '';

    // ✅ 1. PEGA A TRANSLITERAÇÃO DOS DADOS DA PALAVRA
    String transliteration = wordData['translit'] ?? "---";
    String shortDefinition = "N/A";

    if (strongNumber.isNotEmpty &&
        strongNumber != "N/A" &&
        greekLexicon != null) {
      final lexiconEntry = greekLexicon[strongNumber] as Map<String, dynamic>?;
      if (lexiconEntry != null) {
        // ✅ 2. FALLBACK: Se a transliteração não veio nos dados, pega do léxico
        if (transliteration == "---" &&
            lexiconEntry['transliteration'] != null) {
          transliteration = lexiconEntry['transliteration'];
        }

        // Lógica para definição curta (permanece a mesma)
        List<dynamic>? definitionsPt =
            lexiconEntry['definitions_pt'] as List<dynamic>?;
        List<dynamic>? definitionsOrig =
            lexiconEntry['definitions'] as List<dynamic>?;

        if (definitionsPt != null &&
            definitionsPt.isNotEmpty &&
            !definitionsPt.every(
                (d) => d.toString().toUpperCase().startsWith("TRADUZIR:"))) {
          shortDefinition = _extractShortDefinition(definitionsPt);
        } else if (definitionsOrig != null && definitionsOrig.isNotEmpty) {
          shortDefinition = _extractShortDefinition(definitionsOrig);
        }
      }
    }

    final double baseGreekFontSize = 19.0;
    // ✅ 3. ADICIONA UM TAMANHO DE FONTE PARA A TRANSLITERAÇÃO
    final double baseTranslitFontSize = 10.0;
    final double baseDefinitionFontSize = 9.0;

    return GestureDetector(
      onTap: () {
        AnalyticsService.instance.logEvent(
          name: 'lexicon_word_lookup',
          parameters: {
            'language': 'greek',
            'strong_number': strongNumber,
            'word_translit': transliteration,
          },
        );
        if (strongNumber.isNotEmpty && strongNumber != "N/A") {
          _showVerseLexiconModalGreek(context, selectedBook!, selectedChapter!,
              verseNumber, strongNumber, greekLexicon);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 2.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Palavra em Grego (como antes)
            Text(
              greekText,
              style: TextStyle(
                fontSize: baseGreekFontSize * fontSizeMultiplier,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),

            // ✅ 4. EXIBE A TRANSLITERAÇÃO ABAIXO DA PALAVRA GREGA
            Text(
              transliteration,
              style: TextStyle(
                fontSize: baseTranslitFontSize * fontSizeMultiplier,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),

            // Definição curta (como antes)
            if (shortDefinition.isNotEmpty && shortDefinition != "N/A")
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: Text(
                  shortDefinition,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: baseDefinitionFontSize * fontSizeMultiplier,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget buildVerseItem({
    required Key key,
    required int verseNumber,
    required dynamic verseData,
    required String? selectedBook,
    required int? selectedChapter,
    required BuildContext context,
    required Map<String, Map<String, dynamic>> userHighlights,
    required List<Map<String, dynamic>> userNotes,
    required List<String> allUserTags,
    required double fontSizeMultiplier,
    bool isHebrew = false,
    bool isGreekInterlinear = false,
    bool showHebrewInterlinear = false,
    bool showGreekInterlinear = false,
    List<Map<String, String>>? hebrewVerseData,
    List<Map<String, String>>? greekVerseData,
    bool isRecommended = false, // Parâmetro que estamos usando
  }) {
    // A lógica interna para preparar os dados (theme, verseId, highlights, etc.)
    // permanece exatamente a mesma.
    final theme = Theme.of(context);
    final verseId = "${selectedBook}_${selectedChapter}_$verseNumber";

    final Map<String, dynamic>? currentHighlightData = userHighlights[verseId];
    final String? currentHighlightColorHex =
        currentHighlightData?['color'] as String?;
    final bool hasNote = userNotes.any((note) => note['verseId'] == verseId);
    String? currentNoteText;
    if (hasNote) {
      currentNoteText = userNotes.firstWhere(
        (note) => note['verseId'] == verseId,
        orElse: () => {},
      )['noteText'] as String?;
    }
    final backgroundColor = currentHighlightColorHex != null
        ? Color(int.parse(currentHighlightColorHex.replaceFirst('#', '0xff')))
            .withOpacity(0.30)
        : Colors.transparent;

    String verseTextForModalDialog = "";
    Widget mainTranslationWidget;

    // ... (toda a sua lógica para 'if (isGreekInterlinear)', 'if (isHebrew)', etc. continua AQUI, sem nenhuma alteração)
    if (isGreekInterlinear && verseData is List<Map<String, String>>) {
      List<Widget> greekWordWidgets = [];
      final greekLexicon = BiblePageHelper.cachedGreekStrongsLexicon;
      for (var wordDataMap in verseData) {
        verseTextForModalDialog += "${wordDataMap['text'] ?? ''} ";
        greekWordWidgets.add(_buildGreekInterlinearWord(
            context,
            wordDataMap,
            selectedBook,
            selectedChapter,
            verseNumber,
            greekLexicon,
            fontSizeMultiplier));
      }
      mainTranslationWidget = Wrap(
          alignment: WrapAlignment.start,
          runSpacing: 0.0,
          spacing: 4.0,
          children: greekWordWidgets);
    } else if (isHebrew && verseData is List<Map<String, String>>) {
      List<Widget> hebrewWordWidgets = [];
      final hebrewLexicon = BiblePageHelper.cachedHebrewStrongsLexicon;
      for (var wordDataMap in verseData) {
        verseTextForModalDialog += "${wordDataMap['text'] ?? ''} ";
        hebrewWordWidgets.add(_buildHebrewInterlinearWord(
            context,
            wordDataMap,
            selectedBook,
            selectedChapter,
            verseNumber,
            hebrewLexicon,
            fontSizeMultiplier));
      }
      mainTranslationWidget = Wrap(
          alignment: WrapAlignment.end,
          textDirection: TextDirection.rtl,
          runSpacing: 4.0,
          spacing: 4.0,
          children: hebrewWordWidgets);
    } else if (verseData is String) {
      verseTextForModalDialog = verseData;
      mainTranslationWidget = RichText(
        text: TextSpan(
          children:
              _formatRegularVerseText(verseData, theme, fontSizeMultiplier),
        ),
      );
    } else {
      verseTextForModalDialog = "[Formato de verso inválido]";
      mainTranslationWidget = Text(verseTextForModalDialog,
          style: TextStyle(
              color: theme.colorScheme.error,
              fontSize: 14 * fontSizeMultiplier));
    }

    Widget? complementaryHebrewInterlinearWidget;
    if (showHebrewInterlinear &&
        hebrewVerseData != null &&
        hebrewVerseData.isNotEmpty) {
      List<Widget> interlinearHebrewWords = [];
      final hebrewLexicon = BiblePageHelper.cachedHebrewStrongsLexicon;
      for (var wordDataMap in hebrewVerseData) {
        interlinearHebrewWords.add(_buildHebrewInterlinearWord(
            context,
            wordDataMap,
            selectedBook,
            selectedChapter,
            verseNumber,
            hebrewLexicon,
            fontSizeMultiplier));
      }
      complementaryHebrewInterlinearWidget = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Divider(color: theme.dividerColor.withOpacity(0.3), height: 12),
            Wrap(
              alignment: WrapAlignment.end,
              textDirection: TextDirection.rtl,
              runSpacing: 4.0,
              spacing: 4.0,
              children: interlinearHebrewWords,
            ),
          ],
        ),
      );
    }

    Widget? complementaryGreekInterlinearWidget;
    if (showGreekInterlinear &&
        greekVerseData != null &&
        greekVerseData.isNotEmpty) {
      List<Widget> interlinearGreekWords = [];
      final greekLexicon = BiblePageHelper.cachedGreekStrongsLexicon;
      for (var wordDataMap in greekVerseData) {
        interlinearGreekWords.add(_buildGreekInterlinearWord(
            context,
            wordDataMap,
            selectedBook,
            selectedChapter,
            verseNumber,
            greekLexicon,
            fontSizeMultiplier));
      }
      complementaryGreekInterlinearWidget = Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: theme.dividerColor.withOpacity(0.3), height: 12),
            Wrap(
              alignment: WrapAlignment.start,
              runSpacing: 4.0,
              spacing: 4.0,
              children: interlinearGreekWords,
            ),
          ],
        ),
      );
    }
    // ==========================================================
    // <<< INÍCIO DA MODIFICAÇÃO PRINCIPAL >>>
    // ==========================================================

    // 1. O conteúdo interno do versículo (o que já estava dentro do GestureDetector)
    final verseContentWidget = GestureDetector(
      key: key,
      onLongPress: () {
        // ... sua lógica de onLongPress permanece a mesma
        String? currentNoteText;
        if (hasNote) {
          currentNoteText = userNotes.firstWhere(
            (note) => note['verseId'] == verseId,
            orElse: () => {},
          )['noteText'] as String?;
        }
        _showVerseOptionsModal(
          context,
          verseId: verseId,
          currentHighlightColor: currentHighlightColorHex,
          currentHighlightData: currentHighlightData,
          currentNote: currentNoteText,
          bookAbbrev: selectedBook!,
          chapter: selectedChapter!,
          verseNum: verseNumber,
          verseText: verseTextForModalDialog.trim(),
          allUserTags: allUserTags,
        );
      },
      child: Container(
        // A cor de fundo do highlight do usuário continua aqui
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$verseNumber ',
                  style: TextStyle(
                      fontSize: 12 * fontSizeMultiplier,
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.bold),
                ),
                Expanded(child: mainTranslationWidget),
                if (hasNote &&
                    !isHebrew &&
                    !isGreekInterlinear &&
                    !showHebrewInterlinear &&
                    !showGreekInterlinear)
                  IconButton(
                    icon: Icon(Icons.note_alt_rounded,
                        color: theme.colorScheme.primary.withOpacity(0.8),
                        size: 16 * fontSizeMultiplier),
                    tooltip: "Ver Nota",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      if (currentNoteText != null &&
                          currentNoteText.isNotEmpty) {
                        final String referenceForDialog =
                            "$selectedBook $selectedChapter:$verseNumber";
                        _showViewNoteDialog(
                            context, referenceForDialog, currentNoteText);
                      }
                    },
                  )
              ],
            ),
            if (complementaryHebrewInterlinearWidget != null)
              complementaryHebrewInterlinearWidget,
            if (complementaryGreekInterlinearWidget != null)
              complementaryGreekInterlinearWidget,
          ],
        ),
      ),
    );

    // 2. O Container externo que receberá a animação
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.0),
      // A decoração (borda/brilho) será controlada pelo flutter_animate
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(8), // Borda arredondada para o brilho
      ),
      child: verseContentWidget,
    )
        .animate(
          target: isRecommended ? 1.0 : 0.0, // O alvo da animação
          onPlay: (controller) {
            if (isRecommended) {
              controller.repeat(reverse: true); // Faz a animação pulsar
            }
          },
        )
        .boxShadow(
          begin: BoxShadow(color: Colors.transparent),
          end: BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.6),
            spreadRadius: 2,
            blurRadius: 5,
          ),
          duration: 1500.ms, // Duração de cada "pulso"
          curve: Curves.easeInOut,
        );
    // ==========================================================
    // <<< FIM DA MODIFICAÇÃO PRINCIPAL >>>
    // ==========================================================
  }

  static void _showVerseOptionsModal(
    BuildContext context, {
    // MUDANÇA: Parâmetros agora são nomeados
    required String verseId,
    required String? currentHighlightColor,
    required Map<String, dynamic>? currentHighlightData,
    required String? currentNote,
    required String bookAbbrev,
    required int chapter,
    required int verseNum,
    required String verseText,
    required List<String> allUserTags, // Parâmetro obrigatório
  }) {
    final theme = Theme.of(context);
    final store = StoreProvider.of<AppState>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            top: 16.0,
            left: 8.0,
            right: 8.0,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do Modal
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Opções para: $bookAbbrev $chapter:$verseNum",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      verseText.isNotEmpty
                          ? verseText
                          : "[Conteúdo interlinear]",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.75),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Divider(color: theme.dividerColor.withOpacity(0.5), height: 20),

              // Opção 1: Destacar Versículo
              ListTile(
                leading: Icon(
                  Icons.format_paint_outlined,
                  color: currentHighlightColor != null
                      ? Color(int.parse(
                          currentHighlightColor.replaceFirst('#', '0xff')))
                      : theme.iconTheme.color?.withOpacity(0.8),
                ),
                title: Text(
                  currentHighlightColor != null
                      ? "Editar Destaque/Tags"
                      : "Destacar Versículo",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface, fontSize: 15),
                ),
                onTap: () async {
                  Navigator.pop(modalContext);
                  final result = await showDialog<HighlightResult?>(
                    context: context,
                    builder: (_) => HighlightEditorDialog(
                      initialColor: currentHighlightColor,
                      initialTags: List<String>.from(
                          currentHighlightData?['tags'] ?? []),
                      allUserTags: allUserTags,
                    ),
                  );
                  if (result == null) return;
                  if (result.shouldRemove) {
                    store.dispatch(ToggleHighlightAction(verseId));
                  } else if (result.colorHex != null) {
                    store.dispatch(ToggleHighlightAction(
                      verseId,
                      colorHex: result.colorHex,
                      tags: result.tags,
                    ));
                  }
                },
              ),

              // <<< NOVA OPÇÃO ADICIONADA AQUI >>>
              // Opção 2: Compartilhar Versículo
              ListTile(
                leading: Icon(Icons.share_outlined,
                    color: theme.iconTheme.color?.withOpacity(0.8)),
                title: Text(
                  "Compartilhar Versículo",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(modalContext); // Fecha o modal de opções
                  Navigator.push(
                    context, // Usa o contexto da página original
                    MaterialPageRoute(
                      builder: (context) => ImageSelectionPage(
                        verseText: verseText,
                        verseReference: "$bookAbbrev $chapter:$verseNum",
                      ),
                    ),
                  );
                },
              ),

              // Opção 3: Adicionar/Editar Nota
              ListTile(
                leading: Icon(
                  currentNote != null
                      ? Icons.edit_note_outlined
                      : Icons.note_add_outlined,
                  color: theme.iconTheme.color?.withOpacity(0.8),
                ),
                title: Text(
                  currentNote != null ? "Editar Nota" : "Adicionar Nota",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(modalContext);
                  showDialog(
                    context: context,
                    builder: (_) => NoteEditorModal(
                      verseId: verseId,
                      initialText: currentNote,
                      bookReference: "$bookAbbrev $chapter:$verseNum",
                      verseTextSample: verseText.isNotEmpty
                          ? verseText
                          : "[Conteúdo interlinear]",
                    ),
                  );
                },
              ),

              // Opção 4: Remover Nota (só aparece se houver uma nota)
              if (currentNote != null && currentNote.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.8)),
                  title: Text(
                    "Remover Nota",
                    style:
                        TextStyle(color: theme.colorScheme.error, fontSize: 15),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    store.dispatch(DeleteNoteAction(verseId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nota removida.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static void _showVerseLexiconModalHebrew(
    BuildContext context,
    String bookAbbrev,
    int chapter,
    int verseNum,
    String strongNumberWithPrefix,
    Map<String, dynamic>? hebrewLexicon,
  ) {
    final theme = Theme.of(context);
    if (hebrewLexicon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Léxico Hebraico não disponível.")));
      return;
    }

    final String strongNumberOnly =
        strongNumberWithPrefix.replaceAll(RegExp(r'^[Hc]/'), '');
    final lexiconEntry =
        hebrewLexicon[strongNumberOnly] as Map<String, dynamic>?;

    if (lexiconEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Definição para Strong $strongNumberWithPrefix não encontrada.")));
      return;
    }

    final String lemma = lexiconEntry['lemma_hebrew'] ?? 'N/A';
    final String translit = lexiconEntry['transliteration'] ?? 'N/A';
    final String hebrewWordInEntry =
        lexiconEntry['hebrew_word_in_entry'] ?? lemma;

    List<String> definitionsToShow = List<String>.from(
        lexiconEntry['definitions_pt'] as List<dynamic>? ?? []);
    if (definitionsToShow.isEmpty ||
        definitionsToShow
            .every((d) => d.toUpperCase().startsWith("TRADUZIR:"))) {
      definitionsToShow = List<String>.from(
          lexiconEntry['definitions'] as List<dynamic>? ?? ['N/A']);
    }

    Map<String, List<String>> notesToShow = {};
    final notesOriginal = lexiconEntry['notes'] as Map<String, dynamic>? ?? {};
    final notesPt = lexiconEntry['notes_pt'] as Map<String, dynamic>? ?? {};

    for (var key in ['exegesis', 'explanation', 'translation']) {
      String title = key.capitalizeFirstOfEach; // Usa a extensão
      List<String> ptList =
          List<String>.from(notesPt['${key}_pt'] as List<dynamic>? ?? []);
      List<String> origList =
          List<String>.from(notesOriginal[key] as List<dynamic>? ?? []);

      if (ptList.isNotEmpty &&
          !ptList.every((d) => d.toUpperCase().startsWith("TRADUZIR:"))) {
        notesToShow['$title (PT)'] = ptList;
      } else if (origList.isNotEmpty) {
        notesToShow['$title (Original)'] = origList;
      }
    }

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
            maxChildSize: 0.95,
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
                              borderRadius: BorderRadius.circular(10))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(children: [
                        Text(
                          "Léxico Hebraico: $strongNumberWithPrefix",
                          style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          hebrewWordInEntry,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                              fontFamily: 'NotoSansHebrew',
                              fontSize: 22,
                              color: theme.colorScheme.secondary),
                        ),
                      ]),
                    ),
                    Divider(color: theme.dividerColor, height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          Text("Lema: $lemma",
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 14)),
                          Text("Transliteração: $translit",
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          Text("Definições:",
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                          ...definitionsToShow.map((def) {
                            final String cleanedDef =
                                cleanLexiconEntry(def); // ✅ CORREÇÃO
                            if (cleanedDef.isEmpty)
                              return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("• ",
                                      style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      cleanedDef
                                          .capitalizeFirstOfEach, // Capitaliza a primeira letra
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 13,
                                        height:
                                            1.4, // Melhora o espaçamento entre linhas
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (notesToShow.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text("Notas Adicionais:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            // Mapeia e limpa cada nota antes de exibi-la
                            ...notesToShow.entries.expand((entry) => [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0, bottom: 2.0),
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ...entry.value.map((noteLine) {
                                    final String cleanedNote =
                                        cleanLexiconNote(noteLine);
                                    if (cleanedNote.isEmpty)
                                      return const SizedBox.shrink();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8.0, top: 2.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("- ",
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodySmall?.color)),
                                          Expanded(
                                            child: Text(
                                              cleanedNote,
                                              style: TextStyle(
                                                color: theme.textTheme
                                                    .bodyMedium?.color,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
      },
    );
  }

  static void _showVerseLexiconModalGreek(
    BuildContext context,
    String bookAbbrev,
    int chapter,
    int verseNum,
    String strongNumberClicked,
    Map<String, dynamic>? greekLexicon,
  ) {
    final theme = Theme.of(context);
    if (greekLexicon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Léxico Grego não disponível.")));
      return;
    }

    final lexiconEntry =
        greekLexicon[strongNumberClicked] as Map<String, dynamic>?;

    if (lexiconEntry == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Definição para Strong $strongNumberClicked não encontrada.")));
      return;
    }

    final String lemma = lexiconEntry['lemma_greek'] ?? 'N/A';
    final String translit = lexiconEntry['transliteration'] ?? 'N/A';
    final String pronunciation = lexiconEntry['pronunciation'] ?? 'N/A';

    List<String> definitionsToShow = List<String>.from(
        lexiconEntry['definitions_pt'] as List<dynamic>? ?? []);
    if (definitionsToShow.isEmpty ||
        definitionsToShow
            .every((d) => d.toUpperCase().startsWith("TRADUZIR:"))) {
      definitionsToShow = List<String>.from(
          lexiconEntry['definitions'] as List<dynamic>? ?? ['N/A']);
    }

    Map<String, List<String>> notesToShow = {};
    final notesOriginal = lexiconEntry['notes'] as Map<String, dynamic>? ?? {};
    final notesPt = lexiconEntry['notes_pt'] as Map<String, dynamic>? ?? {};

    List<String> derivationPtList =
        List<String>.from(notesPt['derivation_pt'] as List<dynamic>? ?? []);
    List<String> derivationOrigList =
        List<String>.from(notesOriginal['derivation'] as List<dynamic>? ?? []);
    if (derivationPtList.isNotEmpty &&
        !derivationPtList
            .every((d) => d.toUpperCase().startsWith("TRADUZIR:"))) {
      notesToShow['Derivação (PT)'] = derivationPtList;
    } else if (derivationOrigList.isNotEmpty) {
      notesToShow['Derivação (Original)'] = derivationOrigList;
    }

    List<String> kjvDefPtList =
        List<String>.from(notesPt['kjv_definition_pt'] as List<dynamic>? ?? []);
    List<String> kjvDefOrigList = List<String>.from(
        notesOriginal['kjv_definition'] as List<dynamic>? ?? []);
    if (kjvDefPtList.isNotEmpty &&
        !kjvDefPtList.every((d) => d.toUpperCase().startsWith("TRADUZIR:"))) {
      notesToShow['Definição KJV (PT)'] = kjvDefPtList;
    } else if (kjvDefOrigList.isNotEmpty) {
      notesToShow['Definição KJV (Original)'] = kjvDefOrigList;
    }

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
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                    color: theme.dialogBackgroundColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16))),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        "Léxico Grego: $strongNumberClicked",
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (lemma != 'N/A')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(lemma,
                            style: TextStyle(
                                fontSize: 22,
                                color: theme.colorScheme.secondary),
                            textAlign: TextAlign.center),
                      ),
                    Divider(color: theme.dividerColor, height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          Text("Transliteração: $translit",
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 14)),
                          Text("Pronúncia: $pronunciation",
                              style: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontSize: 14)),
                          const SizedBox(height: 10),
                          Text("Definições:",
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500)),
                          ...definitionsToShow.map((def) {
                            final String cleanedDef =
                                cleanLexiconEntry(def); // ✅ CORREÇÃO
                            if (cleanedDef.isEmpty)
                              return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("• ",
                                      style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      cleanedDef.capitalizeFirstOfEach,
                                      style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (notesToShow.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text("Notas Adicionais:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            ...notesToShow.entries.expand((entry) => [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0, bottom: 2.0),
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ...entry.value.map((noteLine) {
                                    final String cleanedNote = cleanLexiconNote(
                                        noteLine); // ✅ CORREÇÃO
                                    if (cleanedNote.isEmpty)
                                      return const SizedBox.shrink();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8.0, top: 2.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("- ",
                                              style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodySmall?.color)),
                                          Expanded(
                                            child: Text(
                                              cleanedNote,
                                              style: TextStyle(
                                                color: theme.textTheme
                                                    .bodyMedium?.color,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ]),
                          ],
                          if (lexiconEntry['greek_references'] != null &&
                              (lexiconEntry['greek_references'] as List)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text("Referências Gregas:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text(
                                  (lexiconEntry['greek_references'] as List)
                                      .join(', '),
                                  style: TextStyle(
                                      color: theme.textTheme.bodySmall?.color,
                                      fontSize: 12)),
                            )
                          ],
                          if (lexiconEntry['hebrew_references'] != null &&
                              (lexiconEntry['hebrew_references'] as List)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text("Referências Hebraicas:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, top: 2.0),
                              child: Text(
                                  (lexiconEntry['hebrew_references'] as List)
                                      .join(', '),
                                  style: TextStyle(
                                      color: theme.textTheme.bodySmall?.color,
                                      fontSize: 12)),
                            )
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            });
      },
    );
  }

  static void _showViewNoteDialog(
      BuildContext context, String verseReference, String noteText) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: Text(
          "Nota para $verseReference",
          style: TextStyle(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            noteText,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Fechar"),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}

// Extensão para capitalizar a primeira letra de cada palavra
extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}

class _TranslationSelectionModalContent extends StatefulWidget {
  final String selectedTranslation;
  final Function(String) onTranslationSelected;
  final String? currentSelectedBookAbbrev;
  final Map<String, dynamic>? booksMap;
  final bool isPremium;
  final VoidCallback onToggleCompareMode;

  const _TranslationSelectionModalContent({
    required this.selectedTranslation,
    required this.onTranslationSelected,
    this.currentSelectedBookAbbrev,
    this.booksMap,
    required this.isPremium,
    required this.onToggleCompareMode,
  });

  @override
  State<_TranslationSelectionModalContent> createState() =>
      __TranslationSelectionModalContentState();
}

class __TranslationSelectionModalContentState
    extends State<_TranslationSelectionModalContent> {
  bool _isDetailedView = false;
  late Future<List<BibleVersionMeta>> _versionsMetaFuture;

  @override
  void initState() {
    super.initState();
    _versionsMetaFuture = BibleVersionService.instance.getVersions();
  }

  Widget _buildDetailedVersionTile(
      BibleVersionMeta meta, bool isSelected, ThemeData theme) {
    return InkWell(
      onTap: () {
        widget.onTranslationSelected(meta.id);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone de check para a versão selecionada
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Conteúdo principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha com Nome Completo e Ano
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          meta.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      Text(
                        "Ano: ${meta.year}",
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Descrição
                  Text(
                    meta.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // --- Barra Superior com Ações ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.compare_arrows_outlined, size: 20),
                      label: const Text("Comparar"),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onToggleCompareMode();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyLarge?.color,
                        side: BorderSide(color: theme.dividerColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isDetailedView
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined),
                      tooltip: _isDetailedView
                          ? "Visão Compacta"
                          : "Visão Detalhada",
                      onPressed: () {
                        setState(() {
                          _isDetailedView = !_isDetailedView;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- Corpo do Modal (Lista ou Grade) ---
              Expanded(
                child: FutureBuilder<List<BibleVersionMeta>>(
                  future: _versionsMetaFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final versionsMeta = snapshot.data!;

                    if (_isDetailedView) {
                      // --- VISÃO DETALHADA (LISTA) ---
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: versionsMeta.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, indent: 24, endIndent: 24),
                        itemBuilder: (context, index) {
                          final meta = versionsMeta[index];
                          final isSelected = meta.id.toUpperCase() ==
                              widget.selectedTranslation.toUpperCase();
                          // <<< USA O NOVO WIDGET AQUI >>>
                          return _buildDetailedVersionTile(
                              meta, isSelected, theme);
                        },
                      );
                    } else {
                      // --- VISÃO COMPACTA (GRADE) ---
                      return SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24), // Mais espaçamento
                        child: Wrap(
                          spacing: 12.0, // Espaçamento horizontal
                          runSpacing: 12.0, // Espaçamento vertical
                          alignment: WrapAlignment.center,
                          children: versionsMeta.map((meta) {
                            return BiblePageWidgets.buildTranslationButton(
                              context: context,
                              translationKey: meta.id,
                              translationLabel: meta.id,
                              selectedTranslation: widget.selectedTranslation,
                              onPressed: () {
                                widget.onTranslationSelected(meta.id);
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
