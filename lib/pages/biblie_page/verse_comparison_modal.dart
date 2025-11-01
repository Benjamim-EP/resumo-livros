// lib/pages/biblie_page/verse_comparison_modal.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';

class VerseComparisonModal extends StatefulWidget {
  final String verseId;
  final String verseReference;

  const VerseComparisonModal({
    super.key,
    required this.verseId,
    required this.verseReference,
  });

  @override
  State<VerseComparisonModal> createState() => _VerseComparisonModalState();
}

class _VerseComparisonModalState extends State<VerseComparisonModal> {
  late Future<Map<String, String>> _translationsFuture;

  @override
  void initState() {
    super.initState();
    _translationsFuture =
        BiblePageHelper.loadSingleVerseAcrossAllTranslations(widget.verseId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Comparar: ${widget.verseReference}"),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _translationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text("Erro ao carregar traduções: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhuma tradução encontrada."));
          }

          final translations = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: translations.length,
            separatorBuilder: (context, index) => Divider(
              color: theme.dividerColor.withOpacity(0.5),
              height: 32,
            ),
            itemBuilder: (context, index) {
              final key = translations.keys.elementAt(index);
              final text = translations.values.elementAt(index);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(key), // NVI, ACF, etc.
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    text,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(height: 1.5, fontSize: 18),
                    textAlign: TextAlign.justify,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
