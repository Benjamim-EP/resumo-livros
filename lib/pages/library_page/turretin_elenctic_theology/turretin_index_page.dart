// lib/pages/library_page/turretin_elenctic_theology/turretin_index_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:septima_biblia/models/turretin_theology_model.dart';
import 'package:septima_biblia/pages/library_page/turretin_elenctic_theology/turretin_topic_page.dart';

class TurretinIndexPage extends StatefulWidget {
  const TurretinIndexPage({super.key});

  @override
  State<TurretinIndexPage> createState() => _TurretinIndexPageState();
}

class _TurretinIndexPageState extends State<TurretinIndexPage> {
  Future<List<ElencticTopic>>? _topicsFuture;

  @override
  void initState() {
    super.initState();
    _topicsFuture = _loadData();
  }

  Future<List<ElencticTopic>> _loadData() async {
    try {
      // ATENÇÃO: Verifique se o caminho do seu JSON está correto
      final String jsonString =
          await rootBundle.loadString('assets/turretin/elenctic_theology.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => ElencticTopic.fromJson(json)).toList();
    } catch (e) {
      print("Erro ao carregar a Teologia Elêntica: $e");
      throw Exception('Falha ao carregar dados');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Institutas de Turretin"),
      ),
      body: FutureBuilder<List<ElencticTopic>>(
        future: _topicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Erro: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Nenhum tópico encontrado."));
          }

          final topics = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topic = topics[index];
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
                      '${index + 1}', // Numeração simples
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary),
                    ),
                  ),
                  title: Text(
                    topic.topicTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TurretinTopicPage(topic: topic),
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
