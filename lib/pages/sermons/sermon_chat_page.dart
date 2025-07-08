// lib/pages/sermons/sermon_chat_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';

// --- Modelos de Dados para o Chat ---
enum MessageAuthor { user, bot }

class ChatMessage {
  final String text;
  final MessageAuthor author;
  final List<Map<String, dynamic>>? sources; // Fontes usadas pelo bot

  ChatMessage({
    required this.text,
    required this.author,
    this.sources,
  });
}

// --- Widget da Tela Principal do Chat ---
class SermonChatPage extends StatefulWidget {
  const SermonChatPage({super.key});

  @override
  State<SermonChatPage> createState() => _SermonChatPageState();
}

class _SermonChatPageState extends State<SermonChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Lista que guardará todas as mensagens da conversa
  final List<ChatMessage> _messages = [];
  // Estado para controlar o indicador de "carregando"
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Função para rolar a lista para o final
  void _scrollToBottom() {
    // Adiciona um pequeno delay para garantir que o widget foi construído antes de rolar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // =============================================================
  // >>> PASSO 2: A LÓGICA DE CHAMADA DA FUNÇÃO ENTRARÁ AQUI <<<
  // =============================================================
  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    // Limpa o campo de texto
    _textController.clear();

    setState(() {
      // Adiciona a mensagem do usuário à tela imediatamente
      _messages.add(ChatMessage(text: query, author: MessageAuthor.user));
      _isLoading = true; // Mostra o indicador de "pensando..."
    });

    _scrollToBottom();

    try {
      // 1. Instancia o cliente do Firebase Functions
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('chatWithSermons');

      // 2. Prepara os dados para enviar
      // No futuro, você pode enviar o histórico aqui: 'history': _messages...
      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'query': query,
      });

      // 3. Processa a resposta bem-sucedida
      final responseData = Map<String, dynamic>.from(result.data);
      final botResponse = responseData['response'] as String? ??
          "Desculpe, não consegui processar a resposta.";
      final sources = (responseData['sources'] as List<dynamic>?)
          ?.map((source) => Map<String, dynamic>.from(source))
          .toList();

      setState(() {
        _messages.add(ChatMessage(
          text: botResponse,
          author: MessageAuthor.bot,
          sources: sources,
        ));
      });
    } on FirebaseFunctionsException catch (e) {
      // 4. Trata erros específicos da Cloud Function
      print("Erro FirebaseFunctionsException: ${e.code} - ${e.message}");
      setState(() {
        _messages.add(ChatMessage(
          text: "Ocorreu um erro ao buscar a resposta: ${e.message}",
          author: MessageAuthor.bot,
        ));
      });
    } catch (e) {
      // 5. Trata outros erros (ex: rede)
      print("Erro inesperado: $e");
      setState(() {
        _messages.add(ChatMessage(
          text: "Ocorreu um erro inesperado. Verifique sua conexão.",
          author: MessageAuthor.bot,
        ));
      });
    } finally {
      // 6. Garante que o estado de loading seja sempre desativado
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversar com Spurgeon AI"),
      ),
      body: Column(
        children: [
          // Área das Mensagens
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length +
                  (_isLoading ? 1 : 0), // Adiciona espaço para o loader
              itemBuilder: (context, index) {
                // Se estiver carregando e for o último item, mostra o loader
                if (_isLoading && index == _messages.length) {
                  return const _BotTypingIndicator();
                }
                final message = _messages[index];
                if (message.author == MessageAuthor.user) {
                  return _UserMessageBubble(message: message);
                } else {
                  return _BotMessageBubble(message: message);
                }
              },
            ),
          ),
          // Divisor
          Divider(height: 1.0, color: theme.dividerColor),
          // Área de Input
          _buildTextComposer(theme),
        ],
      ),
    );
  }

  // Widget para a caixa de texto e botão de enviar
  Widget _buildTextComposer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: theme.cardColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration.collapsed(
                hintText: "Pergunte sobre os sermões...",
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            // Desabilita o botão enquanto uma resposta está sendo carregada
            onPressed: _isLoading ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

// --- Widgets para as Bolhas de Chat ---

class _UserMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _UserMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }
}

class _BotMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _BotMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            ),
          ),
          // Renderiza as fontes, se houver
          if (message.sources != null && message.sources!.isNotEmpty)
            _buildSourceList(context, message.sources!),
        ],
      ),
    );
  }

  Widget _buildSourceList(
      BuildContext context, List<Map<String, dynamic>> sources) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Fontes usadas:",
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...sources
              .map((source) => _buildSourceChip(context, source))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSourceChip(BuildContext context, Map<String, dynamic> source) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: ActionChip(
        avatar: Icon(Icons.menu_book,
            size: 16, color: Theme.of(context).colorScheme.primary),
        label: Text(
          source['title'] ?? 'Sermão Desconhecido',
          overflow: TextOverflow.ellipsis,
        ),
        labelStyle: TextStyle(
            fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
        // <<< A LÓGICA DE NAVEGAÇÃO ESTÁ AQUI >>>
        onPressed: () {
          // 1. Extrai os dados necessários do mapa 'source'
          final sermonId = source['sermon_id'] as String?;
          final title = source['title'] as String?;

          // 2. Garante que os dados existem antes de navegar
          if (sermonId != null && title != null) {
            // 3. Usa o Navigator para empurrar a tela de detalhes do sermão
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SermonDetailPage(
                  // 4. Passa os parâmetros corretos para a SermonDetailPage
                  sermonGeneratedId: sermonId,
                  sermonTitle: title,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// Widget para o indicador de "digitando" do bot
class _BotTypingIndicator extends StatelessWidget {
  const _BotTypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const SizedBox(
          width: 50,
          height: 20,
          child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2.0), // Ou um GIF de "digitando"
          ),
        ),
      ),
    );
  }
}
