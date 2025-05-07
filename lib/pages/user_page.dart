// lib/pages/user_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for mapEquals if needed (part of _ViewModel)
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/topic_content_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_page/user_diary_page.dart';
import '../components/avatar/profile_picture.dart';
import '../components/user/user_info.dart';
import '../components/stats/stat_item.dart';
import '../components/tabs/tabs.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:redux/redux.dart';
import 'package:intl/intl.dart'; // Necessário para formatar datas do histórico

class UserPage extends StatefulWidget {
  const UserPage({super.key}); // Correção: Use super(key: key)

  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  // Variável local para o mapa de livros e estado de carregamento
  Map<String, dynamic>? _localBooksMap;
  bool _isLoadingBooksMap = true;

  // Aba inicial
  String _selectedTab = 'Histórico'; // Mude conforme necessário

  @override
  void initState() {
    super.initState();
    _loadLocalBooksMap(); // Carrega o mapa localmente
    // Despacha ações iniciais (mantém as existentes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = StoreProvider.of<AppState>(context, listen: false);
      if (store.state.userState.userId != null) {
        store.dispatch(LoadUserStatsAction());
        store.dispatch(LoadUserCollectionsAction());
        // store.dispatch(LoadBooksInProgressAction()); // Removido temporariamente (foco na Bíblia)
        store.dispatch(LoadUserDiariesAction());
        if (store.state.userState.userHighlights.isEmpty) {
          store.dispatch(LoadUserHighlightsAction());
        }
        if (store.state.userState.userNotes.isEmpty) {
          store.dispatch(LoadUserNotesAction());
        }
        // Carrega o histórico ao iniciar
        if (store.state.userState.readingHistory.isEmpty) {
          store.dispatch(LoadReadingHistoryAction());
        }
      }
    });
  }

  // Função para carregar o mapa de livros localmente
  Future<void> _loadLocalBooksMap() async {
    try {
      final map = await BiblePageHelper.loadBooksMap();
      if (mounted) {
        // Verifica se o widget ainda está montado
        setState(() {
          _localBooksMap = map;
          _isLoadingBooksMap = false;
        });
      }
    } catch (e) {
      print("Erro ao carregar booksMap localmente em UserPage: $e");
      if (mounted) {
        setState(() {
          _isLoadingBooksMap = false; // Para o loading mesmo em caso de erro
        });
      }
    }
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  // Função auxiliar para navegar para a Bíblia
  void _navigateToBibleVerse(String verseId) {
    final parts = verseId.split('_');
    if (parts.length == 3) {
      final bookAbbrev = parts[0];
      final chapter = int.tryParse(parts[1]);
      final verse = int.tryParse(parts[2]);

      if (chapter != null && verse != null) {
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(SetInitialBibleLocationAction(bookAbbrev, chapter));
        print("Navegação para Bíblia solicitada: $bookAbbrev $chapter:$verse");
        // TODO: Implementar mecanismo para MainAppScreen mudar para a aba 2 (Bíblia)
        // Ex: Chamar um método via GlobalKey ou Provider, ou fazer MainAppScreen ouvir a action.
        // Exemplo com notificação (simples, mas pode não ser ideal):
        // TabNavigationNotification(2).dispatch(context);
      }
    }
  }

  Widget _buildTabContent() {
    // Verifica se o mapa local está carregado antes de construir as abas que dependem dele
    if (_isLoadingBooksMap &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico' ||
            _selectedTab == 'Salvos')) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
    }
    // Verifica se ocorreu erro ao carregar o mapa
    if (_localBooksMap == null &&
        (_selectedTab == 'Destaques' ||
            _selectedTab == 'Notas' ||
            _selectedTab == 'Histórico' ||
            _selectedTab == 'Salvos')) {
      return const Center(
          child: Text("Erro ao carregar dados dos livros.",
              style: TextStyle(color: Colors.redAccent)));
    }

    switch (_selectedTab) {
      // --- ABA LENDO (Desativada Temporariamente) ---
      case 'Lendo':
        return const Center(
          child: Text(
            'Seção de Livros em Leitura (Desativada Temporariamente)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        );

      // --- ABA SALVOS ---
      case 'Salvos':
        return StoreConnector<AppState,
            Map<String, List<Map<String, dynamic>>>>(
          converter: (store) => store.state.userState.savedTopicsContent,
          onInit: (store) {
            // Garante que UserCollectionsLoadedAction já foi despachada ou despacha agora
            if (store.state.userState.topicSaves.isEmpty) {
              store.dispatch(LoadUserCollectionsAction());
            }
            // Carrega o conteúdo se necessário
            if (store.state.userState.savedTopicsContent.isEmpty &&
                store.state.userState.topicSaves.isNotEmpty) {
              store.dispatch(LoadTopicsContentUserSavesAction());
            }
          },
          builder: (context, savedTopicsContent) {
            final topicSavesMap =
                StoreProvider.of<AppState>(context).state.userState.topicSaves;

            if (topicSavesMap.isEmpty) {
              return const Center(
                  child: Text("Nenhuma coleção salva.",
                      style: TextStyle(color: Colors.white70)));
            }
            // Se tem coleções mas o conteúdo ainda não carregou
            if (savedTopicsContent.isEmpty && topicSavesMap.isNotEmpty) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
            }

            // Se não tem conteúdo e não tem mais saves (após deletar a última coleção, por exemplo)
            if (savedTopicsContent.isEmpty && topicSavesMap.isEmpty) {
              return const Center(
                  child: Text("Nenhum tópico ou versículo salvo.",
                      style: TextStyle(color: Colors.white70)));
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: savedTopicsContent.entries.map((entry) {
                final collectionName = entry.key;
                final items = entry.value;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 3.0,
                  color: const Color(0xFF313333),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    iconColor: Colors.white, // Cor do ícone de expansão
                    collapsedIconColor: Colors.white70, // Cor quando fechado
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Text(collectionName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_outlined,
                              color: Colors.redAccent),
                          tooltip: "Excluir Coleção",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                                context: context,
                                builder: (dContext) => AlertDialog(
                                      backgroundColor: const Color(0xFF2C2F33),
                                      title: const Text("Confirmar Exclusão",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: Text(
                                          "Tem certeza que deseja excluir a coleção '$collectionName' e todos os seus itens?",
                                          style:
                                              TextStyle(color: Colors.white70)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dContext),
                                            child: const Text("Cancelar",
                                                style: TextStyle(
                                                    color: Colors.white70))),
                                        TextButton(
                                            onPressed: () {
                                              StoreProvider.of<AppState>(
                                                      context,
                                                      listen: false)
                                                  .dispatch(
                                                      DeleteTopicCollectionAction(
                                                          collectionName));
                                              Navigator.pop(dContext);
                                            },
                                            child: const Text("Excluir",
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ));
                          },
                        ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.only(bottom: 8.0),
                    children: items.map((item) {
                      final bool isVerse =
                          item['id']?.startsWith("bibleverses-") ?? false;
                      final String displayTitle =
                          item['titulo'] ?? 'Sem título';
                      // Para versículos, busca o nome do livro do _localBooksMap
                      final String bookAbbrev =
                          isVerse ? (item['id']?.split('-')[1] ?? '') : '';
                      final String bookNameFromMap = _localBooksMap?[bookAbbrev]
                              ?['nome'] ??
                          bookAbbrev.toUpperCase();
                      final String displaySubtitle = isVerse
                          ? bookNameFromMap
                          : (item['bookName'] ??
                              'Origem desconhecida'); // Usa nome do livro para versículo

                      final String? coverUrl = item['cover'];
                      final String itemId = item['id'] ?? 'unknown_id';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        leading: coverUrl != null && coverUrl.isNotEmpty
                            ? (coverUrl.startsWith('assets/')
                                ? Image.asset(coverUrl,
                                    width: 50, height: 50, fit: BoxFit.cover)
                                : Image.network(coverUrl,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                        isVerse
                                            ? Icons.book_outlined
                                            : Icons.topic_outlined,
                                        color: Colors.grey,
                                        size: 40)))
                            : Icon(
                                isVerse
                                    ? Icons.book_outlined
                                    : Icons.topic_outlined,
                                color: Colors.grey,
                                size: 40),
                        title: Text(displayTitle,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: displaySubtitle.isNotEmpty
                            ? Text(displaySubtitle,
                                style: const TextStyle(color: Colors.grey))
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 20),
                          tooltip: "Remover Item",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            StoreProvider.of<AppState>(context, listen: false)
                                .dispatch(DeleteSingleTopicFromCollectionAction(
                                    collectionName, itemId));
                          },
                        ),
                        onTap: () {
                          if (isVerse) {
                            // Para versículos, extrai a referência do ID para navegação
                            final parts =
                                itemId.split('-'); // bibleverses-gn-1-1
                            if (parts.length == 4) {
                              final verseIdForNav =
                                  "${parts[1]}_${parts[2]}_${parts[3]}"; // gn_1_1
                              _navigateToBibleVerse(verseIdForNav);
                            }
                          } else if (itemId != 'unknown_id') {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        TopicContentView(topicId: itemId)));
                          }
                        },
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            );
          },
        );

      // --- ABA DESTAQUES ---
      case 'Destaques':
        return StoreConnector<AppState, Map<String, String>>(
          converter: (store) => store.state.userState.userHighlights,
          builder: (context, highlights) {
            if (highlights.isEmpty) {
              return const Center(
                  child: Text("Nenhum versículo destacado ainda.",
                      style: TextStyle(color: Colors.white70)));
            }
            final highlightList = highlights.entries.toList();
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: highlightList.length,
              itemBuilder: (context, index) {
                final entry = highlightList[index];
                final verseId = entry.key; // Formato: gn_1_1
                final colorHex = entry.value;
                final color =
                    Color(int.parse(colorHex.replaceFirst('#', '0xff')));
                final parts = verseId.split('_');
                String referenceText = verseId;
                if (parts.length == 3) {
                  final bookName = _localBooksMap?[parts[0]]?['nome'] ??
                      parts[0].toUpperCase();
                  referenceText = "$bookName ${parts[1]}:${parts[2]}";
                }
                return Card(
                  color: const Color(0xFF313333),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: Container(
                        width: 10,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2))),
                    title: Text(referenceText,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: FutureBuilder<String>(
                      future:
                          BiblePageHelper.loadSingleVerseText(verseId, 'nvi'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Text("Carregando texto...",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12));
                        if (snapshot.hasError ||
                            !snapshot.hasData ||
                            snapshot.data!.isEmpty)
                          return const Text("Texto indisponível",
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12));
                        return Text(snapshot.data!,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                                backgroundColor: color.withOpacity(0.3)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis);
                      },
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Destaque",
                      onPressed: () {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(ToggleHighlightAction(verseId));
                      },
                    ),
                    onTap: () => _navigateToBibleVerse(verseId),
                  ),
                );
              },
            );
          },
        );

      // --- ABA NOTAS ---
      case 'Notas':
        return StoreConnector<AppState, Map<String, String>>(
          converter: (store) => store.state.userState.userNotes,
          builder: (context, notes) {
            if (notes.isEmpty) {
              return const Center(
                  child: Text("Nenhuma nota adicionada ainda.",
                      style: TextStyle(color: Colors.white70)));
            }
            final noteList = notes.entries.toList();
            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: noteList.length,
              itemBuilder: (context, index) {
                final entry = noteList[index];
                final verseId = entry.key; // Formato: gn_1_1
                final noteText = entry.value;
                final parts = verseId.split('_');
                String referenceText = verseId;
                if (parts.length == 3) {
                  final bookName = _localBooksMap?[parts[0]]?['nome'] ??
                      parts[0].toUpperCase();
                  referenceText = "$bookName ${parts[1]}:${parts[2]}";
                }
                return Card(
                  color: const Color(0xFF313333),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: const Icon(Icons.note_alt_outlined,
                        color: Colors.blueAccent),
                    title: Text(referenceText,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(noteText,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.9), fontSize: 13),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: "Remover Nota",
                      onPressed: () {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(DeleteNoteAction(verseId));
                      },
                    ),
                    onTap: () => _navigateToBibleVerse(verseId),
                  ),
                );
              },
            );
          },
        );

      // --- ABA HISTÓRICO ---
      case 'Histórico':
        return StoreConnector<AppState, List<Map<String, dynamic>>>(
          converter: (store) => store.state.userState.readingHistory,
          onInit: (store) {
            // Garante que o histórico seja carregado se não estiver no estado
            if (store.state.userState.readingHistory.isEmpty) {
              store.dispatch(LoadReadingHistoryAction());
            }
          },
          builder: (context, history) {
            if (history.isEmpty) {
              // Mostra loading se a ação ainda não populou o estado
              if (StoreProvider.of<AppState>(context)
                  .state
                  .userState
                  .readingHistory
                  .isEmpty) {
                // Check again in case it loaded between converter and builder
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFCDE7BE)));
              }
              return const Center(
                  child: Text("Nenhum histórico de leitura encontrado.",
                      style: TextStyle(color: Colors.white70)));
            }

            final DateFormat formatter = DateFormat('dd/MM/yy HH:mm');

            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final entry = history[index];
                final bookAbbrev = entry['bookAbbrev'] ?? '?';
                final chapter = entry['chapter'] ?? '?';
                // Usa o mapa local para nome do livro
                final bookName = _localBooksMap?[bookAbbrev]?['nome'] ??
                    bookAbbrev.toUpperCase();
                final timestamp = entry['timestamp'] as DateTime?;
                final verseIdForNav = "${bookAbbrev}_${chapter}_1";

                return Card(
                  color: const Color(0xFF313333),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    leading: const Icon(Icons.history_edu_outlined,
                        color: Colors.white70), // Ícone diferente
                    title: Text(
                      "$bookName $chapter",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      timestamp != null
                          ? formatter.format(timestamp)
                          : "Data indisponível",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.white70),
                    onTap: () => _navigateToBibleVerse(verseIdForNav),
                  ),
                );
              },
            );
          },
        );

      case 'Diário':
        return const UserDiaryPage();

      default:
        return const Center(
            child: Text('Conteúdo não disponível.',
                style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildBookCard(Map<String, dynamic> bookDetails) {
    // Desativado temporariamente
    num progressValue = bookDetails['progress'] ?? 0;
    final progress = (progressValue.clamp(0, 100)) / 100.0;

    return Card(
      color: const Color(0xFF313333),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: (bookDetails['cover'] != null &&
                      bookDetails['cover'].isNotEmpty)
                  ? Image.network(
                      bookDetails['cover'],
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.book, size: 60, color: Colors.grey),
                    )
                  : const SizedBox(
                      width: 60,
                      height: 90,
                      child: Icon(Icons.book, size: 60, color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookDetails['title'] ?? 'Sem título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bookDetails['author'] != null &&
                            bookDetails['author'].isNotEmpty
                        ? '${bookDetails['author']}'
                        : 'Autor desconhecido',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (progress > 0)
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(15),
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF4CAF50),
                      ),
                    )
                  else
                    const Text("Não iniciado",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _UserPageViewModel>(
      converter: (store) => _UserPageViewModel.fromStore(store),
      builder: (context, vm) {
        // Mostra o loader principal se o mapa de livros ainda não carregou
        if (_isLoadingBooksMap) {
          return Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFCDE7BE))));
        }

        final userDetails = vm.userDetails;
        // final livros = vm.booksInProgressCount.toString(); // Desativado
        final topicosLidos = userDetails['Tópicos']?.toString() ?? '0';

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: RefreshIndicator(
            onRefresh: () async {
              final store = StoreProvider.of<AppState>(context, listen: false);
              if (vm.userId != null) {
                store.dispatch(LoadUserStatsAction());
                store.dispatch(LoadUserCollectionsAction());
                store.dispatch(LoadUserDiariesAction());
                store.dispatch(LoadUserHighlightsAction());
                store.dispatch(LoadUserNotesAction());
                store.dispatch(
                    LoadReadingHistoryAction()); // Recarrega histórico
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kToolbarHeight - 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      ProfilePicture(),
                      const SizedBox(height: 16),
                      UserInfo(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: StatsContainer(
                              livros: "0", // Fixo
                              topicos: topicosLidos,
                            ),
                          ),
                          Padding(
                            // Adiciona padding ao botão de logout
                            padding: const EdgeInsets.only(left: 8.0),
                            child: LogoutButton(), // Botão de logout
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      Tabs(
                        onTabSelected: _onTabSelected,
                        selectedTab: _selectedTab,
                      ),
                      const Divider(color: Colors.white24, height: 1),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildTabContent(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ViewModel para simplificar o StoreConnector principal
class _UserPageViewModel {
  final String? userId;
  final Map<String, dynamic> userDetails;
  final int booksInProgressCount;
  final int topicSavesCount;

  _UserPageViewModel({
    required this.userId,
    required this.userDetails,
    required this.booksInProgressCount,
    required this.topicSavesCount,
  });

  static _UserPageViewModel fromStore(Store<AppState> store) {
    return _UserPageViewModel(
      userId: store.state.userState.userId,
      userDetails: store.state.userState.userDetails ?? {},
      booksInProgressCount: store.state.userState.booksInProgress.length,
      topicSavesCount: store.state.userState.topicSaves.values
          .fold<int>(0, (prev, list) => prev + list.length),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UserPageViewModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          mapEquals(userDetails, other.userDetails) &&
          booksInProgressCount == other.booksInProgressCount &&
          topicSavesCount == other.topicSavesCount;

  @override
  int get hashCode =>
      userId.hashCode ^
      userDetails.hashCode ^
      booksInProgressCount.hashCode ^
      topicSavesCount.hashCode;
}

// Botão de Logout (Mantido como estava)
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 180, 115, 110),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(
          Icons.logout,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () {
          // Lógica de logout (ex: chamar FirebaseAuth.instance.signOut())
          // Exemplo:
          // FirebaseAuth.instance.signOut();
          // Navega para a tela de login e remove todas as rotas anteriores
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/login', (Route<dynamic> route) => false);
        },
        tooltip: 'Sair',
      ),
    );
  }
}

// Função mapEquals (Mantida como estava)
bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) {
      return false;
    }
  }
  return true;
}
