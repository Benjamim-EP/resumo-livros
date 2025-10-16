// lib/pages/library_page/reading_sequence_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_redux/flutter_redux.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:septima_biblia/models/reading_sequence.dart';
import 'package:septima_biblia/pages/library_page.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class ReadingSequencePage extends StatefulWidget {
  final String assetPath;
  final String sequenceTitle;

  const ReadingSequencePage({
    super.key,
    required this.assetPath,
    required this.sequenceTitle,
  });

  @override
  State<ReadingSequencePage> createState() => _ReadingSequencePageState();
}

class _ReadingSequencePageState extends State<ReadingSequencePage> {
  Future<ReadingSequence>? _sequenceFuture;

  @override
  void initState() {
    super.initState();
    _sequenceFuture = _loadSequenceData();
  }

  Future<ReadingSequence> _loadSequenceData() async {
    try {
      final jsonString = await rootBundle.loadString(widget.assetPath);
      final jsonData = json.decode(jsonString);
      return ReadingSequence.fromJson(jsonData);
    } catch (e) {
      print("Erro ao carregar a sequência de leitura: $e");
      throw Exception('Falha ao carregar os dados da sequência.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sequenceTitle),
      ),
      body: FutureBuilder<ReadingSequence>(
        future: _sequenceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
                child: Text("Erro ao carregar a jornada de leitura."));
          }

          final sequence = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: sequence.steps.length,
            itemBuilder: (context, index) {
              final step = sequence.steps[index];
              return _MonthSection(step: step);
            },
          );
        },
      ),
    );
  }
}

// Widget para exibir a seção de um mês
class _MonthSection extends StatelessWidget {
  final SequenceStep step;
  const _MonthSection({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Mês ${step.month}: ${step.title}",
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(step.focus,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          // Usamos um LayoutBuilder para que o Wrap se ajuste ao espaço disponível
          LayoutBuilder(builder: (context, constraints) {
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: step.resources.map((resource) {
                return SizedBox(
                  // Calcula a largura para caberem 3 cards por linha, com espaçamento
                  width: (constraints.maxWidth - 32) / 3,
                  child: _BookProgressCard(resourceId: resource.resourceId),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

// Card individual que mostra o progresso de cada livro
class _BookProgressCard extends StatelessWidget {
  final String resourceId;
  const _BookProgressCard({required this.resourceId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Busca os metadados do livro (capa, página de destino) na lista estática
    final bookMetaData = allLibraryItems.firstWhere(
      (item) => item['id'] == resourceId,
      orElse: () => {},
    );

    if (bookMetaData.isEmpty) {
      return const SizedBox
          .shrink(); // Não renderiza se o livro não for encontrado
    }

    final String coverPath = bookMetaData['coverImagePath'] ?? '';
    final Widget destinationPage = bookMetaData['destinationPage'];
    // <<< 1. EXTRAIR O TÍTULO DO LIVRO >>>
    final String title = bookMetaData['title'] ?? 'Livro';

    return StoreConnector<AppState, double>(
      converter: (store) {
        // Busca o progresso do livro no estado do Redux
        final progressItem = store.state.userState.inProgressItems.firstWhere(
          (item) => item['contentId'] == resourceId,
          orElse: () => {'progressPercentage': 0.0},
        );
        return (progressItem['progressPercentage'] as num?)?.toDouble() ?? 0.0;
      },
      builder: (context, progressPercentage) {
        return InkWell(
          onTap: () {
            Navigator.push(context, FadeScalePageRoute(page: destinationPage));
          },
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Capa do livro
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  clipBehavior: Clip.antiAlias,
                  child: coverPath.isNotEmpty
                      ? Image.asset(coverPath, fit: BoxFit.cover)
                      : Container(color: theme.colorScheme.surfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              // Barra de progresso
              LinearPercentIndicator(
                percent: progressPercentage,
                lineHeight: 6.0,
                barRadius: const Radius.circular(3),
                backgroundColor: theme.colorScheme.surfaceVariant,
                progressColor: theme.colorScheme.primary,
                padding: EdgeInsets.zero,
              ),

              // <<< 2. ADICIONAR O WIDGET DE TEXTO PARA O TÍTULO >>>
              const SizedBox(height: 6), // Espaço entre a barra e o texto
              Text(
                title,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center, // Centraliza o texto
                maxLines: 2, // Permite que o título quebre em até 2 linhas
                overflow: TextOverflow.ellipsis, // Adiciona "..." se for maior
              ),
            ],
          ),
        );
      },
    );
  }
}
