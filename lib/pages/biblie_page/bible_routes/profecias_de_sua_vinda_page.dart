import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfeciasDeSuaVindaPage extends StatefulWidget {
  final List<dynamic> profecias;

  const ProfeciasDeSuaVindaPage({super.key, required this.profecias});

  @override
  _ProfeciasDeSuaVindaPageState createState() => _ProfeciasDeSuaVindaPageState();
}

class _ProfeciasDeSuaVindaPageState extends State<ProfeciasDeSuaVindaPage> {
  Map<String, dynamic>? abbrevMap; // Mapa de abreviações da Bíblia

  @override
  void initState() {
    super.initState();
    _loadAbbrevMap();
  }

  Future<void> _loadAbbrevMap() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Biblia/completa_traducoes/abbrev_map.json');
      setState(() {
        abbrevMap = json.decode(jsonString);
      });
    } catch (e) {
      print("Erro ao carregar abbrev_map.json: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profecias de Sua Vinda"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: abbrevMap == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.profecias.length,
              itemBuilder: (context, index) {
                final profecia = widget.profecias[index];

                return Card(
                  color: const Color(0xFF272828),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.all(16),
                    iconColor: Colors.white,
                    title: Text(
                      profecia['profecia'],
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    children: [
                      _buildSection("Antigo Testamento", profecia['referencias_antigo_testamento']),
                      _buildSection("Novo Testamento", profecia['cumprimento_novo_testamento']),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSection(String title, List<dynamic>? referencias) {
    if (referencias == null || referencias.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...referencias.map((ref) => _buildReferenceTile(ref)).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReferenceTile(String reference) {
    return FutureBuilder<List<String>>(
      future: _loadVerses(reference),
      builder: (context, snapshot) {
        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            "• $reference",
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          children: snapshot.hasData
              ? snapshot.data!.map((verse) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
                    child: Text(
                      verse,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  );
                }).toList()
              : [
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ],
        );
      },
    );
  }

  Future<List<String>> _loadVerses(String reference) async {
    try {
      if (abbrevMap == null) return [];

      final match = RegExp(r'([^\d]+)\s(\d+):(\d+)(?:-(\d+))?').firstMatch(reference);
      if (match == null) return [];

      final bookName = match.group(1)?.trim();
      final chapter = match.group(2);
      final startVerse = match.group(3);
      final endVerse = match.group(4);

      if (bookName == null || chapter == null || startVerse == null) return [];

      // 🔹 Encontrar a abreviação correta do livro no abbrev_map.json
      String? bookAbbrev;
      abbrevMap!.forEach((key, value) {
        if (value["nome"] == bookName) bookAbbrev = key;
      });

      if (bookAbbrev == null) return [];

      // 🔹 Carregar o JSON do capítulo correspondente
      final jsonPath =
          'assets/Biblia/completa_traducoes/nvi/$bookAbbrev/$chapter.json';
      final jsonString = await rootBundle.loadString(jsonPath);
      final List<dynamic> versesList = json.decode(jsonString);

      final startIndex = int.parse(startVerse) - 1;
      final endIndex = endVerse != null ? int.parse(endVerse) - 1 : startIndex;

      if (startIndex < 0 || endIndex >= versesList.length) return [];

      return versesList.sublist(startIndex, endIndex + 1).cast<String>();
    } catch (e) {
      print("Erro ao carregar versículos para referência $reference: $e");
      return [];
    }
  }
}
