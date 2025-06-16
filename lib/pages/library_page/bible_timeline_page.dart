// lib/pages/library_page/bible_timeline_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// Modelo simples para os dados da linha do tempo
class TimelineData {
  final String timelineTitle;
  final List<dynamic> keyEntries;
  final List<dynamic> timePeriods;

  TimelineData({
    required this.timelineTitle,
    required this.keyEntries,
    required this.timePeriods,
  });

  factory TimelineData.fromJson(Map<String, dynamic> json) {
    return TimelineData(
      timelineTitle: json['timelineTitle'] ?? 'Linha do Tempo Bíblica',
      keyEntries: List<dynamic>.from(json['key'] ?? []),
      timePeriods: List<dynamic>.from(json['timePeriods'] ?? []),
    );
  }
}

class BibleTimelinePage extends StatefulWidget {
  const BibleTimelinePage({super.key});

  @override
  State<BibleTimelinePage> createState() => _BibleTimelinePageState();
}

class _BibleTimelinePageState extends State<BibleTimelinePage> {
  Future<TimelineData>? _timelineDataFuture;

  @override
  void initState() {
    super.initState();
    _timelineDataFuture = _loadTimelineData();
  }

  Future<TimelineData> _loadTimelineData() async {
    try {
      final String jsonString = await rootBundle
          .loadString('assets/timelines/timeline_full_bible_pt.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return TimelineData.fromJson(jsonData);
    } catch (e) {
      print("Erro ao carregar a linha do tempo: $e");
      throw Exception('Falha ao carregar dados da linha do tempo');
    }
  }

  Widget _buildEventWidget(Map<String, dynamic> event, ThemeData theme) {
    final String eventName = event['event'] as String? ?? 'Evento Desconhecido';
    final String date = event['date'] as String? ?? '';
    final String? details = event['details'] as String?;
    final String? notes = event['notes'] as String?;
    final String? imageDescription = event['image_description'] as String?;
    final List<dynamic>? subEvents = event['sub_events'] as List<dynamic>?;
    final List<dynamic>? rulersMentioned =
        event['rulers_mentioned'] as List<dynamic>?;
    final String? type = event['type'] as String?;
    final String? region = event['region'] as String?;

    if (type == 'lineage_chart') {
      final List<dynamic> individuals =
          event['individuals'] as List<dynamic>? ?? [];
      final String? chartNote = event['chart_note'] as String?;
      return Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        color: theme.cardColor.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
        child: ExpansionTile(
          key: PageStorageKey(eventName),
          iconColor: theme.colorScheme.primary,
          collapsedIconColor: theme.colorScheme.primary.withOpacity(0.7),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          title: Text(eventName,
              style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary)),
          childrenPadding: const EdgeInsets.only(
              left: 12.0, right: 12.0, bottom: 12.0, top: 4.0),
          children: [
            ...individuals.map<Widget>((ind) {
              final item = ind as Map<String, dynamic>; // Cast para Map
              final String name = item['name'] ?? 'N/A';
              final int? age = item['age'] as int?;
              final String? indNotes = item['notes'] as String?;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                title: Text(name, style: theme.textTheme.bodyMedium),
                trailing: age != null
                    ? Text("Idade: $age", style: theme.textTheme.bodySmall)
                    : null,
                subtitle: indNotes != null
                    ? Text(indNotes,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic))
                    : null,
              );
            }).toList(),
            if (chartNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(chartNote,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      color: theme.cardColor.withOpacity(0.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6.0)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    eventName,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary),
                  ),
                ),
                if (region != null && region.isNotEmpty)
                  Chip(
                    label: Text(region,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer)),
                    backgroundColor:
                        theme.colorScheme.secondaryContainer.withOpacity(0.6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  )
              ],
            ),
            if (date.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
                ),
              ),
            if (details != null) ...[
              const SizedBox(height: 4),
              Text(details, style: theme.textTheme.bodyMedium),
            ],
            if (notes != null) ...[
              const SizedBox(height: 4),
              Text("Nota: $notes",
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],
            if (imageDescription != null) ...[
              const SizedBox(height: 4),
              Text("Imagem: $imageDescription",
                  style:
                      theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
            ],
            if (subEvents != null && subEvents.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: subEvents
                      .map((sub) => Text("• ${sub as String}",
                          style: theme.textTheme.bodySmall))
                      .toList(),
                ),
              )
            ],
            if (rulersMentioned != null && rulersMentioned.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 0.0, bottom: 4.0),
                child: Text("Governantes/Eventos Relevantes:",
                    style: theme.textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
              ),
              ...rulersMentioned.map<Widget>((rulerItem) {
                final ruler = rulerItem as Map<String, dynamic>;
                final String name = ruler['name'] ?? 'N/A';
                final String? reign = ruler['reign'] as String?;
                final String? itemNotes = ruler['notes'] as String?;
                final String? itemImageDesc =
                    ruler['image_description'] as String?;

                return Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 2.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                          text: TextSpan(
                              style: theme.textTheme
                                  .bodyMedium, // Estilo padrão para RichText
                              children: [
                            TextSpan(
                                text: "• $name",
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500)),
                            if (reign != null)
                              TextSpan(
                                  text: " ($reign)",
                                  style: theme.textTheme.bodySmall)
                          ])),
                      if (itemNotes != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0, top: 1.0),
                          child: Text(itemNotes,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic)),
                        ),
                      if (itemImageDesc != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 12.0, top: 1.0),
                          child: Text("Imagem: $itemImageDesc",
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: Colors.grey)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Linha do Tempo Bíblica"),
      ),
      body: FutureBuilder<TimelineData>(
        future: _timelineDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child:
                    Text("Erro ao carregar linha do tempo: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text("Nenhum dado encontrado para a linha do tempo."));
          }

          final timelineData = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: timelineData.timePeriods.length + 1, // +1 para a legenda
            itemBuilder: (context, index) {
              if (index == 0) {
                // Constrói a seção da legenda
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.all(8.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Legenda",
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: theme.colorScheme.primary)),
                        const SizedBox(height: 10),
                        ...(timelineData.keyEntries).map<Widget>((entry) {
                          final item = entry as Map<String, dynamic>;
                          final String? symbol = item['symbol'] as String?;
                          final String? description =
                              item['description'] as String?;
                          final String? note = item['note'] as String?;

                          if (symbol != null && description != null) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("$symbol: ",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  Expanded(
                                      child: Text(description,
                                          style: theme.textTheme.bodyMedium)),
                                ],
                              ),
                            );
                          } else if (note != null) {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 2.0),
                              child: Text(
                                note,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }).toList(),
                      ],
                    ),
                  ),
                );
              }

              // Constrói os períodos de tempo
              final period =
                  timelineData.timePeriods[index - 1] as Map<String, dynamic>;
              final String periodName =
                  period['periodName'] ?? 'Período Desconhecido';
              final String booksContext = period['biblicalBooksContext'] ?? '';
              final List<dynamic> eventsRaw =
                  period['events'] as List<dynamic>? ?? [];

              Map<String, List<Map<String, dynamic>>> eventsByCategory = {};
              for (var eventDataRaw in eventsRaw) {
                if (eventDataRaw is Map<String, dynamic>) {
                  final String category =
                      eventDataRaw['category'] as String? ?? 'Outros Eventos';
                  eventsByCategory
                      .putIfAbsent(category, () => [])
                      .add(eventDataRaw);
                }
              }

              List<String> categoryOrder = [
                "História Bíblica",
                "História do Oriente Médio",
                "História Mundial",
                "Visuals", // Adicionando Visuals se for uma categoria que você quer listar
              ];

              return Card(
                elevation: 2,
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0)),
                child: ExpansionTile(
                  key: PageStorageKey(periodName),
                  backgroundColor:
                      theme.colorScheme.surfaceVariant.withOpacity(0.05),
                  collapsedBackgroundColor: theme.cardColor.withOpacity(0.8),
                  iconColor: theme.colorScheme.primary,
                  collapsedIconColor:
                      theme.colorScheme.primary.withOpacity(0.7),
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  title: Text(
                    periodName,
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary, fontSize: 18),
                  ),
                  subtitle: booksContext.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Contexto: $booksContext",
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.8)),
                          ),
                        )
                      : null,
                  childrenPadding: const EdgeInsets.symmetric(
                      vertical: 0.0, horizontal: 0.0),
                  children: categoryOrder
                      .where((catName) => eventsByCategory.containsKey(catName))
                      .map<Widget>((categoryName) {
                    final List<Map<String, dynamic>> categoryEvents =
                        eventsByCategory[categoryName]!;
                    return Padding(
                      padding: const EdgeInsets.only(
                          top: 8.0, bottom: 4.0, left: 8.0, right: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6.0, horizontal: 8.0),
                            child: Text(
                              categoryName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Divider(
                            color: theme.dividerColor.withOpacity(0.2),
                            height: 1,
                            indent: 8,
                            endIndent: 8,
                          ),
                          const SizedBox(height: 4),
                          ...categoryEvents.map<Widget>((eventData) {
                            return _buildEventWidget(eventData, theme);
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList()
                    ..addAll(eventsByCategory.keys
                        .where((catName) => !categoryOrder.contains(catName))
                        .map<Widget>((categoryName) {
                      final List<Map<String, dynamic>> categoryEvents =
                          eventsByCategory[categoryName]!;
                      return Padding(
                        padding: const EdgeInsets.only(
                            top: 8.0, bottom: 4.0, left: 8.0, right: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6.0, horizontal: 8.0),
                              child: Text(categoryName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Divider(
                              color: theme.dividerColor.withOpacity(0.2),
                              height: 1,
                              indent: 8,
                              endIndent: 8,
                            ),
                            const SizedBox(height: 4),
                            ...categoryEvents
                                .map<Widget>((eventData) =>
                                    _buildEventWidget(eventData, theme))
                                .toList(),
                          ],
                        ),
                      );
                    }).toList()),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
