// lib/pages/community/book_club_grid_card.dart
import 'package:flutter/material.dart';

class BookClubGridCard extends StatelessWidget {
  final String bookId;
  final String title;
  final String coverUrl;
  final int participantCount;
  final VoidCallback onTap;

  const BookClubGridCard({
    super.key,
    required this.bookId,
    required this.title,
    required this.coverUrl,
    required this.participantCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        child: GridTile(
          footer: GridTileBar(
            backgroundColor: Colors.black.withOpacity(0.7),
            title: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                const Icon(Icons.group, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text('$participantCount', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          child: coverUrl.isNotEmpty
              ? Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.book, size: 50),
                )
              : Container(
                  color: theme.colorScheme.surfaceVariant,
                  child: const Icon(Icons.book, size: 50),
                ),
        ),
      ),
    );
  }
}
