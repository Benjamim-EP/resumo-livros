// lib/pages/library_page/church_history_index_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/church_history_model.dart';
import 'package:septima_biblia/pages/library_page/church_history_volume_page.dart';

class ChurchHistoryIndexPage extends StatefulWidget {
  const ChurchHistoryIndexPage({super.key});

  @override
  State<ChurchHistoryIndexPage> createState() => _ChurchHistoryIndexPageState();
}

class _ChurchHistoryIndexPageState extends State<ChurchHistoryIndexPage> {
  Future<List<ChurchHistoryVolume>>? _volumesFuture;

  @override
  void initState() {
    super.initState();
    _volumesFuture = _loadData();
  }

  Future<List<ChurchHistoryVolume>> _loadData() async {
    try {
      final String jsonString = await rootBundle.loadString(
          'assets/timelines/historia_da_igreja.json'); // **ATENÇÃO: Corrija o caminho do seu JSON aqui**
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => ChurchHistoryVolume.fromJson(json))
          .toList();
    } catch (e) {
      print("Erro ao carregar a História da Igreja: $e");
      throw Exception('Falha ao carregar dados');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("História da Igreja"),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: FutureBuilder<List<ChurchHistoryVolume>>(
        future: _volumesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum volume encontrado."));
          }

          final volumes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: volumes.length,
            itemBuilder: (context, index) {
              final volume = volumes[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 15.0),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary),
                    ),
                  ),
                  title: Text(
                    volume.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChurchHistoryVolumePage(volume: volume),
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
