import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes/palavras_do_fim_dos_tempos_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes/profecias_de_sua_vinda_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_routes/eventos_vida_de_jesus_page.dart';

class BibleRoutesWidget extends StatefulWidget {
  final VoidCallback onBack;

  const BibleRoutesWidget({super.key, required this.onBack});

  @override
  _BibleRoutesWidgetState createState() => _BibleRoutesWidgetState();
}

class _BibleRoutesWidgetState extends State<BibleRoutesWidget> {
  final List<Map<String, dynamic>> jsonFiles = [
    {
      'file': 'profeciasdesuavinda.json',
      'title': 'Profecias de Sua Vinda',
      'page': (List<dynamic> data) => ProfeciasDeSuaVindaPage(profecias: data),
    },
    {
      'file': 'palavrasdofimdostempos.json',
      'title': 'Palavras do Fim dos Tempos',
      'page': (List<dynamic> data) => PalavrasDoFimDosTemposPage(termos: data),
    },
    {
      'file': 'eventosvidadeJesus.json',
      'title': 'Eventos da Vida de Jesus',
      'page': (List<dynamic> data) => EventosVidaDeJesusPage(eventos: data),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rotas Bíblicas"),
        backgroundColor: const Color(0xFF181A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: jsonFiles.length,
          itemBuilder: (context, index) {
            return Card(
              color: const Color(0xFF272828),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  jsonFiles[index]['title'],
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                trailing: const Icon(Icons.arrow_forward, color: Colors.white),
                onTap: () async {
                  final data = await _loadJsonFile(jsonFiles[index]['file']);
                  if (data != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => jsonFiles[index]['page'](data),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<List<dynamic>?> _loadJsonFile(String fileName) async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/Biblia/rotas_biblia/$fileName');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return jsonData['profecias'] ?? jsonData['termos'] ?? jsonData['eventos'];
    } catch (e) {
      print("Erro ao carregar $fileName: $e");
      return null;
    }
  }
}
