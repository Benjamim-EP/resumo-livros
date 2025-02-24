import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/pages/explore_page/sermon_video_page.dart';

class SermonsSection extends StatefulWidget {
  const SermonsSection({super.key});

  @override
  _SermonsSectionState createState() => _SermonsSectionState();
}

class _SermonsSectionState extends State<SermonsSection> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _sermons = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _limit = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchSermons();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _fetchSermons() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    Query query =
        _firestore.collection("pregacoes").orderBy("titulo").limit(_limit);

    if (_lastDocument != null) {
      query = query.startAfterDocument(_lastDocument!);
    }

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _lastDocument = snapshot.docs.last;
        _sermons.addAll(
            snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>));
        _hasMore = snapshot.docs.length == _limit;
      });
    } else {
      _hasMore = false;
    }

    setState(() => _isLoading = false);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _fetchSermons();
    }
  }

  void _openSermon(String title, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SermonVideoPage(videoUrl: url, title: title),
      ),
    );
  }

  String _getThumbnailUrl(String videoUrl) {
    final Uri uri = Uri.parse(videoUrl);
    final videoId = uri.queryParameters['v'] ?? uri.pathSegments.last;
    return "https://img.youtube.com/vi/$videoId/0.jpg";
  }

  @override
  @override
Widget build(BuildContext context) {
  return SizedBox(
    height: MediaQuery.of(context).size.height,
    child: Column(
      children: [
        // 🔹 Barra de Pesquisa (fixa no topo)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Pesquisar sermões...",
              hintStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF272828),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // 🔹 Botões de seleção do orador (fixos no topo)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSpeakerButton("Joyce Meyer"),
              _buildSpeakerButton("Billy Graham"),
              _buildSpeakerButton("CCB"),
              _buildSpeakerButton("Todos"),
            ],
          ),
        ),
        const SizedBox(height: 16), // Espaçamento entre filtros e lista

        // 🔹 Lista rolável com sermões
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (!_isLoading &&
                  scrollInfo.metrics.pixels ==
                      scrollInfo.metrics.maxScrollExtent) {
                _fetchSermons();
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _sermons.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _sermons.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sermon = _sermons[index];
                final String title = sermon["titulo"] ?? "Título desconhecido";
                final String fonte = sermon["fonte"] ?? "Fonte desconhecida";
                final String videoUrl = sermon["url"] ?? "";
                final String thumbnailUrl = _getThumbnailUrl(videoUrl);

                return GestureDetector(
                  onTap: () => _openSermon(title, videoUrl),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF272828),
                      image: DecorationImage(
                        image: NetworkImage(thumbnailUrl),
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        opacity: 0.4, // 🔹 Reduz opacidade da thumbnail
                      ),
                    ),
                    child: Stack(
                      children: [
                        // 🔹 Degradê para melhorar contraste
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // 🔹 Ícone de play
                              const Icon(Icons.play_circle_fill,
                                  color: Colors.white, size: 40),
                              const SizedBox(width: 12),
                              // 🔹 Título e fonte
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fonte,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildSpeakerButton(String speakerName) {
    return ElevatedButton(
      onPressed: () {
        // Lógica de filtro será implementada depois
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF272828),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        speakerName,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

}
