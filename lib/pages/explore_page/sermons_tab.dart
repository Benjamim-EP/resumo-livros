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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height, // 🔹 Garante altura definida
      child: Column(
        children: [
          Expanded(
            child: _sermons.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _sermons.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _sermons.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final sermon = _sermons[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: const Color(0xFF272828),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            sermon["titulo"] ?? "Título desconhecido",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18),
                          ),
                          subtitle: Text(
                            sermon["fonte"] ?? "Fonte desconhecida",
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                          trailing: const Icon(Icons.play_circle_fill,
                              color: Colors.white),
                          onTap: () => _openSermon(
                            sermon["titulo"] ?? "Título desconhecido",
                            sermon["url"] ?? "",
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
