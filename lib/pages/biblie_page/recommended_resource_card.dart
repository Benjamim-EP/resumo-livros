// lib/pages/biblie_page/recommended_resource_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/services/library_content_service.dart';
import 'package:septima_biblia/pages/biblie_page/library_resource_viewer_modal.dart';

class RecommendedResourceCard extends StatelessWidget {
  final ContentUnit contentUnit;
  final String reason;

  const RecommendedResourceCard({
    super.key,
    required this.contentUnit,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        margin: const EdgeInsets.only(right: 12.0, top: 4.0, bottom: 4.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  LibraryResourceViewerModal(contentUnit: contentUnit),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contentUnit.sourceTitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  contentUnit.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                const Divider(height: 8),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
