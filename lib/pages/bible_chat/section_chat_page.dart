// lib/pages/bible_chat/section_chat_page.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/services/custom_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Modelos de Dados ---
enum MessageAuthor { user, bot }

class ChatMessage {
  final String text;
  final MessageAuthor author;
  ChatMessage({required this.text, required this.author});

  Map<String, dynamic> toJson() => {'text': text, 'author': author.name};
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        author: MessageAuthor.values.firstWhere(
          (e) => e.name == json['author'],
          orElse: () => MessageAuthor.bot,
        ),
      );
}

// --- ViewModel ---
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

// --- Widget da Tela Principal ---
class SectionChatPage extends StatefulWidget {
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final String sectionTitle;
  final List<String> sectionVerseTexts;

  const SectionChatPage({
    super.key,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.sectionTitle,
    required this.sectionVerseTexts,
  });

  @override
  State<SectionChatPage> createState() => _SectionChatPageState();
}

class _SectionChatPageState extends State<SectionChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  bool _useStrongsKnowledge = false;
  static const int chatCost = 5;
  static const String _chatHistoryKey =
      'sermon_chat_history_bible_section'; // Chave única

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> chatHistoryJson =
          _messages.map((m) => m.toJson()).toList();
      await prefs.setString(_chatHistoryKey, json.encode(chatHistoryJson));
    } catch (e) {
      print("Erro ao salvar histórico do chat da seção: $e");
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
        _messages.addAll(chatHistoryJson
            .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>)));
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
            "Olá! Faça perguntas sobre esta seção, como o significado de uma palavra ou o contexto histórico.",
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
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
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

    if (store.state.userState.isGuestUser) {
      showLoginRequiredDialog(context, featureName: "enviar mensagens no chat");
      return; // Impede a continuação da função
    }

    if (!viewModel.isPremium && viewModel.userCoins < chatCost) {
      CustomNotificationService.showWarningWithAction(
          context: context,
          message: 'Você precisa de $chatCost moedas para enviar uma mensagem.',
          buttonText: 'Ganhar Moedas',
          onButtonPressed: () => store.dispatch(RequestRewardedAdAction()));
      return;
    }

    final int originalCoins = viewModel.userCoins;

    final userMessage = ChatMessage(text: query, author: MessageAuthor.user);
    _textController.clear();

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    if (!viewModel.isPremium) {
      store.dispatch(UpdateUserCoinsAction(originalCoins - chatCost));
    }

    try {
      final functions =
          FirebaseFunctions.instanceFor(region: "southamerica-east1");
      final callable = functions.httpsCallable('chatWithBibleSection');

      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'query': query,
        'history': _messages
            .map((m) => {
                  'role': m.author == MessageAuthor.user ? 'user' : 'assistant',
                  'content': m.text
                })
            .toList(),
        'bookAbbrev': widget.bookAbbrev,
        'chapterNumber': widget.chapterNumber,
        'versesRangeStr': widget.versesRangeStr,
        'useStrongsKnowledge': _useStrongsKnowledge,
      });

      final responseData = Map<String, dynamic>.from(result.data);
      final botResponse = responseData['response'] as String? ??
          "Desculpe, não consegui processar a resposta.";

      if (mounted) {
        setState(() {
          _messages
              .add(ChatMessage(text: botResponse, author: MessageAuthor.bot));
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        // ✅ PONTO DA CORREÇÃO
        print(
            "SectionChatPage: Erro FirebaseFunctionsException: ${e.code} - ${e.message}");

        String errorMessage;
        // Traduz o erro técnico para uma mensagem amigável
        if (e.code.toUpperCase() == 'UNAVAILABLE' ||
            e.code.toUpperCase() == 'DEADLINE_EXCEEDED') {
          errorMessage =
              "Falha na conexão. Por favor, verifique sua internet e tente novamente.";
          // A notificação externa já informa o usuário, então aqui só corrigimos a mensagem do chat.
        } else if (e.code == 'resource-exhausted') {
          errorMessage =
              "Moedas insuficientes. Você precisa de $chatCost moedas para continuar.";
          store.dispatch(LoadUserDetailsAction());
          // A notificação já é mostrada pelo middleware de busca
        } else {
          errorMessage =
              "Ocorreu um erro ao processar sua pergunta. Tente novamente.";
        }

        // Reembolsa as moedas se necessário
        if (!viewModel.isPremium && e.code != 'resource-exhausted') {
          store.dispatch(UpdateUserCoinsAction(originalCoins));
          // A notificação de erro externa pode informar sobre o reembolso
          CustomNotificationService.showError(
              context, "Ocorreu um erro. Suas moedas foram devolvidas.");
        } else if (e.code == 'resource-exhausted') {
          CustomNotificationService.showError(context, errorMessage);
        } else {
          CustomNotificationService.showError(
              context, "Ocorreu um erro ao processar sua pergunta.");
        }

        // Exibe a mensagem amigável no chat
        setState(() {
          _messages
              .add(ChatMessage(text: errorMessage, author: MessageAuthor.bot));
        });
      }
    } catch (e) {
      if (mounted) {
        print("SectionChatPage: Erro inesperado: $e");
        if (!viewModel.isPremium) {
          store.dispatch(UpdateUserCoinsAction(originalCoins));
        }
        // Mostra a notificação externa
        CustomNotificationService.showError(
            context, "Ocorreu um erro inesperado. Verifique sua conexão.");
        // Adiciona a mensagem amigável no chat
        setState(() {
          _messages.add(ChatMessage(
              text:
                  "Ocorreu um erro inesperado. Verifique sua conexão e tente novamente.",
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
    final theme = Theme.of(context);
    final String fullReference =
        '${widget.bookAbbrev.toUpperCase()} ${widget.chapterNumber}:${widget.versesRangeStr}';

    return StoreConnector<AppState, _ChatViewModel>(
      converter: (store) => _ChatViewModel.fromStore(store),
      builder: (context, viewModel) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                title: Text('Chat: $fullReference'),
                pinned: true,
                expandedHeight: 230.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeaderContent(theme, viewModel),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < _messages.length) {
                        final message = _messages[index];
                        return message.author == MessageAuthor.user
                            ? _UserMessageBubble(message: message)
                            : _BotMessageBubble(message: message);
                      }
                      if (_isLoading) {
                        return const _BotTypingIndicator();
                      }
                      return null;
                    },
                    childCount: _messages.length + (_isLoading ? 1 : 0),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildTextComposer(theme, viewModel),
        );
      },
    );
  }

  Widget _buildHeaderContent(ThemeData theme, _ChatViewModel viewModel) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [
              theme.cardColor.withOpacity(0.5),
              theme.scaffoldBackgroundColor
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 1.0]),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
              top: 60.0, left: 16.0, right: 16.0, bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.sectionTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                widget.sectionVerseTexts.join(" "),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate,
                          size: 20, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text("Análise Etimológica",
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  Switch(
                    value: _useStrongsKnowledge,
                    activeColor: theme.colorScheme.primary,
                    onChanged: viewModel.isPremium
                        ? (value) =>
                            setState(() => _useStrongsKnowledge = value)
                        : null,
                  ),
                ],
              ),
              if (!viewModel.isPremium)
                Padding(
                  padding: const EdgeInsets.only(left: 28.0),
                  child: Text(
                    "Recurso Premium",
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer(ThemeData theme, _ChatViewModel viewModel) {
    return Material(
      color: theme.cardColor,
      elevation: 8,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16.0, 12.0, 8.0, 12.0 + MediaQuery.of(context).viewInsets.bottom),
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
                  hintText: "Faça sua pergunta...",
                  filled: true,
                  fillColor: theme.scaffoldBackgroundColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24.0),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!viewModel.isPremium)
                  Text(
                    "Custo: $chatCost",
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: viewModel.userCoins >= chatCost
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.error),
                  ),
                IconButton(
                  icon: const Icon(Icons.send_rounded),
                  iconSize: 28,
                  color: theme.colorScheme.primary,
                  onPressed: _isLoading ? null : _sendMessage,
                  style: IconButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.15),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
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
        margin: const EdgeInsets.symmetric(vertical: 4.0),
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
        child: Text(message.text,
            style: TextStyle(color: theme.colorScheme.onPrimary)),
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
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(20)),
          ),
          child: Markdown(
            data: message.text,
            selectable: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge,
              listBullet: theme.textTheme.bodyLarge,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
        ),
      ),
    );
  }
}

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
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
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
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
              bottomLeft: Radius.circular(20)),
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
                    offset: Offset(0, -sinValue * 4), child: child);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    shape: BoxShape.circle),
              ),
            );
          }),
        ),
      ),
    );
  }
}
