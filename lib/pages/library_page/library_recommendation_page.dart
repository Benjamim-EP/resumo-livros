// lib/pages/library_page/library_recommendation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:septima_biblia/pages/library_page/ai_recommendation_card.dart';
import 'package:septima_biblia/services/custom_page_route.dart';
import 'package:septima_biblia/pages/library_page.dart'; // Importa para acessar a lista estática

class LibraryRecommendationPage extends StatefulWidget {
  const LibraryRecommendationPage({super.key});
  @override
  State<LibraryRecommendationPage> createState() =>
      _LibraryRecommendationPageState();
}

class _LibraryRecommendationPageState extends State<LibraryRecommendationPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>>? _recommendations;
  bool _isLoading = false;
  String? _error;

  // Mapa de consulta para encontrar a página de destino de forma eficiente
  late final Map<String, Widget> _destinationPageMap;

  @override
  void initState() {
    super.initState();
    // Preenche o mapa de consulta uma vez, usando a lista estática da LibraryPage
    _destinationPageMap = {
      for (var item in allLibraryItems) // Acessa a lista estática diretamente
        (item['title'] as String): (item['destinationPage'] as Widget)
    };
  }

  /// Chama a Cloud Function para obter recomendações
  Future<void> _getRecommendations() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _recommendations = null;
    });

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('recommendLibraryBooks');
      final result =
          await callable.call<Map<String, dynamic>>({'user_query': query});

      final data = result.data;
      if (data == null) {
        throw Exception("A resposta do servidor estava vazia.");
      }

      final recommendationsListRaw = data['recommendations'];

      if (data['status'] == 'success' && recommendationsListRaw is List) {
        // Converte os tipos de forma segura para evitar o erro de 'subtype'
        final List<Map<String, dynamic>> typedRecommendations =
            recommendationsListRaw
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();

        setState(() {
          _recommendations = typedRecommendations;
        });
      } else {
        throw Exception(
            "A resposta do servidor não continha recomendações válidas.");
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? "Ocorreu um erro no servidor.");
    } catch (e) {
      setState(() => _error = "Falha na conexão. Tente novamente.");
      print("Erro em _getRecommendations: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recomendações da Biblioteca"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _getRecommendations(),
              decoration: InputDecoration(
                hintText: "Estou buscando um livro sobre...",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _isLoading ? null : _getRecommendations,
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildBodyContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
          child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(_error!,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center),
      ));
    }
    if (_recommendations != null) {
      if (_recommendations!.isEmpty) {
        return const Center(
            child: Text("Nenhuma recomendação encontrada para sua busca."));
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _recommendations!.length,
        itemBuilder: (context, index) {
          // --- INÍCIO DA CORREÇÃO ---

          // 1. Pega a recomendação original da IA
          final aiRecommendation = _recommendations![index];
          final String bookIdFromAI =
              aiRecommendation['bookId'] as String? ?? '';

          // 2. Busca os metadados locais confiáveis usando o bookId da IA
          final localBookData = allLibraryItems.firstWhere(
            (localItem) => localItem['id'] == bookIdFromAI,
            orElse: () =>
                {}, // Retorna um mapa vazio se não encontrar para evitar erros
          );

          // 3. Cria um novo mapa de dados corrigido
          // Ele usa todos os dados da IA, mas SOBRESCREVE o 'coverImagePath'
          // com o valor confiável da nossa lista local.
          final Map<String, dynamic> correctedData = {
            ...aiRecommendation, // Mantém 'title', 'author', 'justificativa', etc., da IA
            if (localBookData.isNotEmpty)
              'coverImagePath': localBookData[
                  'coverImagePath'], // Sobrescreve com o caminho correto
          };

          // A lógica para encontrar a página de destino continua a mesma
          final String title = correctedData['title'] ?? '';
          final Widget destinationPage = _destinationPageMap[title] ??
              const Scaffold(
                  body: Center(child: Text("Página não encontrada")));

          // 4. Passa os dados JÁ CORRIGIDOS para o AiRecommendationCard
          return AiRecommendationCard(
            recommendation: correctedData,
            onTap: () {
              Navigator.push(
                context,
                FadeScalePageRoute(page: destinationPage),
              );
            },
          ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: -0.2);

          // --- FIM DA CORREÇÃO ---
        },
      );
    }
    // Estado inicial
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          "Descreva o que você sente ou procura, e a IA encontrará o livro ideal para você.",
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      ),
    );
  }
}
