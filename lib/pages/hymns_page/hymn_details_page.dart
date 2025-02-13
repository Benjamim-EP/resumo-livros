import 'package:flutter/material.dart';

class HymnDetailsPage extends StatelessWidget {
  final Map<String, dynamic> hymn;

  const HymnDetailsPage({super.key, required this.hymn});

  @override
  Widget build(BuildContext context) {
    final verses = hymn["verses"] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(hymn["title"]),
        backgroundColor: const Color(0xFF181A1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: verses.isEmpty
            ? const Center(
                child: Text(
                  "Nenhuma letra disponível para este hino.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : ListView(
                children: verses.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF129575),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}
