import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Componente que exibe um texto em formato Markdown
class MarkdownViewer extends StatelessWidget {
  const MarkdownViewer({super.key});

  @override
  Widget build(BuildContext context) {
    // O texto de exemplo que será exibido como Markdown
    const String markdownText = """
- **Problema de Atribuir o Universo a um Criador Bom**:
    
    - O autor questiona como, em um universo aparentemente tão cruel, os seres humanos atribuíram sua criação a um Criador sábio e bom.
- **Religião como Algo que Surge Apesar da Natureza**:
    
    - O argumento é que a visão religiosa não surgiu da observação do mundo, mas de outra fonte, já que o mundo sempre mostrou dor e sofrimento.
- **Problema de Atribuir o Universo a um Criador Bom**:
    
    - O autor questiona como, em um universo aparentemente tão cruel, os seres humanos atribuíram sua criação a um Criador sábio e bom.
- **Religião como Algo que Surge Apesar da Natureza**:
    
    - O argumento é que a visão religiosa não surgiu da observação do mundo, mas de outra fonte, já que o mundo sempre mostrou dor e sofrimento.
        
    """;

    return Markdown(
      data: markdownText, // Renderiza o conteúdo Markdown
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 16), // Personalizando o estilo do texto
        listBullet: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
