// lib/pages/biblie_page/bible_page_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/biblie_page/highlight_editor_dialog.dart';
import 'package:septima_biblia/pages/biblie_page/tag_editor_dialog.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/saveVerseDialog.dart';
import 'package:septima_biblia/pages/biblie_page/note_editor_modal.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';

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
  }) {
    final theme = Theme.of(context);
    bool isOldTestament = false;
    bool isNewTestament = false;

    if (currentSelectedBookAbbrev != null &&
        booksMap != null &&
        booksMap.containsKey(currentSelectedBookAbbrev)) {
      final bookData =
          booksMap[currentSelectedBookAbbrev] as Map<String, dynamic>?;
      if (bookData != null) {
        if (bookData['testament'] == 'Antigo')
          isOldTestament = true;
        else if (bookData['testament'] == 'Novo') isNewTestament = true;
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
          }),
      buildTranslationButton(
          context: context,
          translationKey: 'aa',
          translationLabel: 'AA',
          selectedTranslation: selectedTranslation,
          onPressed: () {
            onTranslationSelected('aa');
            Navigator.pop(context);
          }),
      buildTranslationButton(
          context: context,
          translationKey: 'acf',
          translationLabel: 'ACF',
          selectedTranslation: selectedTranslation,
          onPressed: () {
            onTranslationSelected('acf');
            Navigator.pop(context);
          }),
    ];

    if (isOldTestament) {
      translationButtons.add(buildTranslationButton(
        context: context,
        translationKey: 'hebrew_original',
        translationLabel: 'Hebraico (Orig.)',
        selectedTranslation: selectedTranslation,
        onPressed: () => isPremium
            ? onTranslationSelected('hebrew_original')
            : _showPremiumDialog(context),
        isPremiumFeature: true,
        isPremiumUser: isPremium,
      ));
    }

    if (isNewTestament) {
      translationButtons.add(buildTranslationButton(
        context: context,
        translationKey: 'greek_interlinear',
        translationLabel: 'Grego (Interlinear)',
        selectedTranslation: selectedTranslation,
        onPressed: () => isPremium
            ? onTranslationSelected('greek_interlinear')
            : _showPremiumDialog(context),
        isPremiumFeature: true,
        isPremiumUser: isPremium,
      ));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Escolha a Tradução",
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
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
    String firstFullDefinition = definitions.first.toString().trim();
    String cleanedDefinition =
        firstFullDefinition.replaceFirst(RegExp(r'^\d+\s*[.)]\s*'), '');

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
    String shortDefinition = "N/A";

    if (strongNumber.isNotEmpty &&
        strongNumber != "N/A" &&
        greekLexicon != null) {
      final lexiconEntry = greekLexicon[strongNumber] as Map<String, dynamic>?;
      if (lexiconEntry != null) {
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
    final double baseStrongFontSize =
        10.0; // Ajustado para apenas o número de Strong
    final double baseDefinitionFontSize = 9.0;

    return GestureDetector(
      onTap: () {
        if (strongNumber.isNotEmpty && strongNumber != "N/A") {
          _showVerseLexiconModalGreek(
            context,
            selectedBook!,
            selectedChapter!,
            verseNumber,
            strongNumber,
            greekLexicon,
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              greekText,
              style: TextStyle(
                fontSize: baseGreekFontSize * fontSizeMultiplier,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            if (strongNumber.isNotEmpty && strongNumber != "N/A")
              Text(
                strongNumber,
                style: TextStyle(
                  fontSize: baseStrongFontSize * fontSizeMultiplier,
                  color: theme.colorScheme.secondary.withOpacity(0.8),
                ),
              ),
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
    required List<String> allUserTags, // <<< PARÂMETRO ADICIONADO
    required double fontSizeMultiplier,
    bool isHebrew = false,
    bool isGreekInterlinear = false,
    bool showHebrewInterlinear = false,
    bool showGreekInterlinear = false,
    List<Map<String, String>>? hebrewVerseData,
    List<Map<String, String>>? greekVerseData,
  }) {
    final theme = Theme.of(context);
    final verseId = "${selectedBook}_${selectedChapter}_$verseNumber";

    final Map<String, dynamic>? currentHighlightData = userHighlights[verseId];
    final String? currentHighlightColorHex =
        currentHighlightData?['color'] as String?;
    final bool hasNote = userNotes.any((note) => note['verseId'] == verseId);
    final backgroundColor = currentHighlightColorHex != null
        ? Color(int.parse(currentHighlightColorHex.replaceFirst('#', '0xff')))
            .withOpacity(0.30)
        : Colors.transparent;

    String verseTextForModalDialog = "";
    Widget mainTranslationWidget;

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
          runSpacing: 4.0,
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

    // A lógica de obter os dados foi movida para o topo da função
    // para estar disponível tanto para a decoração quanto para o `onLongPress`.

    return GestureDetector(
      key: key,
      onLongPress: () {
        String? currentNoteText;
        if (hasNote) {
          // Usa 'firstWhere' para encontrar o mapa da nota e pegar o texto
          currentNoteText = userNotes.firstWhere(
            (note) => note['verseId'] == verseId,
            orElse: () => {}, // Retorna mapa vazio se não encontrar
          )['noteText'] as String?;
        }
        // <<< MUDANÇA: Parâmetros agora são nomeados >>>
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
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        margin: const EdgeInsets.symmetric(vertical: 1.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
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
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 5.0, right: 2.0, top: 2.0),
                    child: Icon(Icons.note_alt_rounded,
                        color: theme.colorScheme.primary.withOpacity(0.8),
                        size: 16 * fontSizeMultiplier),
                  ),
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
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      verseText.isNotEmpty
                          ? verseText
                          : "[Conteúdo interlinear]",
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          fontStyle: FontStyle.italic,
                          fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Divider(color: theme.dividerColor.withOpacity(0.5), height: 20),
              ListTile(
                leading: Icon(Icons.format_paint_outlined,
                    color: currentHighlightColor != null
                        ? Color(int.parse(
                            currentHighlightColor.replaceFirst('#', '0xff')))
                        : theme.iconTheme.color?.withOpacity(0.8)),
                title: Text(
                    currentHighlightColor != null
                        ? "Editar Destaque/Tags"
                        : "Destacar Versículo",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 15)),
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
              ListTile(
                leading: Icon(
                    currentNote != null
                        ? Icons.edit_note_outlined
                        : Icons.note_add_outlined,
                    color: theme.iconTheme.color?.withOpacity(0.8)),
                title: Text(
                    currentNote != null ? "Editar Nota" : "Adicionar Nota",
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 15)),
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
              if (currentNote != null && currentNote.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.8)),
                  title: Text("Remover Nota",
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 15)),
                  onTap: () {
                    Navigator.pop(modalContext);
                    store.dispatch(DeleteNoteAction(verseId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Nota removida.'),
                          duration: Duration(seconds: 2)),
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
                          ...definitionsToShow.map((def) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 8.0, top: 2.0),
                                child: Text("• $def",
                                    style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 13)),
                              )),
                          if (notesToShow.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text("Notas Adicionais:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            ...notesToShow.entries.expand((entry) => [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6.0, bottom: 2.0),
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ...entry.value.map((noteLine) => Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8.0, top: 2.0),
                                        child: Text("• $noteLine",
                                            style: TextStyle(
                                                color: theme.textTheme
                                                    .bodyMedium?.color,
                                                fontSize: 13)),
                                      )),
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
                          ...definitionsToShow.map((def) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 8.0, top: 2.0),
                                child: Text("• $def",
                                    style: TextStyle(
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontSize: 13)),
                              )),
                          if (notesToShow.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text("Notas Adicionais:",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                            ...notesToShow.entries.expand((entry) => [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6.0, bottom: 2.0),
                                    child: Text(entry.key,
                                        style: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(0.85),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  ...entry.value.map((noteLine) => Padding(
                                        padding: const EdgeInsets.only(
                                            left: 8.0, top: 2.0),
                                        child: Text("• $noteLine",
                                            style: TextStyle(
                                                color: theme.textTheme
                                                    .bodyMedium?.color,
                                                fontSize: 13)),
                                      )),
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
}

// Extensão para capitalizar a primeira letra de cada palavra
extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
