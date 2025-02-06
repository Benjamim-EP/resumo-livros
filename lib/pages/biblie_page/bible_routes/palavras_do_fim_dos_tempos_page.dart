import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PalavrasDoFimDosTemposPage extends StatefulWidget {
  final List<dynamic> termos;

  const PalavrasDoFimDosTemposPage({super.key, required this.termos});

  @override
  _PalavrasDoFimDosTemposPageState createState() => _PalavrasDoFimDosTemposPageState();
}

class _PalavrasDoFimDosTemposPageState extends State<PalavrasDoFimDosTemposPage> {
  Map<String, dynamic>? abbrevMap;

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
        title: const Text("Palavras do Fim dos Tempos"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: abbrevMap == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.termos.length,
              itemBuilder: (context, index) {
                final termo = widget.termos[index];

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
                      termo['topico'],
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          termo['texto'],
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      _buildReferences(termo['referencias']),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReferences(List<dynamic>? referencias) {
    if (referencias == null || referencias.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: referencias.map((ref) => _buildReferenceTile(ref)).toList(),
    );
  }

  Widget _buildReferenceTile(String reference) {
    return FutureBuilder<List<String>>(
      future: _loadVerses(reference),
      builder: (context, snapshot) {
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
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

      String? bookAbbrev;
      abbrevMap!.forEach((key, value) {
        if (value["nome"] == bookName) bookAbbrev = key;
      });

      if (bookAbbrev == null) return [];

      final jsonPath = 'assets/Biblia/completa_traducoes/nvi/$bookAbbrev/$chapter.json';
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
