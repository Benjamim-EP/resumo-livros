// lib/pages/sermons/sermon_chat_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:redux/redux.dart';

// --- Modelos de Dados ---
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

  Map<String, dynamic> toJson() => {
        'text': text,
        'author': author.name,
        'sources': sources,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        author: MessageAuthor.values.firstWhere(
          (e) => e.name == json['author'],
          orElse: () => MessageAuthor.bot,
        ),
        sources: (json['sources'] as List<dynamic>?)
            ?.map((source) => Map<String, dynamic>.from(source))
            .toList(),
      );
}

// --- ViewModel para conectar a UI ao estado do Redux ---
class _ChatViewModel {
  final int userCoins;
  final bool isPremium;

  _ChatViewModel({required this.userCoins, required this.isPremium});

  static _ChatViewModel fromStore(Store<AppState> store) {
    return _ChatViewModel(
      userCoins: store.state.userState.userCoins,
      isPremium: store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive,
    );
  }
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
  static const int chatCost = 5;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  // --- Funções de Persistência e Controle ---

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> chatHistoryJson =
          _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_chatHistoryKey, json.encode(chatHistoryJson));
    } catch (e) {
      print("Erro ao salvar histórico do chat: $e");
    }
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final String? chatHistoryString = prefs.getString(_chatHistoryKey);
    if (chatHistoryString != null) {
      final List<dynamic> chatHistoryJson = json.decode(chatHistoryString);
      setState(() {
        _messages.clear();
        _messages
            .addAll(chatHistoryJson.map((json) => ChatMessage.fromJson(json)));
      });
    } else {
      _resetChat(save: false);
    }
    _scrollToBottom();
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

    final store = StoreProvider.of<AppState>(context, listen: false);
    final viewModel = _ChatViewModel.fromStore(store);

    if (!viewModel.isPremium && viewModel.userCoins < chatCost) {
      CustomNotificationService.showWarningWithAction(
        context: context,
        message: 'Você precisa de $chatCost moedas para enviar uma mensagem.',
        buttonText: 'Ganhar Moedas',
        onButtonPressed: () => store.dispatch(RequestRewardedAdAction()),
      );
      return;
    }

    // <<< INÍCIO DA CORREÇÃO PRINCIPAL >>>

    // 1. Atualização Otimista: Deduz as moedas no estado Redux IMEDIATAMENTE.
    if (!viewModel.isPremium) {
      final newCoinTotal = viewModel.userCoins - chatCost;
      store.dispatch(UpdateUserCoinsAction(newCoinTotal));
      print("Frontend: Atualização otimista das moedas para $newCoinTotal");
    }

    // 2. Atualiza a UI com a mensagem do usuário e o loader.
    final userMessage = ChatMessage(text: query, author: MessageAuthor.user);
    _textController.clear();
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();
    await _saveChatHistory();

    // 3. Chama a Cloud Function (que fará a dedução real no Firestore).
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

      // A sincronização (LoadUserDetailsAction) pode ser removida daqui se a atualização otimista
      // for suficiente, ou mantida como uma verificação periódica. Por enquanto, vamos remover
      // para evitar chamadas redundantes. A atualização otimista já resolve a UI.
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        String errorMessage = "Ocorreu um erro: ${e.message}";
        if (e.code == 'resource-exhausted') {
          errorMessage =
              "Moedas insuficientes. Você precisa de $chatCost moedas para continuar.";
          // Se o backend diz que não há moedas, força a sincronização para corrigir o valor no app.
          store.dispatch(LoadUserDetailsAction());
          CustomNotificationService.showError(context, errorMessage);
        } else if (!viewModel.isPremium) {
          // Se houve outro erro na função, REEMBOLSA as moedas otimisticamente.
          store.dispatch(UpdateUserCoinsAction(viewModel.userCoins));
          print("Frontend: Reembolso otimista das moedas devido a erro na CF.");
        }
        setState(() {
          _messages
              .add(ChatMessage(text: errorMessage, author: MessageAuthor.bot));
        });
      }
    } catch (e) {
      if (mounted) {
        // Reembolsa em caso de erro de rede, etc.
        if (!viewModel.isPremium) {
          store.dispatch(UpdateUserCoinsAction(viewModel.userCoins));
        }
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado. Verifique sua conexão.");
        setState(() {
          _messages.add(ChatMessage(
              text: "Ocorreu um erro inesperado. Verifique sua conexão.",
              author: MessageAuthor.bot));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
        await _saveChatHistory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _ChatViewModel>(
      converter: (store) => _ChatViewModel.fromStore(store),
      builder: (context, viewModel) {
        // <<< A CORREÇÃO ESTÁ AQUI >>>
        return Scaffold(
          // Ao definir como 'true', o corpo do Scaffold será redimensionado
          // para dar espaço ao teclado, empurrando a barra de input para cima.
          // Por padrão, já é true, mas é bom garantir que não foi definido como false em outro lugar.
          resizeToAvoidBottomInset: true,

          appBar: AppBar(
            title: const Text("Conversar com Spurgeon AI"),
            actions: [
              if (!viewModel.isPremium)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Chip(
                    avatar: Icon(Icons.monetization_on,
                        color: Theme.of(context).colorScheme.primary, size: 18),
                    label: Text(viewModel.userCoins.toString()),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
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
                      // Anima a entrada do indicador de "digitando"
                      return const _BotTypingIndicator()
                          .animate()
                          .fadeIn(duration: 300.ms);
                    }
                    final message = _messages[index];
                    Widget messageBubble;
                    if (message.author == MessageAuthor.user) {
                      messageBubble = _UserMessageBubble(message: message);
                    } else {
                      messageBubble = _BotMessageBubble(message: message);
                    }

                    // <<< ADICIONE A ANIMAÇÃO AQUI >>>
                    // Anima cada bolha de mensagem ao ser adicionada à lista
                    return messageBubble
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.5, curve: Curves.easeOutCubic);
                  },
                ),
              ),
              // O _buildTextComposer() é a sua barra de input
              _buildTextComposer(),
            ],
          ),
        );
      },
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
