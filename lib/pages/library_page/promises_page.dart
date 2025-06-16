// lib/pages/library_page/promises_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/promise_model.dart'; // Importe seus modelos

class PromisesPage extends StatefulWidget {
  const PromisesPage({super.key});

  @override
  State<PromisesPage> createState() => _PromisesPageState();
}

class _PromisesPageState extends State<PromisesPage> {
  Future<PromiseBook>? _promiseBookFuture;

  @override
  void initState() {
    super.initState();
    _promiseBookFuture = _loadPromisesData();
  }

  Future<PromiseBook> _loadPromisesData() async {
    try {
      // Certifique-se que o caminho para o seu JSON está correto
      final String jsonString =
          await rootBundle.loadString('assets/promises/promessas.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return PromiseBook.fromJson(jsonData);
    } catch (e) {
      print("Erro ao carregar as promessas: $e");
      throw Exception('Falha ao carregar dados das promessas');
    }
  }

  Widget _buildVerseWidget(PromiseVerse verse, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            verse.text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              verse.reference,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Promessas da Bíblia"),
      ),
      body: FutureBuilder<PromiseBook>(
        future: _promiseBookFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text("Erro ao carregar promessas: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Nenhuma promessa encontrada."));
          }

          final promiseBook = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: promiseBook.parts.length,
            itemBuilder: (context, partIndex) {
              final part = promiseBook.parts[partIndex];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0)),
                child: ExpansionTile(
                  key: PageStorageKey('part_${part.partNumber}'),
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.05),
                  collapsedBackgroundColor: theme.cardColor.withOpacity(0.8),
                  iconColor: theme.colorScheme.primary,
                  collapsedIconColor:
                      theme.colorScheme.primary.withOpacity(0.7),
                  title: Text(
                    part.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary, fontSize: 18),
                  ),
                  children: part.chapters.map<Widget>((chapter) {
                    return ExpansionTile(
                      key: PageStorageKey(
                          'part_${part.partNumber}_chapter_${chapter.chapterNumber}'),
                      tilePadding: const EdgeInsets.only(
                          left: 24.0, right: 16.0), // Indentação para capítulos
                      title: Text(
                        "${chapter.chapterNumber}. ${chapter.title}",
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      children: chapter.sections.map<Widget>((section) {
                        if (section.subsections != null &&
                            section.subsections!.isNotEmpty) {
                          // Seção com subseções
                          return ExpansionTile(
                            key: PageStorageKey(
                                'part_${part.partNumber}_chapter_${chapter.chapterNumber}_section_${section.sectionNumber}'),
                            tilePadding: const EdgeInsets.only(
                                left: 40.0, right: 16.0), // Maior indentação
                            title: Text(
                              "${section.sectionNumber}. ${section.title}",
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: theme.colorScheme.primary),
                            ),
                            children:
                                section.subsections!.map<Widget>((subsection) {
                              return ExpansionTile(
                                key: PageStorageKey(
                                    'part_${part.partNumber}_chapter_${chapter.chapterNumber}_section_${section.sectionNumber}_subsection_${subsection.title.hashCode}'),
                                tilePadding: const EdgeInsets.only(
                                    left: 56.0,
                                    right: 16.0), // Ainda maior indentação
                                title: Text(
                                  subsection.title,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                children: subsection.verses
                                    .map((verse) =>
                                        _buildVerseWidget(verse, theme))
                                    .toList(),
                              );
                            }).toList(),
                          );
                        } else if (section.verses != null &&
                            section.verses!.isNotEmpty) {
                          // Seção sem subseções, mas com versículos diretos
                          return ExpansionTile(
                            key: PageStorageKey(
                                'part_${part.partNumber}_chapter_${chapter.chapterNumber}_section_${section.sectionNumber}'),
                            tilePadding:
                                const EdgeInsets.only(left: 40.0, right: 16.0),
                            title: Text(
                              "${section.sectionNumber}. ${section.title}",
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(color: theme.colorScheme.primary),
                            ),
                            children: section.verses!
                                .map((verse) => _buildVerseWidget(verse, theme))
                                .toList(),
                          );
                        }
                        // Seção sem versos diretos e sem subseções (apenas título)
                        return ListTile(
                          contentPadding:
                              const EdgeInsets.only(left: 40.0, right: 16.0),
                          title: Text(
                            "${section.sectionNumber}. ${section.title}",
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: theme.colorScheme.secondary),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
