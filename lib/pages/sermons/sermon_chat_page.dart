// lib/pages/sermons/sermon_chat_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Modelos de Dados para o Chat ---
enum MessageAuthor { user, bot }

class ChatMessage {
  final String text;
  final MessageAuthor author;
  final List<Map<String, dynamic>>? sources;

  ChatMessage({
    required this.text,
    required this.author,
    this.sources,
  });

  // Converte um objeto ChatMessage em um Map para poder ser salvo em JSON
  Map<String, dynamic> toJson() => {
        'text': text,
        'author': author.name, // Salva o nome do enum (ex: 'user', 'bot')
        'sources': sources,
      };

  // Cria um objeto ChatMessage a partir de um Map (lido do JSON)
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        author: MessageAuthor.values.firstWhere(
          (e) => e.name == json['author'],
          orElse: () => MessageAuthor.bot, // Padrão seguro
        ),
        sources: (json['sources'] as List<dynamic>?)
            ?.map((source) => Map<String, dynamic>.from(source))
            .toList(),
      );
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
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  static const String _chatHistoryKey = 'sermon_chat_history';

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // --- Funções de Persistência ---

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> chatHistoryJson =
        _messages.map((m) => m.toJson()).toList();
    await prefs.setString(_chatHistoryKey, json.encode(chatHistoryJson));
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? chatHistoryString = prefs.getString(_chatHistoryKey);

    if (mounted) {
      if (chatHistoryString != null) {
        final List<dynamic> chatHistoryJson = json.decode(chatHistoryString);
        setState(() {
          _messages.clear();
          _messages.addAll(
              chatHistoryJson.map((json) => ChatMessage.fromJson(json)));
        });
      } else {
        _resetChat(
            save:
                false); // Inicia com a mensagem de boas-vindas se não houver histórico
      }
      _scrollToBottom();
    }
  }

  void _resetChat({bool save = true}) {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text:
            "Olá! Sou Spurgeon AI. Como posso ajudá-lo a explorar os sermões hoje?",
        author: MessageAuthor.bot,
      ));
      _isLoading = false;
    });
    if (save) _saveChatHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
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

  Future<void> _sendMessage() async {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    final userMessage = ChatMessage(text: query, author: MessageAuthor.user);
    _textController.clear();

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('chatWithSermons');

      const int historyLimit = 8;
      final conversationHistory = _messages.length > 1
          ? _messages.sublist(0, _messages.length - 1)
          : [];
      final recentHistory = conversationHistory.length > historyLimit
          ? conversationHistory
              .sublist(conversationHistory.length - historyLimit)
          : conversationHistory;
      final historyPayload = recentHistory
          .map((msg) => {
                'role': msg.author == MessageAuthor.user ? 'user' : 'assistant',
                'content': msg.text
              })
          .toList();

      final HttpsCallableResult result = await callable
          .call<Map<String, dynamic>>(
              {'query': query, 'history': historyPayload});

      final responseData = Map<String, dynamic>.from(result.data);
      final botResponse = responseData['response'] as String? ??
          "Desculpe, não consegui processar a resposta.";
      final sources = (responseData['sources'] as List<dynamic>?)
          ?.map((source) => Map<String, dynamic>.from(source))
          .toList();

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
              text: botResponse, author: MessageAuthor.bot, sources: sources));
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
              text: "Ocorreu um erro ao buscar a resposta: ${e.message}",
              author: MessageAuthor.bot));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
              text: "Ocorreu um erro inesperado. Verifique sua conexão.",
              author: MessageAuthor.bot));
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
        await _saveChatHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Conversar com Spurgeon AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Nova Conversa",
            onPressed: () => _resetChat(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
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
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                onSubmitted: _isLoading ? null : (_) => _sendMessage(),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 5,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Pergunte sobre os sermões...",
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send_rounded),
              iconSize: 28,
              color: theme.colorScheme.primary,
              onPressed: _isLoading ? null : _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
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
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4)),
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20)),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            ),
            if (message.sources != null && message.sources!.isNotEmpty)
              _buildSourcesExpansionTile(context, message.sources!),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesExpansionTile(
      BuildContext context, List<Map<String, dynamic>> sources) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(
          "Fontes Usadas (${sources.length})",
          style:
              theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 4),
        children:
            sources.map((source) => _buildSourceChip(context, source)).toList(),
      ),
    );
  }

  Widget _buildSourceChip(BuildContext context, Map<String, dynamic> source) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        child: ActionChip(
          avatar: Icon(Icons.menu_book,
              size: 16, color: Theme.of(context).colorScheme.primary),
          label: Text(
            source['title'] ?? 'Sermão Desconhecido',
            overflow: TextOverflow.ellipsis,
          ),
          labelStyle: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color),
          onPressed: () {
            final sermonId = source['sermon_id'] as String?;
            final title = source['title'] as String?;
            if (sermonId != null && title != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SermonDetailPage(
                    sermonGeneratedId: sermonId,
                    sermonTitle: title,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// --- Widget para o Indicador de "Digitando" Animado ---
class _BotTypingIndicator extends StatefulWidget {
  const _BotTypingIndicator();

  @override
  State<_BotTypingIndicator> createState() => _BotTypingIndicatorState();
}

class _BotTypingIndicatorState extends State<_BotTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = (index * 200).toDouble();
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final sinValue = (1 +
                        (Curves.easeInOut.transform(
                                    (_controller.value * 1200 - delay)
                                            .clamp(0, 1200) /
                                        1200) *
                                2 -
                            1))
                    .abs();
                return Transform.translate(
                  offset: Offset(0, -sinValue * 4),
                  child: child,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
