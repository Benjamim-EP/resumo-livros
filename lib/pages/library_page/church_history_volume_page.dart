// lib/pages/library_page/church_history_volume_page.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/church_history_model.dart';
import 'package:septima_biblia/services/tts_manager.dart'; // >>> 1. Importar o TtsManager

class ChurchHistoryVolumePage extends StatefulWidget {
  final ChurchHistoryVolume volume;

  const ChurchHistoryVolumePage({super.key, required this.volume});

  @override
  State<ChurchHistoryVolumePage> createState() =>
      _ChurchHistoryVolumePageState();
}

class _ChurchHistoryVolumePageState extends State<ChurchHistoryVolumePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // >>> INÍCIO DA MODIFICAÇÃO 1/4: Adicionar estado e instância do TTS <<<
  final TtsManager _ttsManager = TtsManager();
  TtsPlayerState _playerState = TtsPlayerState.stopped;
  // >>> FIM DA MODIFICAÇÃO 1/4 <<<

  @override
  void initState() {
    super.initState();
    // >>> INÍCIO DA MODIFICAÇÃO 2/4: Adicionar listener <<<
    _ttsManager.playerState.addListener(_onTtsStateChanged);
    // >>> FIM DA MODIFICAÇÃO 2/4 <<<
  }

  @override
  void dispose() {
    _pageController.dispose();
    // >>> INÍCIO DA MODIFICAÇÃO 3/4: Parar TTS e remover listener <<<
    _ttsManager.playerState.removeListener(_onTtsStateChanged);
    _ttsManager.stop(); // Garante que o áudio pare ao sair da página
    // >>> FIM DA MODIFICAÇÃO 3/4 <<<
    super.dispose();
  }

  // >>> INÍCIO DA MODIFICAÇÃO 4/4: Funções de controle do TTS <<<

  /// Atualiza o estado da UI quando o estado do player TTS muda.
  void _onTtsStateChanged() {
    if (!mounted) return;
    if (_playerState != _ttsManager.playerState.value) {
      setState(() {
        _playerState = _ttsManager.playerState.value;
      });
    }
  }

  /// Constrói a fila de áudio para o capítulo atual e inicia a reprodução.
  void _startChapterPlayback() {
    if (widget.volume.chapters.isEmpty) return;

    final chapter = widget.volume.chapters[_currentPage];
    final List<TtsQueueItem> queue = [];

    // Adiciona o título do capítulo à fila
    queue.add(TtsQueueItem(
      sectionId: 'title_$_currentPage',
      textToSpeak: "Capítulo. ${chapter.title}",
    ));

    // Adiciona cada parágrafo do conteúdo à fila
    for (int i = 0; i < chapter.content.length; i++) {
      final paragraph = chapter.content[i];
      if (paragraph.trim().isNotEmpty) {
        queue.add(TtsQueueItem(
          sectionId: 'paragraph_${_currentPage}_$i',
          textToSpeak: paragraph,
        ));
      }
    }

    if (queue.isNotEmpty) {
      // Usa o ID do primeiro item como ponto de partida
      _ttsManager.speak(queue, queue.first.sectionId);
    }
  }

  /// Lida com os cliques no botão de controle de áudio na AppBar.
  void _handleAudioControl() {
    switch (_playerState) {
      case TtsPlayerState.stopped:
        _startChapterPlayback();
        break;
      case TtsPlayerState.playing:
        _ttsManager.pause();
        break;
      case TtsPlayerState.paused:
        _ttsManager.restartCurrentItem();
        break;
    }
  }

  /// Retorna o ícone apropriado para o botão de áudio.
  IconData _getAudioIcon() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return Icons.pause_circle_outline;
      case TtsPlayerState.paused:
        return Icons
            .play_circle_outline; // Ícone de play para indicar "Continuar"
      case TtsPlayerState.stopped:
        return Icons.play_circle_outline;
    }
  }

  /// Retorna o tooltip apropriado para o botão de áudio.
  String _getAudioTooltip() {
    switch (_playerState) {
      case TtsPlayerState.playing:
        return "Pausar Leitura";
      case TtsPlayerState.paused:
        return "Continuar Leitura";
      case TtsPlayerState.stopped:
        return "Ouvir Capítulo";
    }
  }
  // >>> FIM DA MODIFICAÇÃO 4/4 <<<

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.volume.title, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          // >>> Ícone de TTS adicionado aqui <<<
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
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: "Índice de Capítulos",
            onPressed: () => _showChapterIndex(context),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.volume.chapters.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
            // Para a reprodução de áudio se o usuário mudar de capítulo manualmente
            _ttsManager.stop();
          });
        },
        itemBuilder: (context, index) {
          final currentChapter = widget.volume.chapters[index];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentChapter.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(color: theme.dividerColor, height: 24),
                ...currentChapter.content.map(
                  (paragraph) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      paragraph,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color:
                            theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
                      ),
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
                    ? () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    : null,
              ),
              Text(
                'Capítulo ${_currentPage + 1} de ${widget.volume.chapters.length}',
                style: theme.textTheme.bodyMedium,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: _currentPage < widget.volume.chapters.length - 1
                    ? () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeIn,
                        );
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterIndex(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return ListView.builder(
          itemCount: widget.volume.chapters.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(
                '${index + 1}. ${widget.volume.chapters[index].title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _pageController.jumpToPage(index);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
