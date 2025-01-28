import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/middleware.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';

class FinalFormView extends StatefulWidget {
  const FinalFormView({super.key});

  @override
  _FinalFormViewState createState() => _FinalFormViewState();
}

class _FinalFormViewState extends State<FinalFormView> {
  final TextEditingController characteristicsController =
      TextEditingController();
  final TextEditingController challengesController = TextEditingController();
  final TextEditingController strengthController = TextEditingController();
  final TextEditingController additionalInfoController =
      TextEditingController();

  int _currentFieldIndex = 0;

  final List<Map<String, dynamic>> _fields = [
    {
      'title': "Características",
      'controller': TextEditingController(),
      'hintText':
          "Descreva suas características principais, como paciência, organização, etc.",
    },
    {
      'title': "Desafios",
      'controller': TextEditingController(),
      'hintText':
          "Descreva os pontos que você tem dificuldade como raiva, ansiedade, etc.",
    },
    {
      'title': "Força",
      'controller': TextEditingController(),
      'hintText':
          "Quais são as suas maiores forças? Exemplo: resiliência, empatia, etc.",
    },
    {
      'title': "Informação Adicional",
      'controller': TextEditingController(),
      'hintText':
          "Temas de interesse, dúvidas ou algo mais que gostaria de compartilhar.",
    },
  ];

  void _nextField() {
    if (_currentFieldIndex < _fields.length - 1) {
      setState(() {
        _currentFieldIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A1A),
      appBar: AppBar(
        title: const Text("Formulário do Usuário"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Para Começar",
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _fields[_currentFieldIndex]['title'], // Exibe o título do campo
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                context,
                controller: _fields[_currentFieldIndex]['controller'],
                hintText: _fields[_currentFieldIndex]['hintText'],
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              if (_currentFieldIndex < _fields.length - 1)
                ElevatedButton(
                  onPressed: _nextField,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF232538),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Próximo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    final features = {
                      'Caracteristicas': _fields[0]['controller'].text.trim(),
                      'Desafios': _fields[1]['controller'].text.trim(),
                      'Força': _fields[2]['controller'].text.trim(),
                      'Informação adicional':
                          _fields[3]['controller'].text.trim(),
                    };

                    StoreProvider.of<AppState>(context).dispatch(
                      SaveUserFeaturesAction(features),
                    );

                    final userText = '''
                    Características: ${features['Caracteristicas']}
                    Desafios: ${features['Desafios']}
                    Forças: ${features['Força']}
                    Informações adicionais: ${features['Informação adicional']}
                    ''';

                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    final analysis = await getTribeAnalysis(userText);
                    Navigator.pop(context);

                    if (analysis != null && analysis.isNotEmpty) {
                      Navigator.pushNamed(
                        context,
                        '/tribeSelection',
                        arguments: analysis,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Erro ao analisar tribos. Tente novamente.'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF232538),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                  ),
                  child: const Text(
                    'Salvar e Continuar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    required int maxLines,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF232538),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 6,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLength: 255,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          counterText: '', // Remove o contador de caracteres da UI
        ),
      ),
    );
  }
}
