// lib/pages/library_page/turretin_elenctic_theology/turretin_topic_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/turretin_theology_model.dart';
import 'package:septima_biblia/services/tts_manager.dart';

class TurretinTopicPage extends StatefulWidget {
  // Convertido para StatefulWidget
  final ElencticTopic topic;

  const TurretinTopicPage({super.key, required this.topic});

  @override
  State<TurretinTopicPage> createState() => _TurretinTopicPageState();
}

class _TurretinTopicPageState extends State<TurretinTopicPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Estado e instância do TTS
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _playerState = TtsPlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _ttsManager.playerState.addListener(_onTtsStateChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop();
    super.dispose();
  }

  // --- Funções de Controle de Áudio ---

  void _onTtsStateChanged() {
    if (!mounted) return;
    if (_playerState != _ttsManager.playerState.value) {
      setState(() {
        _playerState = _ttsManager.playerState.value;
      });
    }
  }

  void _startQuestionPlayback() {
    if (widget.topic.questions.isEmpty) return;

    final question = widget.topic.questions[_currentPage];
    final List<TtsQueueItem> queue = [];

    // Adiciona o título da questão
    queue.add(TtsQueueItem(
      sectionId: 'q_title_${_currentPage}',
      textToSpeak: question.questionTitle,
    ));

    // Adiciona a declaração da questão, se houver
    if (question.questionStatement.isNotEmpty) {
      queue.add(TtsQueueItem(
        sectionId: 'q_statement_${_currentPage}',
        textToSpeak: question.questionStatement,
      ));
    }

    // Adiciona cada parágrafo do conteúdo
    for (int i = 0; i < question.content.length; i++) {
      final paragraph = question.content[i];
      if (paragraph.trim().isNotEmpty) {
        queue.add(TtsQueueItem(
          sectionId: 'q_paragraph_${_currentPage}_$i',
          textToSpeak: paragraph,
        ));
      }
    }

    if (queue.isNotEmpty) {
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startQuestionPlayback();
        break;
      case TtsPlayerState.playing:
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        _ttsManager.restartCurrentItem();
        break;
    }
  }

  IconData _getAudioIcon() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return Icons.pause_circle_outline;
      case TtsPlayerState.paused:
        return Icons.play_circle_outline;
      case TtsPlayerState.stopped:
        return Icons.play_circle_outline;
    }
  }

  String _getAudioTooltip() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar Leitura";
      case TtsPlayerState.stopped:
        return "Ouvir Questão";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topic.topicTitle, overflow: TextOverflow.ellipsis),
        actions: [
          // Ícone de TTS
          IconButton(
            icon: Icon(
              _getAudioIcon(),
              color: _playerState == TtsPlayerState.playing
                  ? theme.colorScheme.secondary
                  : theme.iconTheme.color,
              size: 28,
            ),
            tooltip: _getAudioTooltip(),
            onPressed: _handleAudioControl,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.topic.questions.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
            _ttsManager.stop(); // Para a leitura ao mudar de página
          });
        },
        itemBuilder: (context, index) {
          final question = widget.topic.questions[index];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (question.questionStatement.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                        color:
                            theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.dividerColor)),
                    child: Text(
                      question.questionStatement,
                      style: theme.textTheme.bodyLarge?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.textTheme.bodyLarge?.color
                              ?.withOpacity(0.9)),
                    ),
                  ),
                ],
                Divider(color: theme.dividerColor, height: 32),
                ...question.content.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: theme.scaffoldBackgroundColor,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: _currentPage > 0
                    ? () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn)
                    : null,
              ),
              Text(
                'Questão ${_currentPage + 1} de ${widget.topic.questions.length}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentPage < widget.topic.questions.length - 1
                    ? () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
