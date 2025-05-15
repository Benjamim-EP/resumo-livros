// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for listEquals and mapEquals
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart'; // Não mais usado aqui diretamente
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart'; // Não mais usado aqui diretamente
import 'package:resumo_dos_deuses_flutter/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/tabs/tabs.dart'; // Ainda usado
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart';
import 'package:intl/intl.dart';

enum HighlightType { verses, comments }

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  Map<String, dynamic>? _localBooksMap;
  bool _isLoadingBooksMap = true;
  String _selectedTab = 'Destaques'; // Destaques agora é a padrão e principal
  HighlightType _selectedHighlightType = HighlightType.verses;

  // Lista de abas ATUALIZADA
  final List<String> _availableTabs = const [
    'Destaques',
    'Notas',
    'Histórico',
    'Diário'
    // 'Lendo' e 'Salvos' foram removidos
  ];

  @override
  void initState() {
    super.initState();
    _loadLocalBooksMap(); // Mantido, pois é usado para nomes de livros em Destaques, Notas, Histórico

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Proteção adicional
      final storeInstance = StoreProvider.of<AppState>(context, listen: false);
      if (storeInstance.state.userState.userId != null) {
        storeInstance.dispatch(LoadUserStatsAction());
        // storeInstance.dispatch(LoadUserCollectionsAction()); // REMOVIDO se 'Salvos' não existe mais
        storeInstance.dispatch(LoadUserDiariesAction());
        storeInstance.dispatch(LoadReadingHistoryAction());
        if (storeInstance.state.userState.userHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserHighlightsAction());
        }
        if (storeInstance.state.userState.userCommentHighlights.isEmpty) {
          storeInstance.dispatch(LoadUserCommentHighlightsAction());
        }
        if (storeInstance.state.userState.userNotes.isEmpty) {
          storeInstance.dispatch(LoadUserNotesAction());
        }
        // if (storeInstance.state.userState.booksInProgressDetails.isEmpty) { // REMOVIDO
        //   storeInstance.dispatch(LoadBooksDetailsAction());
        // }
      }
    });
  }

  Future<void> _loadLocalBooksMap() async {
    try {
      final map = await BiblePageHelper.loadBooksMap();
      if (mounted) {
        setState(() {
          _localBooksMap = map;
          _isLoadingBooksMap = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar booksMap localmente em UserPage: $e");
      if (mounted) {
        setState(() {
          _isLoadingBooksMap = false;
        });
      }
    }
  }

  void _onTabSelected(String tab) {
    if (mounted) {
      setState(() {
        _selectedTab = tab;
      });
    }
  }

  void _navigateToBibleVerseAndTab(String verseId) {
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      if (chapter != null && context.mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        store.dispatch(RequestBottomNavChangeAction(2));
        print(
            "UserPage: Solicitação para ir para Bíblia: $bookAbbrev $chapter, Aba 2");
      }
    }
  }

  Widget _buildCommentHighlightCard(
      Map<String, dynamic> highlight, BuildContext context, ThemeData theme) {
    final String selectedSnippet =
        highlight['selectedSnippet'] ?? 'Trecho indisponível';
    final String fullCommentText =
        highlight['fullCommentText'] ?? 'Comentário completo indisponível';
    final String referenceText =
        highlight['verseReferenceText'] ?? 'Referência desconhecida';
    final String highlightId = highlight['id'] ?? '';
    return Card(
      color: const Color(0xFF3A3C3C),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$selectedSnippet"',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              "No contexto de: ${fullCommentText.length > 100 ? "${fullCommentText.substring(0, 100)}..." : fullCommentText}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    referenceText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (highlightId.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: "Remover Marcação do Comentário",
                    onPressed: () {
                      if (context.mounted) {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                                RemoveCommentHighlightAction(highlightId));
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final theme = Theme.of(context);
    // Condição de loading ajustada, pois não temos mais a aba 'Salvos' dependendo disso diretamente aqui
    if (_isLoadingBooksMap &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico')) {
      return Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary));
    }
    // Verificação de _localBooksMap para abas que o utilizam
    if (_localBooksMap == null &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico')) {
      return Center(
          child: Text("Erro ao carregar dados dos livros.",
              style: TextStyle(color: theme.colorScheme.error)));
    }

    switch (_selectedTab) {
      // REMOVIDO case 'Lendo'
      // REMOVIDO case 'Salvos'

      case 'Destaques':
        return Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: SegmentedButton<HighlightType>(
                segments: const <ButtonSegment<HighlightType>>[
                  ButtonSegment<HighlightType>(
                      value: HighlightType.verses,
                      label: Text('Versículos'),
                      icon: Icon(Icons.menu_book)),
                  ButtonSegment<HighlightType>(
                      value: HighlightType.comments,
                      label: Text('Comentários'),
                      icon: Icon(Icons.comment_bank_outlined)),
                ],
                selected: <HighlightType>{_selectedHighlightType},
                onSelectionChanged: (Set<HighlightType> newSelection) {
                  if (mounted) {
                    setState(() {
                      _selectedHighlightType = newSelection.first;
                    });
                  }
                },
                style: SegmentedButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface.withOpacity(0.1),
                  foregroundColor: theme.colorScheme.onSurface,
                  selectedForegroundColor: theme.colorScheme.onPrimary,
                  selectedBackgroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: StoreConnector<AppState, _HighlightsViewModel>(
                converter: (store) => _HighlightsViewModel.fromStore(store),
                builder: (context, highlightsVm) {
                  if (_selectedHighlightType == HighlightType.verses) {
                    // _isLoadingBooksMap já verificado acima para esta aba
                    final highlights = highlightsVm.userVerseHighlights;
                    if (highlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum versículo destacado ainda.",
                              style: TextStyle(fontSize: 16)));
                    }
                    final highlightList = highlights.entries.toList();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: highlightList.length,
                      itemBuilder: (context, index) {
                        final entry = highlightList[index];
                        final verseId = entry.key;
                        final colorHex = entry.value;
                        final colorForIndicator = Color(
                            int.parse(colorHex.replaceFirst('#', '0xff')));
                        final parts = verseId.split('_');
                        String referenceText = verseId;

                        if (parts.length == 3 &&
                            _localBooksMap != null &&
                            _localBooksMap!.containsKey(parts[0])) {
                          final bookData = _localBooksMap![parts[0]];
                          referenceText =
                              "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        } else if (parts.length == 3) {
                          referenceText =
                              "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 10.0),
                            leading: Container(
                                width: 10,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                    color: colorForIndicator,
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10)))),
                            title: Text(referenceText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                            subtitle: FutureBuilder<String>(
                              future: BiblePageHelper.loadSingleVerseText(
                                  verseId, 'nvi'),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text("Carregando texto...",
                                      style: TextStyle(
                                          color:
                                              theme.textTheme.bodySmall?.color,
                                          fontSize: 12));
                                }
                                if (snapshot.hasError ||
                                    !snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Text("Texto indisponível",
                                      style: TextStyle(
                                          color: theme.colorScheme.error
                                              .withOpacity(0.7),
                                          fontSize: 12));
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(snapshot.data!,
                                      style: TextStyle(
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                          fontSize: 13.5,
                                          height: 1.4),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis),
                                );
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: theme.colorScheme.error.withOpacity(
                                      0.7), // Ajustado para usar 0.7 de opacidade
                                  size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: "Remover Destaque",
                              onPressed: () {
                                if (context.mounted) {
                                  StoreProvider.of<AppState>(context,
                                          listen: false)
                                      .dispatch(ToggleHighlightAction(verseId));
                                }
                              },
                            ),
                            onTap: () => _navigateToBibleVerseAndTab(verseId),
                          ),
                        );
                      },
                    );
                  } else {
                    // _selectedHighlightType == HighlightType.comments
                    final commentHighlights =
                        highlightsVm.userCommentHighlights;
                    if (commentHighlights.isEmpty) {
                      return const Center(
                          child: Text("Nenhum comentário marcado ainda.",
                              style: TextStyle(fontSize: 16)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      itemCount: commentHighlights.length,
                      itemBuilder: (context, index) {
                        final highlight = commentHighlights[index];
                        return _buildCommentHighlightCard(
                            highlight, context, theme);
                      },
                    );
                  }
                },
              ),
            ),
          ],
        );

      case 'Notas':
        return StoreConnector<AppState, Map<String, String>>(
          converter: (store) => store.state.userState.userNotes,
          onInit: (store) {
            if (store.state.userState.userNotes.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadUserNotesAction());
            }
          },
          builder: (context, notes) {
            if (notes.isEmpty) {
              return Center(
                  child: Text("Nenhuma nota adicionada ainda.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                          fontSize: 16)));
            }
            final noteList = notes.entries.toList();
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: noteList.length,
              itemBuilder: (context, index) {
                final entry = noteList[index];
                final verseId = entry.key;
                final noteText = entry.value;
                final parts = verseId.split('_');
                String referenceText = verseId;
                if (parts.length == 3 &&
                    _localBooksMap != null &&
                    _localBooksMap!.containsKey(parts[0])) {
                  final bookData = _localBooksMap![parts[0]];
                  referenceText =
                      "${bookData?['nome'] ?? parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                } else if (parts.length == 3) {
                  referenceText =
                      "${parts[0].toUpperCase()} ${parts[1]}:${parts[2]}";
                }
                return Card(
                  // color: const Color(0xFF313333), // Usa cor do tema
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: Icon(Icons.note_alt_outlined,
                        color: theme.colorScheme.secondary,
                        size: 28), // Cor do tema
                    title: Text(referenceText,
                        style: TextStyle(
                            // color: Colors.white, // Usa cor do tema
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(noteText,
                          style: TextStyle(
                              // color: Colors.white.withOpacity(0.9), // Usa cor do tema
                              fontSize: 14,
                              height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error.withOpacity(0.7),
                          size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Nota",
                      onPressed: () {
                        if (context.mounted) {
                          StoreProvider.of<AppState>(context, listen: false)
                              .dispatch(DeleteNoteAction(verseId));
                        }
                      },
                    ),
                    onTap: () => _navigateToBibleVerseAndTab(verseId),
                  ),
                );
              },
            );
          },
        );

      case 'Histórico':
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.readingHistory,
          onInit: (store) {
            if (store.state.userState.readingHistory.isEmpty &&
                store.state.userState.userId != null) {
              store.dispatch(LoadReadingHistoryAction());
            }
          },
          builder: (context, history) {
            if (history.isEmpty) {
              return Center(
                  child: Text("Nenhum histórico de leitura encontrado.",
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                          fontSize: 16)));
            }
            final DateFormat formatter = DateFormat('dd/MM/yy \'às\' HH:mm');
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final bookAbbrev = entry['bookAbbrev'] ?? '?';
                final chapter = entry['chapter'] ?? '?';
                final bookName = _localBooksMap?[bookAbbrev]?['nome'] ??
                    bookAbbrev.toUpperCase();
                final timestamp = entry['timestamp'] as DateTime?;
                final verseIdForNav = "${bookAbbrev}_${chapter}_1";

                return Card(
                  // color: const Color(0xFF313333), // Usa cor do tema
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 10.0),
                    leading: Icon(Icons.history_edu_outlined,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                        size: 28),
                    title: Text(
                      "$bookName $chapter",
                      style: const TextStyle(
                          // color: Colors.white, // Usa cor do tema
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        timestamp != null
                            ? formatter.format(timestamp.toLocal())
                            : "Data indisponível",
                        style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 13),
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 18,
                        color: theme.iconTheme.color?.withOpacity(0.7)),
                    onTap: () => _navigateToBibleVerseAndTab(verseIdForNav),
                  ),
                );
              },
            );
          },
        );

      case 'Diário':
        return const UserDiaryPage();

      default:
        return Center(
            child: Text('Conteúdo não disponível.',
                style: TextStyle(fontSize: 16)));
    }
  }

  // REMOVIDO: _buildBookCard pois a aba 'Lendo' foi removida.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Para usar no RefreshIndicator
    return StoreConnector<AppState, _UserPageViewModel>(
      converter: (store) => _UserPageViewModel.fromStore(store),
      builder: (context, vm) {
        // Ajustada a condição para não depender mais de _selectedTab == 'Lendo' ou 'Salvos'
        bool shouldShowGlobalLoader = _isLoadingBooksMap &&
            (_selectedTab == 'Destaques' ||
                _selectedTab == 'Notas' ||
                _selectedTab == 'Histórico');

        if (shouldShowGlobalLoader) {
          return Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary)));
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: RefreshIndicator(
            color: theme.colorScheme.primary,
            backgroundColor: theme.scaffoldBackgroundColor,
            onRefresh: () async {
              if (!mounted) return;
              final storeInstance =
                  StoreProvider.of<AppState>(context, listen: false);
              if (vm.userId != null) {
                storeInstance.dispatch(LoadUserStatsAction());
                // storeInstance.dispatch(LoadUserCollectionsAction()); // REMOVIDO
                storeInstance.dispatch(LoadUserDiariesAction());
                storeInstance.dispatch(LoadUserHighlightsAction());
                storeInstance.dispatch(LoadUserCommentHighlightsAction());
                storeInstance.dispatch(LoadUserNotesAction());
                storeInstance.dispatch(LoadReadingHistoryAction());
                // storeInstance.dispatch(LoadBooksDetailsAction()); // REMOVIDO
              }
            },
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 0),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  ProfilePicture(),
                                  const SizedBox(height: 12),
                                  UserInfo(),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.settings_outlined,
                                  color: theme.colorScheme.primary, size: 28),
                              tooltip: 'Configurações',
                              onPressed: () {
                                if (context.mounted) {
                                  Navigator.of(context, rootNavigator: true)
                                      .pushNamed('/userSettings');
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Passa a lista de abas ATUALIZADA para o componente Tabs
                        Tabs(
                          tabs:
                              _availableTabs, // Usa a lista de abas disponíveis
                          onTabSelected: _onTabSelected,
                          selectedTab: _selectedTab,
                        ),
                        Divider(
                            color: theme.dividerColor.withOpacity(0.5),
                            height: 1,
                            thickness: 0.5),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildTabContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UserPageViewModel {
  final String? userId;
  final Map<String, dynamic> userDetails;
  // REMOVIDO: final int topicSavesCount; // Se a aba 'Salvos' foi removida, isso pode não ser mais necessário aqui
  final int userDiariesCount;

  _UserPageViewModel({
    required this.userId,
    required this.userDetails,
    // required this.topicSavesCount, // REMOVIDO
    required this.userDiariesCount,
  });

  static _UserPageViewModel fromStore(Store<AppState> store) {
    // int totalSavedItems = 0; // REMOVIDO
    // store.state.userState.topicSaves.forEach((collectionName, items) { // REMOVIDO
    //   totalSavedItems += items.length; // REMOVIDO
    // }); // REMOVIDO

    return _UserPageViewModel(
      userId: store.state.userState.userId,
      userDetails: store.state.userState.userDetails ?? {},
      // topicSavesCount: totalSavedItems, // REMOVIDO
      userDiariesCount: store.state.userState.userDiaries.length,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserPageViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          mapEquals(userDetails, other.userDetails) &&
          // topicSavesCount == other.topicSavesCount && // REMOVIDO
          userDiariesCount == other.userDiariesCount;

  @override
  int get hashCode =>
      userId.hashCode ^
      userDetails.hashCode ^
      // topicSavesCount.hashCode ^ // REMOVIDO
      userDiariesCount.hashCode;
}

class _HighlightsViewModel {
  final Map<String, String> userVerseHighlights;
  final List<Map<String, dynamic>> userCommentHighlights;

  _HighlightsViewModel({
    required this.userVerseHighlights,
    required this.userCommentHighlights,
  });

  static _HighlightsViewModel fromStore(Store<AppState> store) {
    return _HighlightsViewModel(
      userVerseHighlights: store.state.userState.userHighlights,
      userCommentHighlights: store.state.userState.userCommentHighlights,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HighlightsViewModel &&
          runtimeType == other.runtimeType &&
          mapEquals(userVerseHighlights, other.userVerseHighlights) &&
          listEquals(userCommentHighlights, other.userCommentHighlights);

  @override
  int get hashCode =>
      userVerseHighlights.hashCode ^ userCommentHighlights.hashCode;
}
