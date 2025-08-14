// lib/services/cross_reference_service.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Para carregar os versículos

// ====================================================================
// <<< PASSO 1: O NOVO WIDGET STATEFUL PARA O CONTEÚDO DO DIÁLOGO >>>
// ====================================================================
class _VerseContentDialog extends StatefulWidget {
  final String reference;

  const _VerseContentDialog({required this.reference});

  @override
  State<_VerseContentDialog> createState() => _VerseContentDialogState();
}

class _VerseContentDialogState extends State<_VerseContentDialog> {
  // O Future agora vive DENTRO do estado do diálogo
  late Future<List<String>> _verseTextsFuture;

  @override
  void initState() {
    super.initState();
    // Inicia o carregamento dos dados quando o diálogo é criado
    _verseTextsFuture =
        BiblePageHelper.loadVersesFromReference(widget.reference, 'nvi');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reference),
      // O FutureBuilder gerencia a UI de loading e a de conteúdo
      content: FutureBuilder<List<String>>(
        future: _verseTextsFuture,
        builder: (context, snapshot) {
          // Enquanto está carregando...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Carregando referência..."),
              ],
            );
          }

          // Se deu erro...
          if (snapshot.hasError || !snapshot.hasData) {
            return Text(
              "Não foi possível carregar o texto para esta referência.\nErro: ${snapshot.error}",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            );
          }

          // Se carregou com sucesso...
          final verseTexts = snapshot.data!;
          return SingleChildScrollView(
            child: Text(verseTexts.join('\n')),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Fechar"),
        ),
      ],
    );
  }
}

// ==============================================================
// <<< PASSO 2: A CLASSE DE SERVIÇO ATUALIZADA E SIMPLIFICADA >>>
// ==============================================================
class CrossReferenceService {
  // A função showVerseInModal agora é muito mais simples.
  // Ela apenas mostra o nosso novo widget de diálogo stateful.
  static void showVerseInModal(BuildContext context, String reference) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // A única responsabilidade dela é construir o nosso diálogo inteligente.
        return _VerseContentDialog(reference: reference);
      },
    );
  }
  // Os outros métodos do serviço (se houver) permanecem os mesmos.
}
