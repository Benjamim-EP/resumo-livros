// lib/pages/library_page/themed_maps_list_page.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/models/themed_map_model.dart';
import 'package:septima_biblia/pages/bible_map_page.dart';
import 'package:septima_biblia/services/firestore_service.dart';

class ThemedMapsListPage extends StatefulWidget {
  const ThemedMapsListPage({super.key});

  @override
  State<ThemedMapsListPage> createState() => _ThemedMapsListPageState();
}

class _ThemedMapsListPageState extends State<ThemedMapsListPage> {
  // O Future agora busca uma lista de categorias de mapa
  late Future<List<ThemedMapCategory>> _categoriesFuture;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadMapCategories();
  }

  // A função agora busca as categorias
  Future<List<ThemedMapCategory>> _loadMapCategories() async {
    // Por enquanto, buscamos apenas um documento, mas a estrutura suporta mais
    final paulsJourneyData =
        await _firestoreService.getThemedMapCategory("pauls_journeys");

    final List<ThemedMapCategory> categories = [];
    if (paulsJourneyData != null) {
      categories.add(ThemedMapCategory.fromFirestore(paulsJourneyData));
    }
    // No futuro, você poderia buscar outros documentos aqui e adicionar à lista.

    return categories;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapas Temáticos"),
      ),
      body: FutureBuilder<List<ThemedMapCategory>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum mapa encontrado."));
          }

          final categories = snapshot.data!;

          // O ListView agora constrói ExpansionTiles para cada categoria
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ExpansionTile(
                  // Começa expandido por padrão
                  initiallyExpanded: true,
                  title:
                      Text(category.title, style: theme.textTheme.titleLarge),
                  children: category.journeys.map((journey) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: journey.color.withOpacity(0.2),
                        child: Icon(Icons.route, color: journey.color),
                      ),
                      title: Text(journey.title,
                          style: theme.textTheme.titleMedium),
                      subtitle: Text(journey.description,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BibleMapPage(
                              themedJourney: journey,
                            ),
                          ),
                        );
                      },
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
