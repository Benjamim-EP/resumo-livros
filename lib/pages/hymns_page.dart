import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/hymns_page/hymn_details_page.dart';

class HymnsPage extends StatefulWidget {
  const HymnsPage({super.key});

  @override
  _HymnsPageState createState() => _HymnsPageState();
}

class _HymnsPageState extends State<HymnsPage> {
  List<Map<String, dynamic>> _hymns = [];
  List<Map<String, dynamic>> _displayedHymns = [];
  int _loadedCount = 0;
  final int _loadAmount = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHymns();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadHymns() async {
    final String data = await rootBundle.loadString('assets/hinos/hinos.json');
    final Map<String, dynamic> jsonData = json.decode(data);

    List<Map<String, dynamic>> hymnsList = jsonData.entries.map((entry) {
      return {
        "id": entry.key,
        "title": entry.value["title"],
        "verses": entry.value["verses"]
      };
    }).toList();

    setState(() {
      _hymns = hymnsList;
      _loadMoreHymns();
    });
  }

  void _loadMoreHymns() {
    if (_loadedCount < _hymns.length) {
      int nextCount = (_loadedCount + _loadAmount).clamp(0, _hymns.length);
      setState(() {
        _displayedHymns.addAll(_hymns.sublist(_loadedCount, nextCount));
        _loadedCount = nextCount;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreHymns();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hinos"),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: _displayedHymns.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              itemCount: _displayedHymns.length,
              itemBuilder: (context, index) {
                final hymn = _displayedHymns[index];
                return Card(
                  color: const Color(0xFF272828),
                  elevation: 4,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      hymn['title'],
                      style:
                          const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    trailing: const Icon(Icons.arrow_forward, color: Colors.white),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HymnDetailsPage(hymn: hymn),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
