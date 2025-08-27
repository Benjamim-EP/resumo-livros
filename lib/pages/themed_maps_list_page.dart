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
  late Future<List<ThemedJourney>> _journeysFuture;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _journeysFuture = _loadJourneys();
  }

  Future<List<ThemedJourney>> _loadJourneys() async {
    final data = await _firestoreService.getThemedMapsData("pauls_journeys");
    if (data == null) return [];

    final List<dynamic> journeysList = data['journeys'] ?? [];
    return journeysList.map((j) => ThemedJourney.fromJson(j)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mapas Temáticos"),
      ),
      body: FutureBuilder<List<ThemedJourney>>(
        future: _journeysFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum mapa encontrado."));
          }

          final journeys = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: journeys.length,
            itemBuilder: (context, index) {
              final journey = journeys[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: journey.color,
                    child: const Icon(Icons.route, color: Colors.white),
                  ),
                  title:
                      Text(journey.title, style: theme.textTheme.titleMedium),
                  subtitle: Text(journey.description,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BibleMapPage(
                          // Passamos a jornada completa em vez de um chapterId
                          themedJourney: journey,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
